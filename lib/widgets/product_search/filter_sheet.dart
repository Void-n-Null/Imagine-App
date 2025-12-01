import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/bestbuy/bestbuy.dart';
import '../../services/bestbuy/category_finder.dart';
import '../../theme/app_colors.dart';

/// Filter parameters for the search.
class FilterParams {
  final ProductSort sortBy;
  final bool onSaleOnly;
  final bool freeShippingOnly;
  final bool inStockOnly;
  final double? minPrice;
  final double? maxPrice;
  final double? minRating;
  final ProductCondition? condition;
  final CategoryEntry? selectedCategory;

  FilterParams({
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
class FilterSheet extends StatefulWidget {
  const FilterSheet({
    super.key,
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
  final void Function(FilterParams) onApply;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
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

    widget.onApply(FilterParams(
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
