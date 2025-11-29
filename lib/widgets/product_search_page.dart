import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/bestbuy/bestbuy.dart';
import '../theme/app_colors.dart';
import 'product_detail_page.dart';

/// A beautiful product search page with filters, sorting, and infinite scroll.
class ProductSearchPage extends StatefulWidget {
  const ProductSearchPage({
    super.key,
    required this.client,
    this.initialQuery,
  });

  final BestBuyClient client;
  final String? initialQuery;

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
      builder: (context) => _FilterSheet(
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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(product: fullProduct),
          ),
        );
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
          child: _ProductCard(
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

/// Product card widget for search results.
class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    this.isLoading = false,
  });

  final BestBuyProduct product;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isAvailable =
        product.onlineAvailability == true || product.inStoreAvailability == true;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLoading ? AppColors.primaryBlue : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image with loading indicator
              Hero(
                tag: 'product_${product.sku}',
                child: Stack(
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: isLoading ? 0.6 : 1.0,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildImage(),
                        ),
                      ),
                    ),
                    if (isLoading)
                      Positioned.fill(
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badges row
                    if (_hasBadges())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            if (product.onSale == true)
                              _buildBadge('SALE', AppColors.sale),
                            if (product.freeShipping == true) ...[
                              if (product.onSale == true)
                                const SizedBox(width: 6),
                              _buildBadge('FREE SHIP', AppColors.success),
                            ],
                          ],
                        ),
                      ),
                    // Product name
                    Text(
                      product.name,
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
                    // Brand & SKU row
                    Row(
                      children: [
                        if (product.manufacturer != null) ...[
                          Text(
                            product.manufacturer!,
                            style: const TextStyle(
                              color: AppColors.primaryBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          'SKU: ${product.sku}',
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Price & Rating row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Price
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (product.onSale == true &&
                                  product.regularPrice != null)
                                Text(
                                  '\$${product.regularPrice!.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                                    fontSize: 11,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              Row(
                                children: [
                                  Text(
                                    '\$${product.effectivePrice?.toStringAsFixed(2) ?? 'N/A'}',
                                    style: TextStyle(
                                      color: product.onSale == true
                                          ? AppColors.sale
                                          : AppColors.accentYellow,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (product.onSale == true &&
                                      product.percentSavings != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '-${product.percentSavings!.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        color: AppColors.sale,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Rating & Availability
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Rating
                            if (product.customerReviewAverage != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 14,
                                    color: AppColors.brightYellow,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    product.customerReviewAverage!
                                        .toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (product.customerReviewCount != null) ...[
                                    Text(
                                      ' (${_formatCount(product.customerReviewCount!)})',
                                      style: TextStyle(
                                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            const SizedBox(height: 4),
                            // Availability indicator
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isAvailable
                                        ? AppColors.success
                                        : AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAvailable ? 'In Stock' : 'Out of Stock',
                                  style: TextStyle(
                                    color: isAvailable
                                        ? AppColors.success
                                        : AppColors.error,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final imageUrl = product.image ?? product.thumbnailImage;
    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                color: AppColors.primaryBlue,
              ),
            ),
          );
        },
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceVariant,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: AppColors.textSecondary,
        size: 32,
      ),
    );
  }

  bool _hasBadges() {
    return product.onSale == true || product.freeShipping == true;
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}

/// Filter parameters for the search.
class _FilterParams {
  final ProductSort sortBy;
  final bool onSaleOnly;
  final bool freeShippingOnly;
  final bool inStockOnly;
  final double? minPrice;
  final double? maxPrice;
  final double? minRating;
  final ProductCondition? condition;
  final CategoryEntry? selectedCategory;

  _FilterParams({
    required this.sortBy,
    required this.onSaleOnly,
    required this.freeShippingOnly,
    required this.inStockOnly,
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.condition,
    this.selectedCategory,
  });
}

/// Bottom sheet for filter options.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.sortBy,
    required this.onSaleOnly,
    required this.freeShippingOnly,
    required this.inStockOnly,
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.condition,
    this.selectedCategory,
    required this.onApply,
  });

  final ProductSort sortBy;
  final bool onSaleOnly;
  final bool freeShippingOnly;
  final bool inStockOnly;
  final double? minPrice;
  final double? maxPrice;
  final double? minRating;
  final ProductCondition? condition;
  final CategoryEntry? selectedCategory;
  final void Function(_FilterParams) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ProductSort _sortBy;
  late bool _onSaleOnly;
  late bool _freeShippingOnly;
  late bool _inStockOnly;
  late TextEditingController _minPriceController;
  late TextEditingController _maxPriceController;
  double? _minRating;
  ProductCondition? _condition;
  CategoryEntry? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.sortBy;
    _onSaleOnly = widget.onSaleOnly;
    _freeShippingOnly = widget.freeShippingOnly;
    _inStockOnly = widget.inStockOnly;
    _minPriceController = TextEditingController(
      text: widget.minPrice?.toStringAsFixed(0) ?? '',
    );
    _maxPriceController = TextEditingController(
      text: widget.maxPrice?.toStringAsFixed(0) ?? '',
    );
    _minRating = widget.minRating;
    _condition = widget.condition;
    _selectedCategory = widget.selectedCategory;
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _apply() {
    final minPrice = double.tryParse(_minPriceController.text);
    final maxPrice = double.tryParse(_maxPriceController.text);

    widget.onApply(_FilterParams(
      sortBy: _sortBy,
      onSaleOnly: _onSaleOnly,
      freeShippingOnly: _freeShippingOnly,
      inStockOnly: _inStockOnly,
      minPrice: minPrice,
      maxPrice: maxPrice,
      minRating: _minRating,
      condition: _condition,
      selectedCategory: _selectedCategory,
    ));
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _sortBy = ProductSort.bestSellingRank;
      _onSaleOnly = false;
      _freeShippingOnly = false;
      _inStockOnly = false;
      _minPriceController.clear();
      _maxPriceController.clear();
      _minRating = null;
      _condition = null;
      _selectedCategory = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Filters & Sorting',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _reset,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sort by
                  const Text(
                    'Sort by',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ProductSort.values.map((sort) {
                      final isSelected = _sortBy == sort;
                      return ChoiceChip(
                        label: Text(_getSortLabel(sort)),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) setState(() => _sortBy = sort);
                        },
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppColors.background
                              : AppColors.textPrimary,
                          fontSize: 12,
                        ),
                        backgroundColor: AppColors.surfaceVariant,
                        selectedColor: AppColors.primaryBlue,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primaryBlue
                              : AppColors.border,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Category filter
                  const Text(
                    'Category',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Filter by category for better results',
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildCategoryPicker(),
                  const SizedBox(height: 24),

                  // Condition filter
                  const Text(
                    'Condition',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildConditionChip('All', null),
                      const SizedBox(width: 8),
                      _buildConditionChip('New', ProductCondition.isNew),
                      const SizedBox(width: 8),
                      _buildConditionChip('Refurb', ProductCondition.refurbished),
                      const SizedBox(width: 8),
                      _buildConditionChip('Pre-Owned', ProductCondition.preOwned),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Quick filters
                  const Text(
                    'Quick Filters',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildFilterToggle(
                    'On Sale',
                    Icons.local_offer_outlined,
                    _onSaleOnly,
                    (v) => setState(() => _onSaleOnly = v),
                  ),
                  _buildFilterToggle(
                    'Free Shipping',
                    Icons.local_shipping_outlined,
                    _freeShippingOnly,
                    (v) => setState(() => _freeShippingOnly = v),
                  ),
                  _buildFilterToggle(
                    'In Stock Only',
                    Icons.inventory_2_outlined,
                    _inStockOnly,
                    (v) => setState(() => _inStockOnly = v),
                  ),
                  const SizedBox(height: 24),

                  // Price range
                  const Text(
                    'Price Range',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minPriceController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            hintText: 'Min',
                            prefixText: '\$ ',
                            prefixStyle:
                                const TextStyle(color: AppColors.textSecondary),
                            hintStyle:
                                const TextStyle(color: AppColors.textSecondary),
                            filled: true,
                            fillColor: AppColors.surfaceVariant,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.primaryBlue),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'to',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _maxPriceController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            hintText: 'Max',
                            prefixText: '\$ ',
                            prefixStyle:
                                const TextStyle(color: AppColors.textSecondary),
                            hintStyle:
                                const TextStyle(color: AppColors.textSecondary),
                            filled: true,
                            fillColor: AppColors.surfaceVariant,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppColors.primaryBlue),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Minimum rating
                  const Text(
                    'Minimum Rating',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (int i = 0; i <= 4; i++)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                if (_minRating == (i + 1).toDouble()) {
                                  _minRating = null;
                                } else {
                                  _minRating = (i + 1).toDouble();
                                }
                              });
                            },
                            child: Container(
                              margin: EdgeInsets.only(right: i < 4 ? 8 : 0),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _minRating == (i + 1).toDouble()
                                    ? AppColors.brightYellow.withValues(alpha: 0.15)
                                    : AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _minRating == (i + 1).toDouble()
                                      ? AppColors.brightYellow
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      color: _minRating == (i + 1).toDouble()
                                          ? AppColors.brightYellow
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.star,
                                    size: 14,
                                    color: _minRating == (i + 1).toDouble()
                                        ? AppColors.brightYellow
                                        : AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          // Apply button
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: const Border(
                top: BorderSide(color: AppColors.border),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToggle(
    String label,
    IconData icon,
    bool value,
    void Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: value
            ? AppColors.primaryBlue.withValues(alpha: 0.1)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value ? AppColors.primaryBlue : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: value ? AppColors.primaryBlue : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: value ? AppColors.primaryBlue : AppColors.textPrimary,
                fontWeight: value ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primaryBlue,
          ),
        ],
      ),
    );
  }

  String _getSortLabel(ProductSort sort) {
    return switch (sort) {
      ProductSort.bestSellingRank => 'Best Selling',
      ProductSort.customerReviewAverage => 'Top Rated',
      ProductSort.customerReviewCount => 'Most Reviews',
      ProductSort.salePriceAsc => 'Price ↑',
      ProductSort.salePriceDesc => 'Price ↓',
      ProductSort.nameAsc => 'A-Z',
      ProductSort.nameDesc => 'Z-A',
      ProductSort.releaseDateDesc => 'Newest',
      ProductSort.releaseDateAsc => 'Oldest',
      ProductSort.skuAsc => 'SKU',
    };
  }

  Widget _buildCategoryPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected category chip (if any)
        if (_selectedCategory != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Chip(
              label: Text(_selectedCategory!.displayName),
              labelStyle: const TextStyle(
                color: AppColors.background,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              backgroundColor: AppColors.primaryBlue,
              deleteIcon: const Icon(
                Icons.close,
                size: 16,
                color: AppColors.background,
              ),
              onDeleted: () => setState(() => _selectedCategory = null),
              side: BorderSide.none,
            ),
          ),
        // Category chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // "All Categories" option
            _buildCategoryChip(null, 'All'),
            // Top-level categories
            for (final category in CategoryFinder.topLevelCategories.take(8))
              _buildCategoryChip(category, category.name),
            // Popular subcategories
            _buildCategoryChip(
              const CategoryEntry(id: 'abcat0502000', name: 'Laptops', parentName: 'Computers'),
              'Laptops',
            ),
            _buildCategoryChip(
              const CategoryEntry(id: 'abcat0515013', name: 'USB Cables & Adapters', parentName: 'Cables & Connectors'),
              'USB Cables',
            ),
            _buildCategoryChip(
              const CategoryEntry(id: 'abcat0811002', name: 'Cell Phone Accessories', parentName: 'Cell Phones'),
              'Phone Accessories',
            ),
            _buildCategoryChip(
              const CategoryEntry(id: 'pcmcat321000050003', name: 'Smartwatches & Accessories', parentName: 'Cell Phones'),
              'Smartwatches',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryChip(CategoryEntry? category, String label) {
    final isSelected = _selectedCategory?.id == category?.id;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedCategory = selected ? category : null);
      },
      labelStyle: TextStyle(
        color: isSelected ? AppColors.background : AppColors.textPrimary,
        fontSize: 11,
      ),
      backgroundColor: AppColors.surfaceVariant,
      selectedColor: AppColors.primaryBlue,
      side: BorderSide(
        color: isSelected ? AppColors.primaryBlue : AppColors.border,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildConditionChip(String label, ProductCondition? condition) {
    final isSelected = _condition == condition;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _condition = condition),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentYellow.withValues(alpha: 0.15)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.accentYellow : AppColors.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppColors.accentYellow : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

