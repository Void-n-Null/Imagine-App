import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bestbuy/bestbuy.dart';

/// Represents a product in the comparison list.
/// Stores minimal data needed for display and later fetching full details.
class ComparisonItem {
  final int sku;
  final String name;
  final String? thumbnailImage;
  final double? price;
  final String? manufacturer;
  final DateTime addedAt;

  ComparisonItem({
    required this.sku,
    required this.name,
    this.thumbnailImage,
    this.price,
    this.manufacturer,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  factory ComparisonItem.fromProduct(BestBuyProduct product) {
    return ComparisonItem(
      sku: product.sku,
      name: product.name,
      thumbnailImage: product.thumbnailImage ?? product.mediumImage ?? product.image,
      price: product.effectivePrice,
      manufacturer: product.manufacturer,
    );
  }

  factory ComparisonItem.fromJson(Map<String, dynamic> json) {
    return ComparisonItem(
      sku: json['sku'] as int,
      name: json['name'] as String,
      thumbnailImage: json['thumbnailImage'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      manufacturer: json['manufacturer'] as String?,
      addedAt: json['addedAt'] != null 
          ? DateTime.parse(json['addedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sku': sku,
      'name': name,
      'thumbnailImage': thumbnailImage,
      'price': price,
      'manufacturer': manufacturer,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'ComparisonItem(sku: $sku, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComparisonItem &&
          runtimeType == other.runtimeType &&
          sku == other.sku;

  @override
  int get hashCode => sku.hashCode;
}

/// Service for managing the product comparison list.
/// Provides persistence via SharedPreferences and reactive updates via ChangeNotifier.
class ComparisonService extends ChangeNotifier {
  static ComparisonService? _instance;
  static ComparisonService get instance => _instance!;

  static const String _comparisonKey = 'product_comparison';
  static const int maxComparisonItems = 5; // Reasonable limit for comparison

  final SharedPreferences _prefs;
  List<ComparisonItem> _items = [];

  /// Full product details for items in comparison (loaded on demand).
  final Map<int, BestBuyProduct> _productDetails = {};

  ComparisonService._(this._prefs) {
    _loadComparison();
  }

  /// Initialize the comparison service. Must be called before accessing instance.
  static Future<void> initialize() async {
    if (_instance != null) return;
    final prefs = await SharedPreferences.getInstance();
    _instance = ComparisonService._(prefs);
  }

  /// Get all items in the comparison list.
  List<ComparisonItem> get items => List.unmodifiable(_items);

  /// Get the number of items in the comparison.
  int get itemCount => _items.length;

  /// Check if the comparison list is empty.
  bool get isEmpty => _items.isEmpty;

  /// Check if the comparison list is not empty.
  bool get isNotEmpty => _items.isNotEmpty;

  /// Check if the comparison list has enough items to compare.
  bool get canCompare => _items.length >= 2;

  /// Check if we've reached the maximum items.
  bool get isFull => _items.length >= maxComparisonItems;

  /// Check if a product is in the comparison list.
  bool containsSku(int sku) => _items.any((item) => item.sku == sku);

  /// Get a comparison item by SKU.
  ComparisonItem? getItemBySku(int sku) {
    try {
      return _items.firstWhere((item) => item.sku == sku);
    } catch (_) {
      return null;
    }
  }

  /// Get cached product details by SKU (may be null if not loaded).
  BestBuyProduct? getProductDetails(int sku) => _productDetails[sku];

  /// Get all cached product details.
  List<BestBuyProduct> get cachedProducts => _productDetails.values.toList();

  /// Add a product to the comparison list.
  /// Returns true if added, false if already in list or list is full.
  Future<bool> addToComparison(BestBuyProduct product) async {
    if (containsSku(product.sku)) {
      return false;
    }

    if (isFull) {
      return false;
    }

    _items.add(ComparisonItem.fromProduct(product));
    _productDetails[product.sku] = product;
    
    // Notify listeners immediately for responsive UI
    notifyListeners();
    
    // Save in background (don't await)
    _saveComparison();
    return true;
  }

  /// Add an item to the comparison list directly.
  Future<bool> addItem(ComparisonItem item) async {
    if (containsSku(item.sku)) {
      return false;
    }

    if (isFull) {
      return false;
    }

    _items.add(item);
    await _saveComparison();
    notifyListeners();
    return true;
  }

  /// Remove a product from the comparison list by SKU.
  /// Returns true if removed, false if not found.
  Future<bool> removeFromComparison(int sku) async {
    final initialLength = _items.length;
    _items.removeWhere((item) => item.sku == sku);
    _productDetails.remove(sku);
    
    if (_items.length != initialLength) {
      // Notify immediately for responsive UI
      notifyListeners();
      // Save in background
      _saveComparison();
      return true;
    }
    return false;
  }

  /// Clear all items from the comparison list.
  Future<void> clearComparison() async {
    _items.clear();
    _productDetails.clear();
    // Notify immediately for responsive UI
    notifyListeners();
    // Save in background
    _saveComparison();
  }

  /// Reorder items in the comparison list.
  Future<void> reorderItems(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _items.length) return;
    if (newIndex < 0 || newIndex >= _items.length) return;
    if (oldIndex == newIndex) return;

    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    // Notify immediately for responsive UI
    notifyListeners();
    // Save in background
    _saveComparison();
  }

  /// Set product details for comparison items (used after loading full products).
  void setProductDetails(List<BestBuyProduct> products) {
    for (final product in products) {
      _productDetails[product.sku] = product;
    }
    notifyListeners();
  }

  /// Set product details without notifying listeners (to avoid loops).
  void setProductDetailsQuietly(List<BestBuyProduct> products) {
    for (final product in products) {
      _productDetails[product.sku] = product;
    }
  }

  /// Toggle a product in the comparison list.
  /// If present, removes it. If not present, adds it.
  /// Returns true if the product is now in the list, false if removed.
  Future<bool> toggleComparison(BestBuyProduct product) async {
    if (containsSku(product.sku)) {
      await removeFromComparison(product.sku);
      return false;
    } else {
      await addToComparison(product);
      return true;
    }
  }

  /// Get SKUs of all items in comparison.
  List<int> get skus => _items.map((item) => item.sku).toList();

  void _loadComparison() {
    final comparisonJson = _prefs.getString(_comparisonKey);
    if (comparisonJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(comparisonJson);
        _items = decoded
            .map((e) => ComparisonItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading comparison: $e');
        _items = [];
      }
    }
  }

  Future<void> _saveComparison() async {
    final comparisonJson = jsonEncode(_items.map((e) => e.toJson()).toList());
    await _prefs.setString(_comparisonKey, comparisonJson);
  }
}
