import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/bestbuy/bestbuy.dart';
import '../theme/app_colors.dart';
import 'product_detail_page.dart';

/// A compact product badge that displays product info inline in chat messages.
class ProductBadge extends StatefulWidget {
  final int sku;
  final BestBuyClient client;
  
  const ProductBadge({
    super.key,
    required this.sku,
    required this.client,
  });

  @override
  State<ProductBadge> createState() => _ProductBadgeState();
}

class _ProductBadgeState extends State<ProductBadge> with AutomaticKeepAliveClientMixin {
  BestBuyProduct? _product;
  bool _isLoading = true;
  String? _error;
  int _retryCount = 0;
  static const int _maxRetries = 5;
  static const Duration _retryDelay = Duration(seconds: 2);
  
  @override
  bool get wantKeepAlive => true; // Keep widget alive when scrolled off-screen

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    try {
      final product = await widget.client.getProductBySku(widget.sku);
      if (mounted) {
        if (product != null) {
          debugPrint('✅ Loaded product: ${product.name}');
          debugPrint('   thumbnailImage: ${product.thumbnailImage}');
          debugPrint('   mediumImage: ${product.mediumImage}');
          debugPrint('   image: ${product.image}');
        }
        setState(() {
          _product = product;
          _isLoading = false;
          if (product == null) {
            _error = 'Product not found';
          }
        });
      }
    } catch (e) {
      // Silently retry with delay if we haven't exceeded max retries (handles rate limiting)
      if (_retryCount < _maxRetries && mounted) {
        _retryCount++;
        await Future.delayed(_retryDelay);
        if (mounted) {
          await _loadProduct();
        }
        return;
      }
      
      // All retries exhausted - SKU is likely invalid
      debugPrint('❌ Product ${widget.sku} not found after $_maxRetries retries: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Product not found';
        });
      }
    }
  }

  void _openProductDetail() {
    if (_product != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ProductDetailPage(product: _product!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return GestureDetector(
      onTap: _product != null ? _openProductDetail : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.userMessageBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.border.withOpacity(0.5),
          ),
        ),
        child: _isLoading
            ? _buildLoading()
            : _error != null
                ? _buildError()
                : _buildProduct(),
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Loading product...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Text(
            '$_error (SKU: ${widget.sku})',
            style: TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildProduct() {
    final product = _product!;
    
    // Get best available image
    final imageUrl = product.thumbnailImage ?? 
                     product.mediumImage ?? 
                     product.image ?? 
                     product.largeImage;
    
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Product image
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryBlue,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, error, ___) {
                        debugPrint('❌ Image load error: $error for $imageUrl');
                        return _buildImagePlaceholder();
                      },
                    )
                  : _buildImagePlaceholder(),
            ),
          ),
          const SizedBox(width: 12),
          
          // Product info
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (product.onSale == true && product.regularPrice != null) ...[
                      Text(
                        '\$${product.regularPrice!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      '\$${product.effectivePrice?.toStringAsFixed(2) ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: product.onSale == true 
                            ? AppColors.sale 
                            : AppColors.accentYellow,
                      ),
                    ),
                    if (product.onSale == true) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.sale.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'SALE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.sale,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Chevron
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.surfaceVariant,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 20,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// Parses message content and extracts product SKUs from [Product(SKU)] syntax.
class ProductBadgeParser {
  static final RegExp _productPattern = RegExp(r'\[Product\((\d+)\)\]');
  
  /// Parse message content and return a list of widgets (text and product badges).
  static List<InlineSpan> parseToSpans(
    String content,
    BestBuyClient client,
    BuildContext context,
  ) {
    final spans = <InlineSpan>[];
    int lastEnd = 0;
    
    for (final match in _productPattern.allMatches(content)) {
      // Add text before this match
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }
      
      // Add placeholder for product badge
      final sku = int.parse(match.group(1)!);
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: ProductBadge(sku: sku, client: client),
      ));
      
      lastEnd = match.end;
    }
    
    // Add remaining text
    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }
    
    return spans;
  }
  
  /// Check if content contains any product references.
  static bool hasProducts(String content) {
    return _productPattern.hasMatch(content);
  }
  
  /// Extract all SKUs from content.
  static List<int> extractSkus(String content) {
    return _productPattern
        .allMatches(content)
        .map((m) => int.parse(m.group(1)!))
        .toList();
  }
}

