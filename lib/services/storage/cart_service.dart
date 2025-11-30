import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bestbuy/bestbuy.dart';

/// Represents an item in the shopping cart.
class CartItem {
  final int sku;
  final String name;
  final String? thumbnailImage;
  final String? upc;
  final double? price;
  final String? manufacturer;
  final DateTime addedAt;

  CartItem({
    required this.sku,
    required this.name,
    this.thumbnailImage,
    this.upc,
    this.price,
    this.manufacturer,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  factory CartItem.fromProduct(BestBuyProduct product) {
    return CartItem(
      sku: product.sku,
      name: product.name,
      thumbnailImage: product.thumbnailImage ?? product.mediumImage ?? product.image,
      upc: product.upc,
      price: product.effectivePrice,
      manufacturer: product.manufacturer,
    );
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      sku: json['sku'] as int,
      name: json['name'] as String,
      thumbnailImage: json['thumbnailImage'] as String?,
      upc: json['upc'] as String?,
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
      'upc': upc,
      'price': price,
      'manufacturer': manufacturer,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'CartItem(sku: $sku, name: $name)';
}

/// Service for managing the shopping cart.
/// Provides persistence via SharedPreferences and reactive updates via ChangeNotifier.
class CartService extends ChangeNotifier {
  static CartService? _instance;
  static CartService get instance => _instance!;

  static const String _cartKey = 'shopping_cart';

  final SharedPreferences _prefs;
  List<CartItem> _items = [];

  CartService._(this._prefs) {
    _loadCart();
  }

  /// Initialize the cart service. Must be called before accessing instance.
  static Future<void> initialize() async {
    if (_instance != null) return;
    final prefs = await SharedPreferences.getInstance();
    _instance = CartService._(prefs);
  }

  /// Get all items in the cart.
  List<CartItem> get items => List.unmodifiable(_items);

  /// Get the number of items in the cart.
  int get itemCount => _items.length;

  /// Check if the cart is empty.
  bool get isEmpty => _items.isEmpty;

  /// Check if the cart is not empty.
  bool get isNotEmpty => _items.isNotEmpty;

  /// Check if a product is in the cart.
  bool containsSku(int sku) => _items.any((item) => item.sku == sku);

  /// Get a cart item by SKU.
  CartItem? getItemBySku(int sku) {
    try {
      return _items.firstWhere((item) => item.sku == sku);
    } catch (_) {
      return null;
    }
  }

  /// Add a product to the cart.
  /// Returns true if added, false if already in cart.
  Future<bool> addToCart(BestBuyProduct product) async {
    if (containsSku(product.sku)) {
      return false;
    }

    _items.add(CartItem.fromProduct(product));
    await _saveCart();
    notifyListeners();
    return true;
  }

  /// Add an item to the cart directly.
  Future<bool> addItem(CartItem item) async {
    if (containsSku(item.sku)) {
      return false;
    }

    _items.add(item);
    await _saveCart();
    notifyListeners();
    return true;
  }

  /// Remove a product from the cart by SKU.
  /// Returns true if removed, false if not found.
  Future<bool> removeFromCart(int sku) async {
    final initialLength = _items.length;
    _items.removeWhere((item) => item.sku == sku);
    
    if (_items.length != initialLength) {
      await _saveCart();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Clear all items from the cart.
  Future<void> clearCart() async {
    _items.clear();
    await _saveCart();
    notifyListeners();
  }

  /// Search cart items by name (fuzzy matching).
  /// Returns items sorted by relevance (best match first).
  List<CartItem> searchItems(String query) {
    if (query.isEmpty) return items;
    
    final lowerQuery = query.toLowerCase();
    final words = lowerQuery.split(RegExp(r'\s+'));
    
    // Score each item based on how well it matches
    final scored = _items.map((item) {
      final lowerName = item.name.toLowerCase();
      final lowerManufacturer = item.manufacturer?.toLowerCase() ?? '';
      
      int score = 0;
      
      // Exact match in name
      if (lowerName.contains(lowerQuery)) {
        score += 100;
      }
      
      // Exact match in manufacturer
      if (lowerManufacturer.contains(lowerQuery)) {
        score += 50;
      }
      
      // Word matches
      for (final word in words) {
        if (word.length < 2) continue;
        if (lowerName.contains(word)) score += 10;
        if (lowerManufacturer.contains(word)) score += 5;
      }
      
      // Fuzzy matching - check if letters appear in order
      if (score == 0) {
        int queryIndex = 0;
        for (int i = 0; i < lowerName.length && queryIndex < lowerQuery.length; i++) {
          if (lowerName[i] == lowerQuery[queryIndex]) {
            queryIndex++;
            score++;
          }
        }
      }
      
      return (item: item, score: score);
    }).where((s) => s.score > 0).toList();
    
    // Sort by score descending
    scored.sort((a, b) => b.score.compareTo(a.score));
    
    return scored.map((s) => s.item).toList();
  }

  /// Get the best matching item for a search query.
  CartItem? findBestMatch(String query) {
    final results = searchItems(query);
    return results.isNotEmpty ? results.first : null;
  }

  void _loadCart() {
    final cartJson = _prefs.getString(_cartKey);
    if (cartJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(cartJson);
        _items = decoded
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading cart: $e');
        _items = [];
      }
    }
  }

  Future<void> _saveCart() async {
    final cartJson = jsonEncode(_items.map((e) => e.toJson()).toList());
    await _prefs.setString(_cartKey, cartJson);
  }
}
