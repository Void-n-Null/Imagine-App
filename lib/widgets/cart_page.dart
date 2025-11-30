import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/api_keys.dart';
import '../services/bestbuy/bestbuy.dart';
import '../services/storage/cart_service.dart';
import '../theme/app_colors.dart';
import 'product_detail_page.dart';
import 'scan_product_page.dart';

/// Page for viewing and managing the shopping cart.
/// Features a list view and a carousel scan mode for easy barcode scanning.
class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final CartService _cart = CartService.instance;
  final BestBuyClient _client = BestBuyClient(apiKey: ApiKeys.bestBuy);
  final PageController _carouselController = PageController();
  
  bool _isCarouselMode = false;
  int _currentCarouselIndex = 0;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    _carouselController.dispose();
    _client.close();
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  void _navigateToScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ScanProductPage(),
      ),
    );
  }

  Future<void> _removeItem(int sku) async {
    final item = _cart.getItemBySku(sku);
    await _cart.removeFromCart(sku);
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${item?.name ?? 'item'}" from cart'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            if (item != null) {
              await _cart.addItem(item);
            }
          },
        ),
      ),
    );
  }

  Future<void> _clearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear Cart?'),
        content: Text('Remove all ${_cart.itemCount} items from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cart.clearCart();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cart cleared')),
        );
      }
    }
  }

  Future<void> _openProductDetail(int sku) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      ),
    );

    try {
      final product = await _client.getProductBySku(sku);
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (product != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(product: product),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load product details')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 22),
            const SizedBox(width: 8),
            Text(
              'Cart (${_cart.itemCount})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          if (_cart.isNotEmpty) ...[
            // Toggle carousel/list mode
            IconButton(
              icon: Icon(
                _isCarouselMode 
                    ? Icons.view_list_rounded 
                    : Icons.view_carousel_rounded,
              ),
              tooltip: _isCarouselMode ? 'List View' : 'Scan Mode',
              onPressed: () {
                setState(() {
                  _isCarouselMode = !_isCarouselMode;
                  if (_isCarouselMode) {
                    _currentCarouselIndex = 0;
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear Cart',
              onPressed: _clearCart,
            ),
          ],
        ],
      ),
      body: _cart.isEmpty
          ? _buildEmptyState()
          : _isCarouselMode
              ? _buildCarouselView()
              : _buildListView(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToScanner,
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
        label: const Text(
          'Scan to Add',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan products or add them from product pages',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _cart.items.length,
      itemBuilder: (context, index) {
        final item = _cart.items[index];
        return _CartItemCard(
          item: item,
          onTap: () => _openProductDetail(item.sku),
          onRemove: () => _removeItem(item.sku),
        );
      },
    );
  }

  Widget _buildCarouselView() {
    final items = _cart.items;
    
    return Column(
      children: [
        // Page indicator
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _currentCarouselIndex > 0
                    ? () {
                        _carouselController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentCarouselIndex + 1} of ${items.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _currentCarouselIndex < items.length - 1
                    ? () {
                        _carouselController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
              ),
            ],
          ),
        ),

        // Carousel
        Expanded(
          child: PageView.builder(
            controller: _carouselController,
            onPageChanged: (index) {
              setState(() => _currentCarouselIndex = index);
            },
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _CarouselCard(
                item: items[index],
                onTap: () => _openProductDetail(items[index].sku),
                onRemove: () => _removeItem(items[index].sku),
              );
            },
          ),
        ),

        // Bottom padding for FAB
        const SizedBox(height: 80),
      ],
    );
  }
}

/// Card widget for displaying a cart item in the list view.
class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _CartItemCard({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.userMessageBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border.withOpacity(0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Product image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: item.thumbnailImage != null
                      ? Image.network(
                          item.thumbnailImage!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                        )
                      : _buildImagePlaceholder(),
                ),
              ),
              const SizedBox(width: 12),

              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (item.price != null)
                          Text(
                            '\$${item.price!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentYellow,
                            ),
                          ),
                        if (item.manufacturer != null) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.manufacturer!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              Column(
                children: [
                  // Navigate chevron
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Remove button
                  GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppColors.error.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.surfaceVariant,
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 24,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// Card widget for displaying a cart item in carousel/scan mode.
class _CarouselCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _CarouselCard({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

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

  Future<void> _copyUpc(BuildContext context) async {
    if (item.upc == null) return;
    await Clipboard.setData(ClipboardData(text: item.upc!));
    await HapticFeedback.lightImpact();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('UPC copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              // Product image
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: item.thumbnailImage != null
                      ? Image.network(
                          item.thumbnailImage!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                        )
                      : _buildImagePlaceholder(),
                ),
              ),

              // Product info and barcode - use SingleChildScrollView to prevent overflow
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Product name
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // Price and brand
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (item.price != null)
                            Text(
                              '\$${item.price!.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentYellow,
                              ),
                            ),
                          if (item.manufacturer != null) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.manufacturer!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 12),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 10),

                      // Barcode section
                      if (item.upc != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 14,
                              color: AppColors.accentYellow,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Scan at Register',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _copyUpc(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.copy,
                                      size: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Copy',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              bw.BarcodeWidget(
                                barcode: bw.Barcode.upcA(),
                                data: _normalizeUpc(item.upc!),
                                width: 160,
                                height: 45,
                                color: Colors.black,
                                backgroundColor: Colors.white,
                                drawText: false,
                                errorBuilder: (context, error) {
                                  return bw.BarcodeWidget(
                                    barcode: bw.Barcode.ean13(),
                                    data: _normalizeUpc(item.upc!),
                                    width: 160,
                                    height: 45,
                                    color: Colors.black,
                                    backgroundColor: Colors.white,
                                    drawText: false,
                                    errorBuilder: (context, error) {
                                      return const Text(
                                        'Barcode unavailable',
                                        style: TextStyle(color: Colors.grey),
                                      );
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.upc!,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'No barcode available',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onRemove,
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: const Text('Remove', style: TextStyle(fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: BorderSide(
                                  color: AppColors.error.withOpacity(0.5),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: onTap,
                              icon: const Icon(Icons.info_outline, size: 16),
                              label: const Text('Details', style: TextStyle(fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return const Icon(
      Icons.inventory_2_outlined,
      size: 64,
      color: AppColors.textSecondary,
    );
  }
}
