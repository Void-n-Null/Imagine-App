import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_keys.dart';
import '../services/bestbuy/bestbuy.dart';
import '../services/storage/storage.dart';
import '../theme/app_colors.dart';

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
  bool _categoryExpanded = false;
  String _detailsSearchQuery = '';

  // Store availability state
  bool _loadingStoreAvailability = false;
  StoreAvailabilityResponse? _storeAvailability;
  String? _storeAvailabilityError;
  String? _userPostalCode;

  BestBuyProduct get product => widget.product;

  @override
  void initState() {
    super.initState();
    // Auto-fetch store availability if product is marked as in-store available
    if (product.inStoreAvailability == true) {
      _fetchStoreAvailability();
    }
  }

  Future<void> _fetchStoreAvailability({bool preferGps = true}) async {
    if (_loadingStoreAvailability) return;

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
            if (derivedPostalCode != null && derivedPostalCode.isNotEmpty) {
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
          setState(() {
            _loadingStoreAvailability = false;
            _storeAvailabilityError = 'location_needed';
          });
          return;
        }

        setState(() {
          _storeAvailability = response;
          _loadingStoreAvailability = false;
        });
      } finally {
        client.close();
      }
    } on BestBuyException catch (e) {
      setState(() {
        _loadingStoreAvailability = false;
        _storeAvailabilityError = e.message;
      });
    } catch (e) {
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
            _buildImageSection(context, topPadding),
            
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
                  _buildStockStatus(context),
                  const SizedBox(height: 20),

                  // Action buttons - prominent placement
                  _buildActionButtons(context),
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
                    _buildCategorySection(context),
                  ],

                  // Special offers
                  if (product.offers.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildOffersSection(context),
                  ],

                  // Customer Reviews
                  if (product.customerReviewAverage != null) ...[
                    const SizedBox(height: 24),
                    _buildRatingSection(context),
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

  Widget _buildImageSection(BuildContext context, double topPadding) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surfaceVariant,
            AppColors.surface,
            AppColors.background,
          ],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Image content
          Padding(
            padding: EdgeInsets.only(top: topPadding + 50, bottom: 20),
            child: Center(
              child: product.bestImage != null
                  ? Hero(
                      tag: 'product_${product.sku}',
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(16),
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withValues(alpha: 0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Image.network(
                          product.bestImage!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.image_not_supported_outlined,
                            size: 80,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 80,
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),
          ),
          
          // Navigation buttons overlay
          Positioned(
            top: topPadding + 8,
            left: 8,
            right: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.share_outlined, color: AppColors.textPrimary),
                    onPressed: () => _shareProduct(context),
                  ),
                ),
              ],
            ),
          ),
        ],
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
        _buildPriceSection(context),
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

  Widget _buildPriceSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main price
        Text(
          '\$${product.effectivePrice?.toStringAsFixed(2) ?? 'N/A'}',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: product.onSale == true
                    ? AppColors.sale
                    : AppColors.accentYellow,
                fontWeight: FontWeight.bold,
              ),
        ),
        // Sale info: savings amount and original price
        if (product.onSale == true && product.dollarSavings != null) ...[
          const SizedBox(height: 4),
          Text(
            'You save \$${product.dollarSavings!.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
        if (product.onSale == true && product.regularPrice != null) ...[
          const SizedBox(height: 2),
          Text(
            'Originally \$${product.regularPrice!.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStockStatus(BuildContext context) {
    final isOnline = product.onlineAvailability == true;
    final isInStore = product.inStoreAvailability == true;
    final isAvailable = isOnline || isInStore;

    return Column(
      children: [
        // Main stock status card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isAvailable
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isAvailable
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.error.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? AppColors.success.withValues(alpha: 0.2)
                      : AppColors.error.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAvailable ? Icons.check_circle : Icons.cancel,
                  color: isAvailable ? AppColors.success : AppColors.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAvailable ? 'In Stock' : 'Out of Stock',
                      style: TextStyle(
                        color: isAvailable ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOnline && isInStore
                          ? 'Available online & in-store'
                          : isOnline
                              ? 'Available online only'
                              : isInStore
                                  ? 'Available in-store only'
                                  : 'Currently unavailable',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Store availability section (only for in-store products)
        if (isInStore) ...[
          const SizedBox(height: 12),
          _buildStoreAvailabilitySection(context),
        ],
      ],
    );
  }

  Widget _buildStoreAvailabilitySection(BuildContext context) {
    // Loading state
    if (_loadingStoreAvailability) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryBlue,
              ),
            ),
            SizedBox(width: 14),
            Text(
              'Finding nearest store...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Need location input
    if (_storeAvailabilityError == 'location_needed') {
      return _buildPostalCodeInput(context);
    }

    // Error state
    if (_storeAvailabilityError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Could not find nearby stores',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _fetchStoreAvailability,
                  child: const Text('Retry'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildPostalCodeInput(context, compact: true),
          ],
        ),
      );
    }

    // Store found
    if (_storeAvailability != null && _storeAvailability!.hasAvailableStores) {
      return _buildNearestStoreCard(context, _storeAvailability!);
    }

    // No stores available - show search option
    if (_storeAvailability != null && !_storeAvailability!.hasAvailableStores) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.store_outlined,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'No stores with this product nearby',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPostalCodeInput(context, compact: true),
          ],
        ),
      );
    }

    // Default: Show find store button
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _fetchStoreAvailability,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on_outlined, 
                       size: 20, color: AppColors.primaryBlue),
                  SizedBox(width: 8),
                  Text(
                    'Find Nearest Store',
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostalCodeInput(BuildContext context, {bool compact = false}) {
    final controller = TextEditingController(text: _userPostalCode);
    
    return Container(
      padding: compact ? EdgeInsets.zero : const EdgeInsets.all(16),
      decoration: compact
          ? null
          : BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) ...[
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Enter your ZIP code to find stores',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    hintText: '12345',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                      letterSpacing: 2,
                    ),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
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
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.length == 5) {
                    _searchByPostalCode(controller.text);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Search',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          // Option to switch back to GPS if not already using it
          if (_userPostalCode != null) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: _useCurrentLocation,
                icon: const Icon(Icons.my_location, size: 16),
                label: const Text('Use Current Location'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNearestStoreCard(
    BuildContext context,
    StoreAvailabilityResponse availability,
  ) {
    final store = availability.nearestStore!;
    final otherStoresCount = availability.stores.length - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryBlue.withValues(alpha: 0.1),
            AppColors.primaryBlue.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.store,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nearest Store with Stock',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      store.name ?? 'Best Buy',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              if (store.distance != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentYellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.directions_car_outlined,
                        size: 14,
                        color: AppColors.accentYellow,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        store.distanceFormatted ?? '',
                        style: const TextStyle(
                          color: AppColors.accentYellow,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  store.fullAddress,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),

          // Low stock warning
          if (store.lowStock) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentYellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: AppColors.accentYellow,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Low Stock - Act Fast!',
                    style: TextStyle(
                      color: AppColors.accentYellow,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Pickup eligibility
          if (availability.ispuEligible) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 14,
                  color: AppColors.success.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  store.minPickupHours != null
                      ? 'Ready for pickup in ${store.minPickupHours}+ hours'
                      : 'Eligible for in-store pickup',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],

          // Other stores available
          if (otherStoresCount > 0) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _showAllStores(context, availability),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '+$otherStoresCount more store${otherStoresCount == 1 ? '' : 's'} nearby',
                      style: const TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.primaryBlue,
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Actions row
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openDirections(store),
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Directions'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(color: AppColors.primaryBlue),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showPostalCodeDialog(context),
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Change Location'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAllStores(BuildContext context, StoreAvailabilityResponse availability) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.store, color: AppColors.primaryBlue),
                  const SizedBox(width: 12),
                  Text(
                    '${availability.stores.length} Stores with Stock',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            // Store list
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: availability.stores.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final store = availability.stores[index];
                  return _buildStoreListItem(context, store, index == 0);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreListItem(
    BuildContext context,
    StoreAvailability store,
    bool isNearest,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isNearest
            ? AppColors.primaryBlue.withValues(alpha: 0.1)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNearest
              ? AppColors.primaryBlue.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      store.name ?? 'Best Buy',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (isNearest) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'NEAREST',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                    if (store.lowStock) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentYellow.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LOW STOCK',
                          style: TextStyle(
                            color: AppColors.accentYellow,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  store.fullAddress,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (store.distance != null)
                Text(
                  store.distanceFormatted ?? '',
                  style: const TextStyle(
                    color: AppColors.accentYellow,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _openDirections(store),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.directions,
                        size: 14,
                        color: AppColors.primaryBlue,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Go',
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openDirections(StoreAvailability store) async {
    final address = Uri.encodeComponent(store.fullAddress);
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$address';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showPostalCodeDialog(BuildContext context) {
    final controller = TextEditingController(text: _userPostalCode);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Enter ZIP Code',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 5,
          autofocus: true,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            letterSpacing: 4,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '12345',
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.5),
              letterSpacing: 4,
            ),
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primaryBlue,
                width: 2,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.length == 5) {
                _searchByPostalCode(controller.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
            ),
            child: const Text(
              'Search',
              style: TextStyle(color: Colors.white),
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

  Widget _buildCategorySection(BuildContext context) {
    final categories = product.categoryPath;
    final showExpand = categories.length > 2;
    
    // Get last 2 categories for collapsed view
    final collapsedCategories = categories.length <= 2
        ? categories
        : categories.sublist(categories.length - 2);

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
              child: const Icon(Icons.category_outlined,
                  size: 20, color: AppColors.primaryBlue),
            ),
            const SizedBox(width: 12),
            Text(
              'Category',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedCrossFade(
          firstChild: _buildCollapsedCategoryView(collapsedCategories, categories.length),
          secondChild: _buildExpandedCategoryView(categories),
          crossFadeState: _categoryExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
        if (showExpand) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _categoryExpanded = !_categoryExpanded),
            child: Row(
              children: [
                Text(
                  _categoryExpanded
                      ? 'Show less'
                      : 'Show full hierarchy (${categories.length} levels)',
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _categoryExpanded
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

  Widget _buildCollapsedCategoryView(List<CategoryPath> categories, int totalCount) {
    return Row(
      children: [
        if (totalCount > 2) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '...',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.chevron_right,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        ...categories.asMap().entries.map((entry) {
          final isLast = entry.key == categories.length - 1;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isLast
                      ? AppColors.primaryBlue.withValues(alpha: 0.15)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isLast
                        ? AppColors.primaryBlue.withValues(alpha: 0.4)
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  entry.value.name ?? 'Unknown',
                  style: TextStyle(
                    color: isLast ? AppColors.primaryBlue : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (!isLast)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildExpandedCategoryView(List<CategoryPath> categories) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: categories.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          final isLast = index == categories.length - 1;
          
          return Padding(
            padding: EdgeInsets.only(
              left: index * 16.0,
              top: index > 0 ? 8 : 0,
            ),
            child: Row(
              children: [
                if (index > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.subdirectory_arrow_right,
                      size: 16,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isLast
                        ? AppColors.primaryBlue.withValues(alpha: 0.15)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                    border: isLast
                        ? Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.4))
                        : null,
                  ),
                  child: Text(
                    category.name ?? 'Unknown',
                    style: TextStyle(
                      color: isLast ? AppColors.primaryBlue : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
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

  Widget _buildRatingSection(BuildContext context) {
    final rating = product.customerReviewAverage!;
    final count = product.customerReviewCount ?? 0;
    
    // Determine rating tier and color
    final (String tier, Color tierColor) = switch (rating) {
      >= 4.5 => ('Excellent', AppColors.success),
      >= 4.0 => ('Very Good', const Color(0xFF8BC34A)),
      >= 3.5 => ('Good', AppColors.accentYellow),
      >= 3.0 => ('Average', const Color(0xFFFF9800)),
      >= 2.0 => ('Fair', const Color(0xFFFF5722)),
      _ => ('Poor', AppColors.error),
    };
    
    // Review count context
    final String countContext = switch (count) {
      >= 1000 => 'Very popular',
      >= 500 => 'Popular choice',
      >= 100 => 'Well reviewed',
      >= 25 => 'Reviewed',
      >= 5 => 'Limited reviews',
      _ => 'Few reviews',
    };

    return _buildSection(
      context,
      title: 'Customer Reviews',
      icon: Icons.star_outline,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            // Main rating row
            Row(
              children: [
                // Score display
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tierColor.withValues(alpha: 0.2),
                        tierColor.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: tierColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: tierColor,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'out of 5',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Rating details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: tierColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tier,
                              style: TextStyle(
                                color: tierColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            countContext,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Star display
                      Row(
                        children: List.generate(5, (index) {
                          if (index < rating.floor()) {
                            return const Icon(Icons.star,
                                color: AppColors.brightYellow, size: 20);
                          } else if (index < rating) {
                            return const Icon(Icons.star_half,
                                color: AppColors.brightYellow, size: 20);
                          } else {
                            return Icon(Icons.star_border,
                                color: AppColors.textSecondary.withValues(alpha: 0.4),
                                size: 20);
                          }
                        }),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_formatReviewCount(count)} ${count == 1 ? 'review' : 'reviews'}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Rating distribution bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: (rating * 20).round(),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              tierColor,
                              tierColor.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 100 - (rating * 20).round(),
                      child: Container(
                        color: AppColors.surfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Scale labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '1',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  '5',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatReviewCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        // Ask AI button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _navigateToAskAI(context),
            icon: const Icon(Icons.smart_toy_outlined, size: 18),
            label: const Text('Ask AI'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentYellow,
              foregroundColor: AppColors.background,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (product.url != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _openUrl(product.url!),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('See on BestBuy.com'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
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
