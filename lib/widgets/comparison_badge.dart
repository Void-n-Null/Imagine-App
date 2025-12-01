import 'package:flutter/material.dart';
import '../services/bestbuy/bestbuy.dart';
import '../services/comparison/comparison_service.dart';
import '../theme/app_colors.dart';
import 'product_comparison_page.dart';

/// A compact comparison badge that displays products side by side inline in chat messages.
/// Tapping opens the full comparison page.
class ComparisonBadge extends StatefulWidget {
  final List<int> skus;
  final BestBuyClient client;
  
  const ComparisonBadge({
    super.key,
    required this.skus,
    required this.client,
  });

  @override
  State<ComparisonBadge> createState() => _ComparisonBadgeState();
}

class _ComparisonBadgeState extends State<ComparisonBadge> with AutomaticKeepAliveClientMixin {
  List<BestBuyProduct?> _products = [];
  bool _isLoading = true;
  String? _error;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = <BestBuyProduct?>[];
      
      for (final sku in widget.skus) {
        try {
          final product = await widget.client.getProductBySku(sku);
          products.add(product);
        } catch (e) {
          debugPrint('Error loading product $sku: $e');
          products.add(null);
        }
      }
      
      if (mounted) {
        // Check if we got at least 2 valid products
        final validProducts = products.where((p) => p != null).length;
        
        if (validProducts < 2 && _retryCount < _maxRetries) {
          _retryCount++;
          await Future.delayed(_retryDelay);
          if (mounted) {
            await _loadProducts();
          }
          return;
        }
        
        setState(() {
          _products = products;
          _isLoading = false;
          if (validProducts < 2) {
            _error = 'Could not load products';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load comparison';
        });
      }
    }
  }

  void _openComparison() async {
    // Add products to comparison service if not already there
    final comparison = ComparisonService.instance;
    
    for (final product in _products) {
      if (product != null && !comparison.containsSku(product.sku)) {
        await comparison.addToComparison(product);
      }
    }
    
    if (!mounted) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProductComparisonPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GestureDetector(
      onTap: _products.where((p) => p != null).length >= 2 ? _openComparison : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryBlue.withValues(alpha: 0.15),
              AppColors.secondaryBlue.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
          ),
        ),
        child: _isLoading
            ? _buildLoading()
            : _error != null
                ? _buildError()
                : _buildComparison(),
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading comparison...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: 10),
          Text(
            '$_error',
            style: TextStyle(color: AppColors.error, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildComparison() {
    final validProducts = _products.where((p) => p != null).cast<BestBuyProduct>().toList();
    
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.compare_arrows_rounded,
                  size: 16,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Product Comparison',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${validProducts.length} items',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Products row
          SizedBox(
            height: 90,
            child: Row(
              children: [
                for (int i = 0; i < validProducts.length; i++) ...[
                  Expanded(child: _buildProductCell(validProducts[i])),
                  if (i < validProducts.length - 1)
                    Container(
                      width: 1,
                      height: 70,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: AppColors.border,
                    ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Tap to compare hint
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tap to compare',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppColors.primaryBlue,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductCell(BestBuyProduct product) {
    final imageUrl = product.thumbnailImage ?? 
                     product.mediumImage ?? 
                     product.image ?? 
                     product.largeImage;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Product image
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, stackTrace) => _buildImagePlaceholder(),
                  )
                : _buildImagePlaceholder(),
          ),
        ),
        const SizedBox(height: 6),
        
        // Product name (truncated)
        Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        
        const SizedBox(height: 2),
        
        // Price
        Text(
          '\$${product.effectivePrice?.toStringAsFixed(2) ?? 'N/A'}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: product.onSale == true 
                ? AppColors.sale 
                : AppColors.accentYellow,
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.surfaceVariant,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 18,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// Parses message content and extracts comparison SKUs from [Compare(SKU1,SKU2,...)] syntax.
class ComparisonBadgeParser {
  static final RegExp _comparePattern = RegExp(r'\[Compare\(([0-9,\s]+)\)\]');
  
  /// Check if content contains any comparison references.
  static bool hasComparisons(String content) {
    return _comparePattern.hasMatch(content);
  }
  
  /// Extract all comparison groups from content.
  /// Returns a list of SKU lists (each inner list is a comparison group).
  static List<List<int>> extractComparisonGroups(String content) {
    return _comparePattern.allMatches(content).map((match) {
      final skuString = match.group(1)!;
      return skuString
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .where((sku) => sku != null)
          .cast<int>()
          .toList();
    }).where((skus) => skus.length >= 2).toList();
  }
  
  /// Parse message content and return a list of widgets (text and comparison badges).
  static List<InlineSpan> parseToSpans(
    String content,
    BestBuyClient client,
    BuildContext context,
  ) {
    final spans = <InlineSpan>[];
    int lastEnd = 0;
    
    for (final match in _comparePattern.allMatches(content)) {
      // Add text before this match
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }
      
      // Parse SKUs
      final skuString = match.group(1)!;
      final skus = skuString
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .where((sku) => sku != null)
          .cast<int>()
          .toList();
      
      if (skus.length >= 2) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: ComparisonBadge(skus: skus, client: client),
        ));
      } else {
        // If not enough SKUs, just show the original text
        spans.add(TextSpan(text: match.group(0)));
      }
      
      lastEnd = match.end;
    }
    
    // Add remaining text
    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }
    
    return spans;
  }
}
