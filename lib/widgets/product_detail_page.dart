import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_keys.dart';
import '../services/bestbuy/bestbuy.dart';
import '../services/comparison/comparison.dart';
import '../services/storage/storage.dart';
import '../theme/app_colors.dart';
import 'product_comparison_page.dart';
import 'product_detail/product_detail.dart';

/// Full-screen page displaying comprehensive product information.
class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.product});

  final BestBuyProduct product;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  bool _detailsExpanded = false;
  bool _descriptionExpanded = false;
  bool _featuresExpanded = false;
  String _detailsSearchQuery = '';

  // Store availability state
  bool _loadingStoreAvailability = false;
  StoreAvailabilityResponse? _storeAvailability;
  String? _storeAvailabilityError;
  String? _userPostalCode;

  // Cart state
  final CartService _cart = CartService.instance;
  bool _isInCart = false;

  // Comparison state
  final ComparisonService _comparisonService = ComparisonService.instance;
  bool _isInComparison = false;

  BestBuyProduct get product => widget.product;

  @override
  void initState() {
    super.initState();
    _isInCart = _cart.containsSku(product.sku);
    _isInComparison = _comparisonService.containsSku(product.sku);
    _cart.addListener(_onCartChanged);
    _comparisonService.addListener(_onComparisonChanged);
    
    // Auto-fetch store availability if product is marked as in-store available
    if (product.inStoreAvailability == true) {
      _fetchStoreAvailability();
    }
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    _comparisonService.removeListener(_onComparisonChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) {
      setState(() {
        _isInCart = _cart.containsSku(product.sku);
      });
    }
  }

  void _onComparisonChanged() {
    if (mounted) {
      setState(() {
        _isInComparison = _comparisonService.containsSku(product.sku);
      });
    }
  }

  Future<void> _toggleComparison() async {
    if (_isInComparison) {
      await _comparisonService.removeFromComparison(product.sku);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Removed from comparison'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _comparisonService.addToComparison(product),
          ),
        ),
      );
    } else {
      if (_comparisonService.isFull) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Comparison list is full (max ${ComparisonService.maxComparisonItems} items)'),
            action: SnackBarAction(
              label: 'View',
              onPressed: _navigateToComparison,
            ),
          ),
        );
        return;
      }
      
      await _comparisonService.addToComparison(product);
      if (!mounted) return;
      await HapticFeedback.lightImpact();
      
      final count = _comparisonService.itemCount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count >= 2 
              ? 'Added to comparison ($count items)' 
              : 'Added to comparison - add 1 more to compare'),
          action: count >= 2 ? SnackBarAction(
            label: 'Compare',
            onPressed: _navigateToComparison,
          ) : null,
        ),
      );
    }
  }

  void _navigateToComparison() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProductComparisonPage(),
      ),
    );
  }

  Future<void> _toggleCart() async {
    if (_isInCart) {
      await _cart.removeFromCart(product.sku);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Removed from cart'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _cart.addToCart(product),
          ),
        ),
      );
    } else {
      await _cart.addToCart(product);
      if (!mounted) return;
      await HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to cart')),
      );
    }
  }

  Future<void> _fetchStoreAvailability({bool preferGps = true}) async {
    if (_loadingStoreAvailability) return;
    if (!mounted) return;

    setState(() {
      _loadingStoreAvailability = true;
      _storeAvailabilityError = null;
    });

    try {
      Position? position;
      
      // Only try GPS if preferred OR if we don't have a postal code yet
      if (preferGps || _userPostalCode == null || _userPostalCode!.isEmpty) {
        position = await _getUserLocation();
      }
      
      if (!mounted) return;

      final client = BestBuyClient(apiKey: ApiKeys.bestBuy);
      try {
        StoreAvailabilityResponse response;

        // Prioritize GPS if available and preferred
        // BUT if preferGps is false (user manually entered zip), skip GPS even if we have it cached
        if (preferGps && position != null) {
          // Attempt to reverse geocode to get the ZIP code for consistency
          String? derivedPostalCode;
          try {
            final placemarks = await placemarkFromCoordinates(
              position.latitude,
              position.longitude,
            );
            derivedPostalCode = placemarks.firstOrNull?.postalCode;
            // Update the UI state with the detected ZIP so the user sees it
            if (mounted && derivedPostalCode != null && derivedPostalCode.isNotEmpty) {
              setState(() {
                _userPostalCode = derivedPostalCode;
              });
            }
          } catch (_) {
            // Ignore reverse geocoding errors and fallback to lat/long search
          }

          if (derivedPostalCode != null && derivedPostalCode.isNotEmpty) {
            // Use the derived ZIP code for the search
            response = await client.getStoreAvailability(
              sku: product.sku,
              postalCode: derivedPostalCode,
            );
          } else {
            // Fallback to lat/long if reverse geocoding failed
            response = await client.getStoreAvailabilityByLocation(
              sku: product.sku,
              latitude: position.latitude,
              longitude: position.longitude,
            );
          }
        } else if (_userPostalCode != null && _userPostalCode!.isNotEmpty) {
          response = await client.getStoreAvailability(
            sku: product.sku,
            postalCode: _userPostalCode!,
          );
        } else {
          // No location available - prompt user for postal code
          if (!mounted) return;
          setState(() {
            _loadingStoreAvailability = false;
            _storeAvailabilityError = 'location_needed';
          });
          return;
        }

        if (!mounted) return;
        setState(() {
          _storeAvailability = response;
          _loadingStoreAvailability = false;
        });
      } finally {
        client.close();
      }
    } on BestBuyException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingStoreAvailability = false;
        _storeAvailabilityError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingStoreAvailability = false;
        _storeAvailabilityError = 'Failed to check store availability';
      });
    }
  }

  Future<Position?> _getUserLocation() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check permissions
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current position
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _searchByPostalCode(String postalCode) async {
    _userPostalCode = postalCode;
    // When searching by postal code, prefer using it over GPS
    await _fetchStoreAvailability(preferGps: false);
  }

  Future<void> _useCurrentLocation() async {
    // Clear manual zip to fallback to GPS
    _userPostalCode = null;
    await _fetchStoreAvailability(preferGps: true);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unified image area with gradient flowing into content
            ProductImageSection(
              product: product,
              topPadding: topPadding,
              onBack: () => Navigator.of(context).pop(),
              onShare: () => _shareProduct(context),
            ),
            
            // Main content area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product title & identifiers at top
                  _buildHeaderSection(context),
                  const SizedBox(height: 20),

                  // BARCODE - Moved up for quick register access
                  if (product.upc != null) ...[
                    _buildBarcodeSection(context),
                    const SizedBox(height: 24),
                  ],

                  // Stock status - prominent availability
                  StockStatusSection(
                    product: product,
                    storeAvailabilityWidget: StoreAvailabilitySection(
                      isLoading: _loadingStoreAvailability,
                      error: _storeAvailabilityError,
                      availability: _storeAvailability,
                      userPostalCode: _userPostalCode,
                      onRetry: _fetchStoreAvailability,
                      onSearchByPostalCode: _searchByPostalCode,
                      onUseCurrentLocation: _useCurrentLocation,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action buttons - prominent placement
                  ActionButtons(
                    product: product,
                    isInCart: _isInCart,
                    isInComparison: _isInComparison,
                    comparisonService: _comparisonService,
                    onToggleCart: _toggleCart,
                    onToggleComparison: _toggleComparison,
                    onNavigateToComparison: _navigateToComparison,
                    onAskAI: () => _navigateToAskAI(context),
                    onOpenUrl: _openUrl,
                  ),
                  const SizedBox(height: 20),

                  // Quick info chips (shipping, etc.)
                  _buildQuickInfoSection(context),
                  const SizedBox(height: 24),

                  // Short description (Overview)
                  if (product.shortDescription != null &&
                      product.shortDescription!.isNotEmpty) ...[
                    _buildSection(
                      context,
                      title: 'Overview',
                      icon: Icons.description_outlined,
                      child: Text(
                        product.shortDescription!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.6,
                            ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Features
                  if (product.features.isNotEmpty) ...[
                    _buildFeaturesSection(context),
                    const SizedBox(height: 24),
                  ],

                  // Long description - Collapsible
                  if (product.longDescription != null &&
                      product.longDescription!.isNotEmpty) ...[
                    _buildCollapsibleDescription(context),
                    const SizedBox(height: 24),
                  ],

                  // Specifications
                  _buildSpecificationsSection(context),

                  // What's included
                  if (product.includedItemList.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildIncludedItemsSection(context),
                  ],

                  // Product details - Collapsible dropdown
                  if (_getFilteredDetails().isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildCollapsibleDetails(context),
                  ],

                  // Categories
                  if (product.categoryPath.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    CategorySection(categories: product.categoryPath),
                  ],

                  // Special offers
                  if (product.offers.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildOffersSection(context),
                  ],

                  // Customer Reviews
                  if (product.customerReviewAverage != null) ...[
                    const SizedBox(height: 24),
                    RatingSection(
                      product: product,
                      buildSection: _buildSection,
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status badges row
        if (_hasBadges())
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (product.new_ == true) _buildBadge('NEW', AppColors.success),
                if (product.onSale == true) _buildBadge('SALE', AppColors.sale),
                if (product.bestBuyOnly == true)
                  _buildBadge('EXCLUSIVE', AppColors.primaryBlue),
                if (product.refurbished == true)
                  _buildBadge('REFURBISHED', AppColors.accentYellow),
                if (product.preowned == true)
                  _buildBadge('PRE-OWNED', AppColors.textSecondary),
                if (product.digital == true)
                  _buildBadge('DIGITAL', AppColors.secondaryBlue),
              ],
            ),
          ),

        // Product name
        Text(
          product.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
        ),
        const SizedBox(height: 16),

        // Price section - moved above SKU card
        PriceSection(product: product),
        const SizedBox(height: 16),

        // Brand & Model row with copyable identifiers
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              // Brand row
              if (product.manufacturer != null)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        product.manufacturer!,
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (product.type != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          product.type!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              if (product.manufacturer != null) const SizedBox(height: 12),

              // Copyable identifiers row
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCopyableChip(
                    context,
                    label: 'SKU',
                    value: product.sku.toString(),
                  ),
                  if (product.upc != null)
                    _buildCopyableChip(
                      context,
                      label: 'UPC',
                      value: product.upc!,
                    ),
                  if (product.modelNumber != null)
                    _buildCopyableChip(
                      context,
                      label: 'Model',
                      value: product.modelNumber!,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCopyableChip(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _copyToClipboard(context, label, value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$label: ',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.copy,
                size: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyToClipboard(
      BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    await HapticFeedback.lightImpact();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 20),
            const SizedBox(width: 12),
            Text('$label copied to clipboard'),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  bool _hasBadges() {
    return product.new_ == true ||
        product.onSale == true ||
        product.bestBuyOnly == true ||
        product.refurbished == true ||
        product.preowned == true ||
        product.digital == true;
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildBarcodeSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accentYellow.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.qr_code_scanner,
                    size: 16, color: AppColors.accentYellow),
              ),
              const SizedBox(width: 8),
              Text(
                'Scan at Register',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
              ),
              const Spacer(),
              // Tap to copy hint
              GestureDetector(
                onTap: () => _copyToClipboard(context, 'UPC', product.upc!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy, size: 14, color: AppColors.textSecondary),
                      SizedBox(width: 6),
                      Text(
                        'Copy UPC',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Barcode container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                bw.BarcodeWidget(
                  barcode: bw.Barcode.upcA(),
                  data: _normalizeUpc(product.upc!),
                  width: 200,
                  height: 65,
                  color: Colors.black,
                  backgroundColor: Colors.white,
                  drawText: false,
                  errorBuilder: (context, error) {
                    return bw.BarcodeWidget(
                      barcode: bw.Barcode.ean13(),
                      data: _normalizeUpc(product.upc!),
                      width: 200,
                      height: 65,
                      color: Colors.black,
                      backgroundColor: Colors.white,
                      drawText: false,
                      errorBuilder: (context, error) {
                        return Column(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.grey[400], size: 24),
                            const SizedBox(height: 6),
                            Text(
                              'Unable to generate barcode',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 11),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  product.upc!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfoSection(BuildContext context) {
    final chips = <Widget>[];

    if (product.freeShipping == true) {
      chips.add(_buildInfoChip('Free Shipping', Icons.local_shipping_outlined));
    }
    if (product.homeDelivery == true) {
      chips.add(_buildInfoChip('Home Delivery', Icons.home_outlined));
    }
    if (product.storePickup == true) {
      chips.add(_buildInfoChip('Store Pickup', Icons.storefront_outlined));
    }
    if (product.friendsAndFamilyPickup == true) {
      chips.add(_buildInfoChip('Family Pickup', Icons.people_outline));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: chips,
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryBlue),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: AppColors.primaryBlue),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    final features = product.features;
    final showCollapse = features.length > 3;
    final displayedFeatures = _featuresExpanded ? features : features.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle_outline,
                  size: 20, color: AppColors.primaryBlue),
            ),
            const SizedBox(width: 12),
            Text(
              'Key Features',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedCrossFade(
          firstChild: _buildFeaturesList(displayedFeatures),
          secondChild: _buildFeaturesList(features),
          crossFadeState: _featuresExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
        if (showCollapse) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _featuresExpanded = !_featuresExpanded),
            child: Row(
              children: [
                Text(
                  _featuresExpanded
                      ? 'Show less'
                      : 'Show all ${features.length} features',
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _featuresExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFeaturesList(List<String> features) {
    return Column(
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accentYellow, AppColors.brightYellow],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentYellow.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  feature,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCollapsibleDescription(BuildContext context) {
    final description = product.longDescription!;
    final isLong = description.length > 300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.article_outlined,
                  size: 20, color: AppColors.primaryBlue),
            ),
            const SizedBox(width: 12),
            Text(
              'Full Description',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedCrossFade(
          firstChild: Text(
            isLong ? '${description.substring(0, 300)}...' : description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.7,
                ),
          ),
          secondChild: Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.7,
                ),
          ),
          crossFadeState: _descriptionExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
        if (isLong) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () =>
                setState(() => _descriptionExpanded = !_descriptionExpanded),
            child: Row(
              children: [
                Text(
                  _descriptionExpanded ? 'Show less' : 'Read more',
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _descriptionExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSpecificationsSection(BuildContext context) {
    final specs = <MapEntry<String, String>>[];

    if (product.color != null) specs.add(MapEntry('Color', product.color!));
    if (product.condition != null) {
      specs.add(MapEntry('Condition', product.condition!));
    }
    if (product.weight != null) specs.add(MapEntry('Weight', product.weight!));
    if (product.shippingWeight != null) {
      specs.add(MapEntry('Shipping Weight', product.shippingWeight!));
    }
    if (product.height != null) specs.add(MapEntry('Height', product.height!));
    if (product.width != null) specs.add(MapEntry('Width', product.width!));
    if (product.depth != null) specs.add(MapEntry('Depth', product.depth!));
    if (product.releaseDate != null) {
      specs.add(MapEntry('Release Date', _formatDate(product.releaseDate!)));
    }

    if (specs.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      context,
      title: 'Specifications',
      icon: Icons.straighten_outlined,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: specs.asMap().entries.map((entry) {
            final isLast = entry.key == specs.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(
                        bottom: BorderSide(color: AppColors.border),
                      ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.value.key,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      entry.value.value,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildIncludedItemsSection(BuildContext context) {
    return _buildSection(
      context,
      title: 'What\'s Included',
      icon: Icons.inventory_2_outlined,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: product.includedItemList.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.check, size: 18, color: AppColors.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Filter out details that duplicate the product name
  List<ProductDetail> _getFilteredDetails() {
    return product.details.where((detail) {
      final name = detail.name?.toLowerCase() ?? '';
      final value = detail.value?.toLowerCase() ?? '';
      final productName = product.name.toLowerCase();

      // Skip if the detail name or value is essentially the product name
      if (name == 'product name' || name == 'name' || name == 'title') {
        return false;
      }
      // Skip if value matches product name closely
      if (value == productName || productName.contains(value) && value.length > 20) {
        return false;
      }
      return true;
    }).toList();
  }

  Widget _buildCollapsibleDetails(BuildContext context) {
    final allDetails = _getFilteredDetails();
    
    // Filter details based on search query
    final filteredDetails = _detailsSearchQuery.isEmpty
        ? allDetails
        : allDetails.where((detail) {
            final query = _detailsSearchQuery.toLowerCase();
            final name = (detail.name ?? '').toLowerCase();
            final value = (detail.value ?? '').toLowerCase();
            return name.contains(query) || value.contains(query);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _detailsExpanded = !_detailsExpanded),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.list_alt,
                      size: 20, color: AppColors.primaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Product Details',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      Text(
                        '${allDetails.length} attributes',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _detailsExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Only show content when expanded (instant close, animated open)
        if (_detailsExpanded)
          AnimatedOpacity(
            opacity: _detailsExpanded ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  // Search bar
                  TextField(
                    onChanged: (value) => setState(() => _detailsSearchQuery = value),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search details...',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                      ),
                      suffixIcon: _detailsSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              color: AppColors.textSecondary,
                              onPressed: () => setState(() => _detailsSearchQuery = ''),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.primaryBlue,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Details list
                  if (filteredDetails.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No results found',
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    )
                  else
                    ...filteredDetails.asMap().entries.map((entry) {
                      final detail = entry.value;
                      final isLast = entry.key == filteredDetails.length - 1;
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: isLast
                              ? null
                              : const Border(
                                  bottom: BorderSide(color: AppColors.border),
                                ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                detail.name ?? 'N/A',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Text(
                                detail.value ?? 'N/A',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOffersSection(BuildContext context) {
    return _buildSection(
      context,
      title: 'Special Offers',
      icon: Icons.local_offer_outlined,
      child: Column(
        children: product.offers.map((offer) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accentYellow.withValues(alpha: 0.1),
                  AppColors.accentYellow.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accentYellow.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (offer.type != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accentYellow.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      offer.type!.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.accentYellow,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                if (offer.text != null)
                  Text(
                    offer.text!,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                if (offer.startDate != null || offer.endDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _formatOfferDates(offer.startDate, offer.endDate),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _navigateToAskAI(BuildContext context) {
    // Set the product as pending attachment (ChatPage will consume it)
    ChatManager.instance.setPendingProductAttachment(product);
    
    // Pop back to the root ChatPage
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _shareProduct(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon!')),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _normalizeUpc(String upc) {
    String digits = upc.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 12) {
      digits = digits.padLeft(12, '0');
    }
    if (digits.length > 13) {
      digits = digits.substring(0, 12);
    }
    return digits;
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return dateString;
    }
  }

  String _formatOfferDates(String? start, String? end) {
    final parts = <String>[];
    if (start != null) parts.add('From ${_formatDate(start)}');
    if (end != null) parts.add('Until ${_formatDate(end)}');
    return parts.join(' • ');
  }
}
