import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/bestbuy/bestbuy.dart';
import '../services/comparison/comparison.dart';
import '../theme/app_colors.dart';
import 'product_detail_page.dart';
import 'product_search/filter_sheet.dart';
import 'product_search/product_card.dart';

/// A beautiful product search page with filters, sorting, and infinite scroll.
class ProductSearchPage extends StatefulWidget {
  const ProductSearchPage({
    super.key,
    required this.client,
    this.initialQuery,
    this.comparisonMode = false,
  });

  final BestBuyClient client;
  final String? initialQuery;
  final bool comparisonMode;

  @override
  State<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends State<ProductSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();

  // Search state
  List<BestBuyProduct> _products = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 0;
  int _totalResults = 0;

  // Track which product is loading
  int? _loadingProductSku;

  // Filter state
  ProductSort _sortBy = ProductSort.bestSellingRank;
  bool _onSaleOnly = false;
  bool _freeShippingOnly = false;
  bool _inStockOnly = false;
  double? _minPrice;
  double? _maxPrice;
  double? _minRating;
  ProductCondition? _condition;
  CategoryEntry? _selectedCategory;

  // Debounce timer
  Timer? _debounceTimer;

  // Animation keys
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Pre-fill search if initial query provided
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      // Delay search to allow widget to build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchProducts(resetPage: true);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreProducts();
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (query.trim().isNotEmpty) {
        _searchProducts(resetPage: true);
      } else {
        setState(() {
          _products = [];
          _totalResults = 0;
          _error = null;
        });
      }
    });
  }

  Future<void> _searchProducts({bool resetPage = false}) async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    if (resetPage) {
      setState(() {
        _currentPage = 1;
        _isLoading = true;
        _error = null;
      });
    }

    try {
      var builder = widget.client
          .products()
          .search(query)
          .sortBy(_sortBy)
          .page(_currentPage)
          .pageSize(20)
          .withAttributes([
        ProductAttribute.sku,
        ProductAttribute.upc,
        ProductAttribute.name,
        ProductAttribute.manufacturer,
        ProductAttribute.salePrice,
        ProductAttribute.regularPrice,
        ProductAttribute.onSale,
        ProductAttribute.percentSavings,
        ProductAttribute.image,
        ProductAttribute.thumbnailImage,
        ProductAttribute.customerReviewAverage,
        ProductAttribute.customerReviewCount,
        ProductAttribute.onlineAvailability,
        ProductAttribute.inStoreAvailability,
        ProductAttribute.freeShipping,
      ]);

      // Exclude AppleCare and protection plans
      builder = builder.filter('manufacturer!="AppleCare"');

      // Apply category filter
      if (_selectedCategory != null) {
        builder = builder.inCategory(_selectedCategory!.id);
      }

      // Apply filters
      if (_onSaleOnly) builder = builder.onSale();
      if (_freeShippingOnly) builder = builder.freeShipping();
      if (_inStockOnly) builder = builder.availableOnline();
      if (_minPrice != null || _maxPrice != null) {
        builder = builder.priceRange(min: _minPrice, max: _maxPrice);
      }
      if (_minRating != null) {
        builder = builder.minRating(_minRating!);
      }
      if (_condition != null) {
        builder = builder.condition(_condition!);
      }

      final response = await builder.execute();

      if (!mounted) return;

      setState(() {
        if (resetPage) {
          _products = response.products;
        } else {
          _products.addAll(response.products);
        }
        _totalPages = response.totalPages;
        _totalResults = response.total;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } on BestBuyApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } on BestBuyNetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error: ${e.message}';
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unexpected error: $e';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || _isLoading || _currentPage >= _totalPages) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    await _searchProducts();
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterSheet(
        sortBy: _sortBy,
        onSaleOnly: _onSaleOnly,
        freeShippingOnly: _freeShippingOnly,
        inStockOnly: _inStockOnly,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        minRating: _minRating,
        condition: _condition,
        selectedCategory: _selectedCategory,
        onApply: (filters) {
          setState(() {
            _sortBy = filters.sortBy;
            _onSaleOnly = filters.onSaleOnly;
            _freeShippingOnly = filters.freeShippingOnly;
            _inStockOnly = filters.inStockOnly;
            _minPrice = filters.minPrice;
            _maxPrice = filters.maxPrice;
            _minRating = filters.minRating;
            _condition = filters.condition;
            _selectedCategory = filters.selectedCategory;
          });
          if (_searchController.text.trim().isNotEmpty) {
            _searchProducts(resetPage: true);
          }
        },
      ),
    );
  }

  Future<void> _navigateToProduct(BestBuyProduct product) async {
    if (_loadingProductSku != null) return; // Already loading something

    setState(() => _loadingProductSku = product.sku);

    try {
      final fullProduct = await widget.client.getProductBySku(product.sku);
      if (!mounted) return;

      setState(() => _loadingProductSku = null);

      if (fullProduct != null) {
        if (widget.comparisonMode) {
          _addToComparison(fullProduct);
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProductDetailPage(product: fullProduct),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product details not found')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingProductSku = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading product: $e')),
      );
    }
  }

  void _addToComparison(BestBuyProduct product) {
    final comparison = ComparisonService.instance;
    
    if (comparison.containsSku(product.sku)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} is already in comparison'),
          backgroundColor: AppColors.surfaceVariant,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    if (comparison.isFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Comparison list is full (max ${ComparisonService.maxComparisonItems})'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    comparison.addToComparison(product);
    HapticFeedback.lightImpact();
    
    final count = comparison.itemCount;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Added to comparison ($count item${count == 1 ? '' : 's'})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        action: count >= 2 ? SnackBarAction(
          label: 'Done',
          textColor: Colors.white,
          onPressed: () {
            Navigator.of(context).pop(); // Go back to scan page
            Navigator.of(context).pop(); // Go back to comparison page
          },
        ) : null,
      ),
    );
    
    // Trigger rebuild to update UI if needed
    setState(() {});
  }

  int get _activeFilterCount {
    int count = 0;
    if (_onSaleOnly) count++;
    if (_freeShippingOnly) count++;
    if (_inStockOnly) count++;
    if (_minPrice != null || _maxPrice != null) count++;
    if (_minRating != null) count++;
    if (_condition != null) count++;
    if (_selectedCategory != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchHeader(),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar row
          Row(
            children: [
              // Back button
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              // Search input
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _searchFocusNode.hasFocus
                          ? AppColors.primaryBlue
                          : AppColors.border,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => _searchProducts(resetPage: true),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.textSecondary,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _products = [];
                                  _totalResults = 0;
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Filter button
              Container(
                decoration: BoxDecoration(
                  color: _activeFilterCount > 0
                      ? AppColors.primaryBlue.withValues(alpha: 0.15)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _activeFilterCount > 0
                        ? AppColors.primaryBlue
                        : AppColors.border,
                  ),
                ),
                child: Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.tune,
                        color: _activeFilterCount > 0
                            ? AppColors.primaryBlue
                            : AppColors.textPrimary,
                      ),
                      onPressed: _showFilters,
                    ),
                    if (_activeFilterCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$_activeFilterCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // Results info row
          if (_totalResults > 0 && !_isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Text(
                    '$_totalResults results',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _showFilters,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sort,
                          size: 16,
                          color: AppColors.primaryBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getSortLabel(_sortBy),
                          style: const TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _products.isEmpty) {
      return _buildLoadingState();
    }

    if (_error != null && _products.isEmpty) {
      return _buildErrorState();
    }

    if (_products.isEmpty && _searchController.text.isEmpty) {
      return _buildEmptyState();
    }

    if (_products.isEmpty && _searchController.text.isNotEmpty) {
      return _buildNoResultsState();
    }

    return _buildProductGrid();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: AppColors.primaryBlue,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Searching products...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _searchProducts(resetPage: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
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
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search,
                size: 56,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Search Best Buy',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Find deals on electronics, appliances,\nand more from Best Buy',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 32),
            // Quick search suggestions
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickSearchChip('iPhone'),
                _buildQuickSearchChip('MacBook'),
                _buildQuickSearchChip('4K TV'),
                _buildQuickSearchChip('AirPods'),
                _buildQuickSearchChip('PS5'),
                _buildQuickSearchChip('Gaming Laptop'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSearchChip(String label) {
    return ActionChip(
      label: Text(label),
      labelStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13,
      ),
      backgroundColor: AppColors.surfaceVariant,
      side: const BorderSide(color: AppColors.border),
      onPressed: () {
        _searchController.text = label;
        _searchProducts(resetPage: true);
      },
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accentYellow.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off,
                size: 48,
                color: AppColors.accentYellow,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No products found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            if (_activeFilterCount > 0) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _onSaleOnly = false;
                    _freeShippingOnly = false;
                    _inStockOnly = false;
                    _minPrice = null;
                    _maxPrice = null;
                    _minRating = null;
                    _condition = null;
                  });
                  _searchProducts(resetPage: true);
                },
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _products.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _products.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryBlue,
                strokeWidth: 2,
              ),
            ),
          );
        }

        final product = _products[index];
        final isLoading = _loadingProductSku == product.sku;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ProductCard(
            product: product,
            isLoading: isLoading,
            onTap: () => _navigateToProduct(product),
          ),
        );
      },
    );
  }

  String _getSortLabel(ProductSort sort) {
    return switch (sort) {
      ProductSort.bestSellingRank => 'Best Selling',
      ProductSort.customerReviewAverage => 'Top Rated',
      ProductSort.customerReviewCount => 'Most Reviews',
      ProductSort.salePriceAsc => 'Price: Low to High',
      ProductSort.salePriceDesc => 'Price: High to Low',
      ProductSort.nameAsc => 'Name: A-Z',
      ProductSort.nameDesc => 'Name: Z-A',
      ProductSort.releaseDateDesc => 'Newest First',
      ProductSort.releaseDateAsc => 'Oldest First',
      ProductSort.skuAsc => 'SKU',
    };
  }
}

