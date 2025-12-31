import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/api_keys.dart';
import '../services/bestbuy/bestbuy.dart';
import '../services/comparison/comparison.dart';
import '../theme/app_colors.dart';
import 'product_detail_page.dart';
import 'scan_product_page.dart';

/// Full-screen page for comparing multiple products side by side.
class ProductComparisonPage extends StatefulWidget {
  const ProductComparisonPage({super.key});

  @override
  State<ProductComparisonPage> createState() => _ProductComparisonPageState();
}

class _ProductComparisonPageState extends State<ProductComparisonPage> {
  final ComparisonService _comparison = ComparisonService.instance;
  final ProductComparisonEngine _engine = ProductComparisonEngine();
  
  bool _isLoading = true;
  bool _isLoadingInProgress = false; // Prevent re-entry
  bool _isVerticalLayout = false;
  bool _showOnlyDifferences = false;
  String? _error;
  
  List<BestBuyProduct> _products = [];
  ProductComparisonResult? _result;

  @override
  void initState() {
    super.initState();
    _comparison.addListener(_onComparisonChanged);
    _loadProducts();
  }

  @override
  void dispose() {
    _comparison.removeListener(_onComparisonChanged);
    super.dispose();
  }

  void _onComparisonChanged() {
    if (mounted && !_isLoadingInProgress) {
      _loadProducts();
    }
  }

  Future<void> _loadProducts() async {
    // Prevent re-entry (avoids infinite loop from setProductDetails)
    if (_isLoadingInProgress) return;
    _isLoadingInProgress = true;
    
    if (_comparison.isEmpty) {
      setState(() {
        _isLoading = false;
        _products = [];
        _result = null;
      });
      _isLoadingInProgress = false;
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = BestBuyClient(apiKey: ApiKeys.bestBuy);
      final skus = _comparison.skus;
      final products = <BestBuyProduct>[];

      // Fetch each product's full details
      for (final sku in skus) {
        // Check if we have cached details
        final cached = _comparison.getProductDetails(sku);
        if (cached != null) {
          products.add(cached);
        } else {
          try {
            final product = await client.getProductBySku(sku);
            if (product != null) {
              products.add(product);
            }
          } catch (e) {
            debugPrint('Error fetching product $sku: $e');
          }
        }
      }

      client.close();

      // Cache product details (don't notify - we're already updating UI)
      _comparison.setProductDetailsQuietly(products);

      if (mounted) {
        setState(() {
          _products = products;
          _result = products.length >= 2 ? _engine.compare(products) : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load products: $e';
        });
      }
    } finally {
      _isLoadingInProgress = false;
    }
  }

  void _removeProduct(int sku) async {
    await HapticFeedback.lightImpact();
    await _comparison.removeFromComparison(sku);
    
    if (!mounted) return;
    
    if (_comparison.itemCount < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least 2 products to compare'),
        ),
      );
    }
  }

  void _clearAll() async {
    await HapticFeedback.mediumImpact();
    await _comparison.clearComparison();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _openProductDetail(BestBuyProduct product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(product: product),
      ),
    );
  }

  void _navigateToAddProducts() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ScanProductPage(),
        settings: const RouteSettings(
          arguments: ComparisonModeArgs(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'Compare (${_comparison.itemCount})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Layout toggle
          IconButton(
            icon: Icon(
              _isVerticalLayout 
                  ? Icons.table_chart_rounded 
                  : Icons.view_agenda_rounded,
            ),
            tooltip: _isVerticalLayout ? 'Spreadsheet View' : 'Card View',
            onPressed: () {
              setState(() {
                _isVerticalLayout = !_isVerticalLayout;
              });
            },
          ),
          // Filter toggle
          IconButton(
            icon: Icon(
              _showOnlyDifferences 
                  ? Icons.difference_rounded 
                  : Icons.list_alt_rounded,
              color: _showOnlyDifferences ? AppColors.accentYellow : null,
            ),
            tooltip: _showOnlyDifferences ? 'Show All' : 'Show Only Differences',
            onPressed: () {
              setState(() {
                _showOnlyDifferences = !_showOnlyDifferences;
              });
            },
          ),
          // Add products
          if (!_comparison.isFull)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add Products',
              onPressed: _navigateToAddProducts,
            ),
          // Clear all
          if (_comparison.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Clear Comparison',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primaryBlue),
            SizedBox(height: 16),
            Text(
              'Loading products...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadProducts,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.length < 2) {
      return _buildEmptyState();
    }

    if (_result == null) {
      return const Center(
        child: Text(
          'Unable to generate comparison',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return _isVerticalLayout 
        ? _buildVerticalLayout() 
        : _buildHorizontalLayout();
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
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.compare_arrows_rounded,
                size: 64,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Add Products to Compare',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Scan or search for products to add them to your comparison list.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _navigateToAddProducts,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Products'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                side: const BorderSide(color: AppColors.primaryBlue),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SPREADSHEET LAYOUT (Products as columns, Attributes as rows)
  // ============================================================

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  bool _isSyncingScroll = false;

  Widget _buildHorizontalLayout() {
    final result = _result!;
    final rows = _showOnlyDifferences 
        ? result.rowsWithDifferences 
        : result.rows;

    const double attrColumnWidth = 120.0;
    const double productColumnWidth = 140.0;
    const double rowHeight = 44.0;
    final double totalProductsWidth = productColumnWidth * _products.length;
    final double totalRowsHeight = rowHeight * rows.length;

    return Column(
      children: [
        // Product headers row (fixed at top)
        Container(
          height: 110,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 2),
            ),
          ),
          child: Row(
            children: [
              // Fixed "Specs" column header
              Container(
                width: attrColumnWidth,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceVariant,
                  border: Border(
                    right: BorderSide(color: AppColors.border, width: 2),
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Specs',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              
              // Scrollable product headers
              Expanded(
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: totalProductsWidth,
                    child: Row(
                      children: [
                        for (int i = 0; i < _products.length; i++)
                          _buildProductHeaderCell(_products[i], i, productColumnWidth),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Attribute rows (both columns scroll together vertically)
        Expanded(
          child: SingleChildScrollView(
            controller: _verticalScrollController,
            child: SizedBox(
              height: totalRowsHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fixed attribute names column
                  SizedBox(
                    width: attrColumnWidth,
                    child: Column(
                      children: [
                        for (int i = 0; i < rows.length; i++)
                          _buildAttributeNameCell(rows[i], i),
                      ],
                    ),
                  ),
                  
                  // Scrollable values area (horizontal only, synced with header)
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (_isSyncingScroll) return false;
                        if (notification is ScrollUpdateNotification &&
                            notification.metrics.axis == Axis.horizontal) {
                          _isSyncingScroll = true;
                          _horizontalScrollController.jumpTo(notification.metrics.pixels);
                          _isSyncingScroll = false;
                        }
                        return false;
                      },
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        child: SizedBox(
                          width: totalProductsWidth,
                          child: Column(
                            children: [
                              for (int i = 0; i < rows.length; i++)
                                _buildValueRow(rows[i], i, productColumnWidth),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductHeaderCell(BestBuyProduct product, int index, double width) {
    return GestureDetector(
      onTap: () => _openProductDetail(product),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: AppColors.surfaceVariant,
          border: Border(
            right: BorderSide(color: AppColors.border),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Remove button
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => _removeProduct(product.sku),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 12,
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
            
            // Product image
            if (product.bestImage != null)
              SizedBox(
                height: 40,
                child: Image.network(
                  product.bestImage!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.image_not_supported_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              const Icon(
                Icons.inventory_2_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
            
            const SizedBox(height: 4),
            
            // Product name (properly constrained)
            SizedBox(
              height: 24,
              child: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ),
            
            // Price
            if (product.effectivePrice != null)
              Text(
                '\$${product.effectivePrice!.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: product.onSale == true 
                      ? AppColors.sale 
                      : AppColors.accentYellow,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttributeNameCell(ComparisonRow row, int rowIndex) {
    final isDifferent = !row.allValuesSame;
    
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDifferent 
            ? AppColors.accentYellow.withValues(alpha: 0.1)
            : AppColors.surfaceVariant,
        border: const Border(
          right: BorderSide(color: AppColors.border, width: 2),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        row.attributeName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isDifferent ? FontWeight.bold : FontWeight.normal,
          color: isDifferent ? AppColors.textPrimary : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildValueRow(ComparisonRow row, int rowIndex, double columnWidth) {
    final isDifferent = !row.allValuesSame;
    
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDifferent 
            ? AppColors.accentYellow.withValues(alpha: 0.05)
            : rowIndex.isEven ? AppColors.surface : AppColors.surfaceVariant.withValues(alpha: 0.3),
        border: const Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < _products.length; i++)
            _buildValueCell(row, i, columnWidth),
        ],
      ),
    );
  }

  Widget _buildValueCell(ComparisonRow row, int productIndex, double width) {
    final value = row.values.length > productIndex ? row.values[productIndex] : null;
    final isNull = value == null;
    
    // Determine if this value is "best"
    bool isBest = false;
    if (row.hasNumericComparison && row.comparison != null && value != null) {
      if (_result!.isTwoProductComparison) {
        final diff = row.comparison!.numericDifference;
        if (diff != null) {
          isBest = (diff.absoluteDifference > 0 && productIndex == 1) ||
                   (diff.absoluteDifference < 0 && productIndex == 0);
        }
      } else {
        final stats = row.comparison!.numericStats;
        if (stats != null) {
          isBest = stats.maxProductIndices.contains(productIndex);
        }
      }
    }
    
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isBest 
            ? AppColors.success.withValues(alpha: 0.15) 
            : Colors.transparent,
        border: const Border(
          right: BorderSide(color: AppColors.border),
        ),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isBest)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Icon(
                Icons.check_circle_rounded,
                size: 10,
                color: AppColors.success,
              ),
            ),
          Flexible(
            child: Text(
              isNull ? '—' : value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isNull 
                    ? AppColors.textSecondary 
                    : isBest 
                        ? AppColors.success 
                        : AppColors.textPrimary,
                fontWeight: isBest ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    if (_result == null || !_result!.isTwoProductComparison) return const SizedBox.shrink();

    final numericRows = _result!.numericRows;
    if (numericRows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryBlue.withValues(alpha: 0.15),
            AppColors.secondaryBlue.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Quick Comparison',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Show key numeric differences
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: numericRows.take(6).map((row) {
              final diff = row.comparison?.numericDifference;
              if (diff == null) return const SizedBox.shrink();
              
              return _buildDifferenceChip(row.attributeName, diff);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDifferenceChip(String name, NumericDifference diff) {
    final isPositive = diff.absoluteDifference > 0;
    final isNegative = diff.absoluteDifference < 0;
    final color = isPositive ? AppColors.success : (isNegative ? AppColors.error : AppColors.textSecondary);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            diff.shortDescription,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(List<ComparisonRow> rows) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            _showOnlyDifferences 
                ? 'No differences found between products'
                : 'No comparable attributes found',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            _buildComparisonRow(rows[i], i),
            if (i < rows.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonRow(ComparisonRow row, int index) {
    final isDifferent = !row.allValuesSame;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDifferent 
            ? AppColors.accentYellow.withValues(alpha: 0.05) 
            : Colors.transparent,
        borderRadius: BorderRadius.only(
          topLeft: index == 0 ? const Radius.circular(12) : Radius.zero,
          topRight: index == 0 ? const Radius.circular(12) : Radius.zero,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Attribute name
          Row(
            children: [
              Expanded(
                child: Text(
                  row.attributeName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isDifferent ? FontWeight.w600 : FontWeight.normal,
                    color: isDifferent ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
              if (row.hasNumericComparison && row.comparison != null)
                _buildNumericIndicator(row),
            ],
          ),
          const SizedBox(height: 8),
          
          // Values row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < row.values.length; i++) ...[
                  _buildValueCell(row, i, 140),
                  if (i < row.values.length - 1) const SizedBox(width: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumericIndicator(ComparisonRow row) {
    if (!row.hasNumericComparison || row.comparison == null) {
      return const SizedBox.shrink();
    }

    if (_result!.isTwoProductComparison) {
      final diff = row.comparison!.numericDifference;
      if (diff == null) return const SizedBox.shrink();
      
      final pct = diff.percentageDifference;
      if (pct == null || pct.abs() < 0.5) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}%',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
          ),
        ),
      );
    } else {
      final stats = row.comparison!.numericStats;
      if (stats == null) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          stats.rangeDescription,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
  }

  Widget _buildUniqueAttributesSection() {
    final uniqueRows = _result!.uniqueRows;
    if (uniqueRows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.star_outline_rounded,
                size: 18,
                color: AppColors.accentYellow,
              ),
              const SizedBox(width: 8),
              const Text(
                'Unique Features',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          for (final row in uniqueRows) ...[
            _buildUniqueRow(row),
            if (row != uniqueRows.last)
              const Divider(height: 16, color: AppColors.border),
          ],
        ],
      ),
    );
  }

  Widget _buildUniqueRow(ComparisonRow row) {
    final productIndex = row.uniqueProductIndex ?? 0;
    final value = row.values[productIndex];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product indicator
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              '${productIndex + 1}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.attributeName,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value ?? '—',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // VERTICAL LAYOUT (Products as rows)
  // ============================================================

  Widget _buildVerticalLayout() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length + 1, // +1 for summary
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildVerticalSummary();
        }
        return _buildVerticalProductCard(_products[index - 1], index - 1);
      },
    );
  }

  Widget _buildVerticalSummary() {
    if (_result == null || !_result!.isTwoProductComparison) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryBlue.withValues(alpha: 0.15),
            AppColors.secondaryBlue.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Key Differences',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _result!.numericRows.take(8).map((row) {
              final diff = row.comparison?.numericDifference;
              if (diff == null) return const SizedBox.shrink();
              return _buildDifferenceChip(row.attributeName, diff);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalProductCard(BestBuyProduct product, int index) {
    final rows = _showOnlyDifferences 
        ? _result!.rowsWithDifferences 
        : _result!.rows;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Product header
          GestureDetector(
            onTap: () => _openProductDetail(product),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  // Product image
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: product.bestImage != null
                        ? Image.network(
                            product.bestImage!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.image_not_supported_outlined,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : const Icon(
                            Icons.inventory_2_outlined,
                            color: AppColors.textSecondary,
                          ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Product info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (product.effectivePrice != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '\$${product.effectivePrice!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: product.onSale == true 
                                  ? AppColors.sale 
                                  : AppColors.accentYellow,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Remove button
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.error,
                    onPressed: () => _removeProduct(product.sku),
                  ),
                ],
              ),
            ),
          ),
          
          // Specifications
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (int i = 0; i < rows.length && i < 10; i++) ...[
                  _buildVerticalSpecRow(rows[i], index),
                  if (i < rows.length - 1 && i < 9)
                    const Divider(height: 1, color: AppColors.border),
                ],
                if (rows.length > 10)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '+${rows.length - 10} more specifications',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalSpecRow(ComparisonRow row, int productIndex) {
    final value = row.values[productIndex];
    final isDifferent = !row.allValuesSame;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              row.attributeName,
              style: TextStyle(
                fontSize: 12,
                color: isDifferent ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value ?? '—',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isDifferent ? FontWeight.w600 : FontWeight.normal,
                color: value != null ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
