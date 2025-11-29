import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/api_keys.dart';
import '../services/bestbuy/bestbuy.dart';
import '../theme/app_colors.dart';

/// A debug page for testing and analyzing Best Buy API search configurations.
///
/// Provides comprehensive logging, configurable filters, and blocklist support
/// to help identify and fix search query issues.
class SearchDebugPage extends StatefulWidget {
  const SearchDebugPage({super.key});

  @override
  State<SearchDebugPage> createState() => _SearchDebugPageState();
}

class _SearchDebugPageState extends State<SearchDebugPage> {
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final ScrollController _logScrollController = ScrollController();
  final ScrollController _resultsScrollController = ScrollController();

  late final BestBuyClient _client;
  final SearchDebugLogger _logger = SearchDebugLogger();

  // Search state
  List<BestBuyProduct> _products = [];
  bool _isLoading = false;
  int _totalResults = 0;
  int _totalPages = 0;

  // Filter configuration
  ProductSort _sortBy = ProductSort.bestSellingRank;
  int _pageSize = 10;
  bool _onSaleOnly = false;
  bool _freeShippingOnly = false;
  bool _inStockOnly = false;
  bool _excludeMarketplace = false;

  // Blocklist configuration
  bool _blockProtectionPlans = true;
  bool _blockGiftCards = true;
  bool _blockDigitalContent = false;
  bool _blockAccessories = false;

  // Minimum rating filter
  double? _minRating;

  // UI state
  bool _showFilters = true;
  bool _showBlocklist = true;
  bool _showLogs = true;

  @override
  void initState() {
    super.initState();
    _client = BestBuyClient(apiKey: ApiKeys.bestBuy);
    _logger.addListener(_onLogUpdate);
    _logger.logInfo('Search Debug Page initialized');
  }

  @override
  void dispose() {
    _queryController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _logScrollController.dispose();
    _resultsScrollController.dispose();
    _logger.removeListener(_onLogUpdate);
    _client.close();
    super.dispose();
  }

  void _onLogUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _executeSearch() async {
    final query = _queryController.text.trim();

    setState(() {
      _isLoading = true;
      _products = [];
    });

    final stopwatch = Stopwatch()..start();

    try {
      var builder = _client.products();

      // Apply search query
      if (query.isNotEmpty) {
        builder = builder.search(query);
      }

      // Apply sort and pagination
      builder = builder.sortBy(_sortBy).pageSize(_pageSize);

      // Apply filters
      if (_onSaleOnly) builder = builder.onSale();
      if (_freeShippingOnly) builder = builder.freeShipping();
      if (_inStockOnly) builder = builder.availableOnline();
      if (_excludeMarketplace) builder = builder.excludeMarketplace();

      // Apply blocklist
      if (_blockProtectionPlans) builder = builder.excludeProtectionPlans();
      if (_blockGiftCards) builder = builder.excludeGiftCards();
      if (_blockDigitalContent) builder = builder.excludeDigitalContent();
      if (_blockAccessories) builder = builder.excludeAccessories();

      // Apply price range
      final minPrice = double.tryParse(_minPriceController.text);
      final maxPrice = double.tryParse(_maxPriceController.text);
      if (minPrice != null || maxPrice != null) {
        builder = builder.priceRange(min: minPrice, max: maxPrice);
      }

      // Apply rating filter
      if (_minRating != null) {
        builder = builder.minRating(_minRating!);
      }

      // Use debug attributes to see category info
      builder = builder.withAttributes([
        ProductAttribute.sku,
        ProductAttribute.upc,
        ProductAttribute.name,
        ProductAttribute.type,
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
        ProductAttribute.categoryPath,
        ProductAttribute.digital,
        ProductAttribute.marketplace,
      ]);

      // Log the request
      final debugInfo = builder.buildDebugInfo();
      _logger.logRequest(
        query: query,
        filters: debugInfo['filters'] as List<String>,
        params: debugInfo['params'] as Map<String, String>,
      );

      // Execute
      final response = await builder.execute();
      stopwatch.stop();

      if (!mounted) return;

      // Extract sample data for logging
      final sampleCategories = response.products
          .take(5)
          .map((p) => p.categoryPath.isNotEmpty ? p.categoryPath.last.name : null)
          .whereType<String>()
          .toSet()
          .toList();

      final sampleManufacturers = response.products
          .take(10)
          .map((p) => p.manufacturer)
          .whereType<String>()
          .toSet()
          .toList();

      _logger.logResponse(
        total: response.total,
        returned: response.products.length,
        pages: response.totalPages,
        elapsed: stopwatch.elapsed,
        sampleCategories: sampleCategories,
        sampleManufacturers: sampleManufacturers,
      );

      setState(() {
        _products = response.products;
        _totalResults = response.total;
        _totalPages = response.totalPages;
        _isLoading = false;
      });
    } catch (e, stack) {
      stopwatch.stop();
      _logger.logError(
        error: e.toString(),
        details: stack.toString().split('\n').take(5).join('\n'),
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    _queryController.clear();
    setState(() {
      _products = [];
      _totalResults = 0;
      _totalPages = 0;
    });
    _logger.logInfo('Search cleared');
  }

  void _copyDebugInfo() {
    final buffer = StringBuffer();
    buffer.writeln('=== Search Debug Export ===');
    buffer.writeln('Query: ${_queryController.text}');
    buffer.writeln('Sort: ${_sortBy.name}');
    buffer.writeln('Page Size: $_pageSize');
    buffer.writeln();
    buffer.writeln('Filters:');
    buffer.writeln('  On Sale: $_onSaleOnly');
    buffer.writeln('  Free Shipping: $_freeShippingOnly');
    buffer.writeln('  In Stock: $_inStockOnly');
    buffer.writeln('  Exclude Marketplace: $_excludeMarketplace');
    buffer.writeln();
    buffer.writeln('Blocklist:');
    buffer.writeln('  Protection Plans: $_blockProtectionPlans');
    buffer.writeln('  Gift Cards: $_blockGiftCards');
    buffer.writeln('  Digital Content: $_blockDigitalContent');
    buffer.writeln('  Accessories: $_blockAccessories');
    buffer.writeln();
    buffer.writeln('Price Range: ${_minPriceController.text.isEmpty ? "any" : "\$${_minPriceController.text}"} - ${_maxPriceController.text.isEmpty ? "any" : "\$${_maxPriceController.text}"}');
    buffer.writeln('Min Rating: ${_minRating ?? "any"}');
    buffer.writeln();
    buffer.writeln('Results: $_totalResults total, ${_products.length} shown');
    buffer.writeln();
    buffer.writeln(_logger.exportLogs());

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Debug info copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 16),
                    _buildFiltersSection(),
                    const SizedBox(height: 16),
                    _buildBlocklistSection(),
                    const SizedBox(height: 16),
                    _buildPriceRatingSection(),
                    const SizedBox(height: 16),
                    _buildLogSection(),
                    const SizedBox(height: 16),
                    _buildResultsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.bug_report, color: AppColors.accentYellow, size: 24),
          const SizedBox(width: 8),
          const Text(
            'Search Debug',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy, color: AppColors.textSecondary),
            tooltip: 'Copy Debug Info',
            onPressed: _copyDebugInfo,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
            tooltip: 'Clear Logs',
            onPressed: () {
              _logger.clear();
              _logger.logInfo('Logs cleared');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
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
              Expanded(
                child: TextField(
                  controller: _queryController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search query (e.g., "iPhone 15 Pro")',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    suffixIcon: _queryController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                            onPressed: _clearSearch,
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onSubmitted: (_) => _executeSearch(),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _executeSearch,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.background,
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: const Text('Run'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return _buildCollapsibleSection(
      title: 'FILTERS',
      icon: Icons.tune,
      isExpanded: _showFilters,
      onToggle: () => setState(() => _showFilters = !_showFilters),
      child: Column(
        children: [
          // Sort dropdown
          Row(
            children: [
              const Text('Sort:', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButton<ProductSort>(
                    value: _sortBy,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    underline: const SizedBox(),
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: ProductSort.values.map((sort) {
                      return DropdownMenuItem(
                        value: sort,
                        child: Text(_getSortLabel(sort)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _sortBy = value);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Page size dropdown
          Row(
            children: [
              const Text('Page Size:', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButton<int>(
                    value: _pageSize,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    underline: const SizedBox(),
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: [5, 10, 20, 50, 100].map((size) {
                      return DropdownMenuItem(
                        value: size,
                        child: Text('$size results'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _pageSize = value);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Toggle filters
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip('On Sale', _onSaleOnly, (v) => setState(() => _onSaleOnly = v)),
              _buildFilterChip('Free Shipping', _freeShippingOnly, (v) => setState(() => _freeShippingOnly = v)),
              _buildFilterChip('In Stock', _inStockOnly, (v) => setState(() => _inStockOnly = v)),
              _buildFilterChip('Exclude Marketplace', _excludeMarketplace, (v) => setState(() => _excludeMarketplace = v)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlocklistSection() {
    return _buildCollapsibleSection(
      title: 'BLOCKLIST',
      icon: Icons.block,
      isExpanded: _showBlocklist,
      onToggle: () => setState(() => _showBlocklist = !_showBlocklist),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exclude unwanted product types from results',
            style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildBlockChip('Protection Plans', _blockProtectionPlans, (v) => setState(() => _blockProtectionPlans = v)),
              _buildBlockChip('Gift Cards', _blockGiftCards, (v) => setState(() => _blockGiftCards = v)),
              _buildBlockChip('Digital Content', _blockDigitalContent, (v) => setState(() => _blockDigitalContent = v)),
              _buildBlockChip('Accessories', _blockAccessories, (v) => setState(() => _blockAccessories = v)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRatingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PRICE & RATING',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minPriceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Min',
                    prefixText: '\$ ',
                    prefixStyle: const TextStyle(color: AppColors.textSecondary),
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('to', style: TextStyle(color: AppColors.textSecondary)),
              ),
              Expanded(
                child: TextField(
                  controller: _maxPriceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Max',
                    prefixText: '\$ ',
                    prefixStyle: const TextStyle(color: AppColors.textSecondary),
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Minimum Rating',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildRatingButton(null, 'Any'),
              for (int i = 1; i <= 5; i++) _buildRatingButton(i.toDouble(), '$i★'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingButton(double? rating, String label) {
    final isSelected = _minRating == rating;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _minRating = rating),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brightYellow.withValues(alpha: 0.2) : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppColors.brightYellow : AppColors.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppColors.brightYellow : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogSection() {
    final logs = _logger.getRecentLogs(20);

    return _buildCollapsibleSection(
      title: 'DEBUG LOG',
      icon: Icons.terminal,
      isExpanded: _showLogs,
      onToggle: () => setState(() => _showLogs = !_showLogs),
      trailing: Text(
        '${logs.length} entries',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(8),
        ),
        child: logs.isEmpty
            ? const Center(
                child: Text(
                  'No logs yet. Run a search to see debug output.',
                  style: TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                ),
              )
            : ListView.builder(
                controller: _logScrollController,
                padding: const EdgeInsets.all(12),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final entry = logs[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildLogEntry(entry),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildLogEntry(SearchLogEntry entry) {
    final color = switch (entry.type) {
      SearchLogType.request => AppColors.primaryBlue,
      SearchLogType.response => AppColors.success,
      SearchLogType.error => AppColors.error,
      SearchLogType.info => AppColors.textSecondary,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '[${entry.formattedTime}]',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.6),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 8),
            Text(
              entry.typeIcon,
              style: TextStyle(color: color, fontSize: 12),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.message,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        if (entry.data != null && entry.data!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entry.data!.entries.map((e) {
                return Text(
                  '${e.key}: ${e.value}',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildResultsSection() {
    return Container(
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
              const Icon(Icons.inventory_2, color: AppColors.accentYellow, size: 18),
              const SizedBox(width: 8),
              Text(
                'RESULTS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (_totalResults > 0)
                Text(
                  '${_products.length} of $_totalResults • $_totalPages pages',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_products.isEmpty && !_isLoading)
            Container(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  _totalResults == 0 && _queryController.text.isNotEmpty
                      ? 'No products found'
                      : 'Run a search to see results',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                return _buildProductCard(_products[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard(BestBuyProduct product) {
    final categoryPath = product.categoryPath.map((c) => c.name).join(' > ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: product.thumbnailImage != null
                  ? Image.network(
                      product.thumbnailImage!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.grey),
                    )
                  : const Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Metadata row
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildMetaBadge('SKU: ${product.sku}', AppColors.textSecondary),
                    if (product.manufacturer != null)
                      _buildMetaBadge(product.manufacturer!, AppColors.primaryBlue),
                    if (product.type != null)
                      _buildMetaBadge(product.type!, AppColors.accentYellow),
                    if (product.digital == true)
                      _buildMetaBadge('DIGITAL', AppColors.error),
                    if (product.marketplace == true)
                      _buildMetaBadge('MARKETPLACE', AppColors.error),
                  ],
                ),
                const SizedBox(height: 6),
                // Category path (important for debugging)
                if (categoryPath.isNotEmpty)
                  Text(
                    categoryPath,
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 6),
                // Price row
                Row(
                  children: [
                    Text(
                      '\$${product.effectivePrice?.toStringAsFixed(2) ?? 'N/A'}',
                      style: TextStyle(
                        color: product.onSale == true ? AppColors.sale : AppColors.accentYellow,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (product.onSale == true && product.regularPrice != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '\$${product.regularPrice!.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (product.customerReviewAverage != null)
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: AppColors.brightYellow),
                          const SizedBox(width: 2),
                          Text(
                            product.customerReviewAverage!.toStringAsFixed(1),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
    );
  }

  Widget _buildMetaBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.accentYellow, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  if (trailing != null) ...[
                    trailing,
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool value, void Function(bool) onChanged) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
      labelStyle: TextStyle(
        color: value ? AppColors.background : AppColors.textPrimary,
        fontSize: 12,
      ),
      backgroundColor: AppColors.surfaceVariant,
      selectedColor: AppColors.primaryBlue,
      checkmarkColor: AppColors.background,
      side: BorderSide(color: value ? AppColors.primaryBlue : AppColors.border),
    );
  }

  Widget _buildBlockChip(String label, bool value, void Function(bool) onChanged) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
      labelStyle: TextStyle(
        color: value ? AppColors.background : AppColors.textPrimary,
        fontSize: 12,
      ),
      backgroundColor: AppColors.surfaceVariant,
      selectedColor: AppColors.error,
      checkmarkColor: AppColors.background,
      side: BorderSide(color: value ? AppColors.error : AppColors.border),
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

