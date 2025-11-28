import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'bestbuy_exception.dart';
import 'models/category.dart';
import 'models/product.dart';
import 'models/search_response.dart';
import 'models/store.dart';
import 'search_builder.dart';

/// Client for interacting with the Best Buy API.
///
/// Provides access to the Products, Categories, and Stores APIs.
///
/// Example usage:
/// ```dart
/// final client = BestBuyClient(apiKey: 'YOUR_API_KEY');
///
/// // Search for products
/// final results = await client.products()
///     .search("iPhone")
///     .onSale()
///     .execute();
///
/// // Get a product by UPC (from barcode scanner)
/// final product = await client.getProductByUpc("194253715375");
/// ```
class BestBuyClient {
  /// Base URL for the Best Buy API.
  static const String _baseUrl = 'https://api.bestbuy.com/v1';

  /// Your Best Buy API key.
  final String apiKey;

  /// HTTP client for making requests.
  final http.Client _httpClient;

  /// Request timeout duration.
  final Duration timeout;

  /// Whether to close the HTTP client when this client is closed.
  final bool _ownsHttpClient;

  /// Creates a new Best Buy API client.
  ///
  /// [apiKey] is required and can be obtained from the Best Buy Developer Portal.
  /// [httpClient] is optional; if not provided, a new client will be created.
  /// [timeout] defaults to 30 seconds.
  BestBuyClient({
    required this.apiKey,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
  })  : _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null;

  /// Closes the HTTP client and releases resources.
  ///
  /// Should be called when the client is no longer needed.
  void close() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Products API
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a new product search builder.
  ///
  /// Use the fluent API to construct your query:
  /// ```dart
  /// final results = await client.products()
  ///     .search("laptop")
  ///     .priceRange(min: 500, max: 1500)
  ///     .sortBy(ProductSort.bestSellingRank)
  ///     .execute();
  /// ```
  ProductSearchBuilder products() {
    return ProductSearchBuilder(_executeProductSearch);
  }

  /// Gets a product by its SKU.
  ///
  /// Returns null if the product is not found.
  Future<BestBuyProduct?> getProductBySku(
    int sku, {
    List<ProductAttribute>? attributes,
  }) async {
    final response = await products()
        .bySku(sku)
        .withAttributes(attributes ?? ProductAttributePresets.full)
        .pageSize(1)
        .execute();

    return response.products.firstOrNull;
  }

  /// Gets a product by its UPC (barcode).
  ///
  /// Returns null if the product is not found.
  Future<BestBuyProduct?> getProductByUpc(
    String upc, {
    List<ProductAttribute>? attributes,
  }) async {
    final response = await products()
        .byUpc(upc)
        .withAttributes(attributes ?? ProductAttributePresets.full)
        .pageSize(1)
        .execute();

    return response.products.firstOrNull;
  }

  /// Gets multiple products by their SKUs.
  Future<List<BestBuyProduct>> getProductsBySkus(
    List<int> skus, {
    List<ProductAttribute>? attributes,
  }) async {
    if (skus.isEmpty) return [];

    final response = await products()
        .bySkus(skus)
        .withAttributes(attributes ?? ProductAttributePresets.card)
        .pageSize(skus.length.clamp(1, 100))
        .execute();

    return response.products;
  }

  /// Gets multiple products by their UPCs.
  Future<List<BestBuyProduct>> getProductsByUpcs(
    List<String> upcs, {
    List<ProductAttribute>? attributes,
  }) async {
    if (upcs.isEmpty) return [];

    final response = await products()
        .byUpcs(upcs)
        .withAttributes(attributes ?? ProductAttributePresets.card)
        .pageSize(upcs.length.clamp(1, 100))
        .execute();

    return response.products;
  }

  /// Searches for products by keyword.
  ///
  /// This is a convenience method for simple searches.
  /// For more control, use [products()] to build a custom query.
  Future<ProductSearchResponse> searchProducts(
    String query, {
    int page = 1,
    int pageSize = 10,
    ProductSort? sort,
    List<ProductAttribute>? attributes,
  }) async {
    var builder = products().search(query).page(page).pageSize(pageSize);

    if (sort != null) {
      builder = builder.sortBy(sort);
    }

    if (attributes != null) {
      builder = builder.withAttributes(attributes);
    }

    return builder.execute();
  }

  /// Executes a product search with the given parameters and filters.
  Future<ProductSearchResponse> _executeProductSearch(
    Map<String, String> params,
    List<String> filters,
  ) async {
    // Build the products URL path
    final filterString =
        filters.isNotEmpty ? '(${filters.join('&')})' : '';
    final path = '/products$filterString';

    final json = await _request(path, params);
    return ProductSearchResponse.fromJson(json);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Categories API
  // ─────────────────────────────────────────────────────────────────────────

  /// Gets all top-level categories.
  Future<CategorySearchResponse> getCategories({
    int page = 1,
    int pageSize = 100,
  }) async {
    final params = {
      'format': 'json',
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };

    final json = await _request('/categories', params);
    return CategorySearchResponse.fromJson(json);
  }

  /// Gets a category by its ID.
  Future<BestBuyCategory?> getCategoryById(String categoryId) async {
    final params = {'format': 'json'};

    try {
      final json = await _request('/categories(id=$categoryId)', params);
      final response = CategorySearchResponse.fromJson(json);
      return response.categories.firstOrNull;
    } on BestBuyApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Gets subcategories of a parent category.
  Future<List<BestBuyCategory>> getSubcategories(String parentCategoryId) async {
    final parent = await getCategoryById(parentCategoryId);
    if (parent == null || parent.subCategories.isEmpty) {
      return [];
    }

    // Fetch each subcategory
    final subcategories = <BestBuyCategory>[];
    for (final subId in parent.subCategories) {
      final sub = await getCategoryById(subId);
      if (sub != null) {
        subcategories.add(sub);
      }
    }
    return subcategories;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stores API - Product Availability
  // ─────────────────────────────────────────────────────────────────────────

  /// Gets store availability for a product by SKU and postal code.
  ///
  /// Returns stores that have the product in stock, sorted by distance
  /// from the provided postal code.
  ///
  /// Example:
  /// ```dart
  /// final availability = await client.getStoreAvailability(
  ///   sku: 6525432,
  ///   postalCode: '55423',
  /// );
  /// if (availability.hasAvailableStores) {
  ///   final nearest = availability.nearestStore!;
  ///   print('Available at ${nearest.name}, ${nearest.distanceFormatted} away');
  /// }
  /// ```
  Future<StoreAvailabilityResponse> getStoreAvailability({
    required int sku,
    required String postalCode,
  }) async {
    final params = {
      'format': 'json',
      'postalCode': postalCode,
    };

    try {
      final json = await _request('/products/$sku/stores.json', params);
      return StoreAvailabilityResponse.fromJson(json);
    } on BestBuyApiException catch (e) {
      // If product not found or no stores available, return empty response
      if (e.isNotFound) {
        return const StoreAvailabilityResponse(ispuEligible: false, stores: []);
      }
      rethrow;
    }
  }

  /// Gets store availability for a product by SKU using latitude/longitude.
  ///
  /// Returns stores that have the product in stock, sorted by distance
  /// from the provided coordinates.
  Future<StoreAvailabilityResponse> getStoreAvailabilityByLocation({
    required int sku,
    required double latitude,
    required double longitude,
  }) async {
    final params = {
      'format': 'json',
      'lat': latitude.toString(),
      'lng': longitude.toString(),
    };

    try {
      final json = await _request('/products/$sku/stores.json', params);
      return StoreAvailabilityResponse.fromJson(json);
    } on BestBuyApiException catch (e) {
      if (e.isNotFound) {
        return const StoreAvailabilityResponse(ispuEligible: false, stores: []);
      }
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HTTP request handling
  // ─────────────────────────────────────────────────────────────────────────

  /// Makes an HTTP GET request to the Best Buy API.
  Future<Map<String, dynamic>> _request(
    String path,
    Map<String, String> params,
  ) async {
    // Add API key to params
    final queryParams = Map<String, String>.from(params);
    queryParams['apiKey'] = apiKey;

    // Build the URL
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: queryParams);

    try {
      final response = await _httpClient.get(uri).timeout(timeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw BestBuyNetworkException(
        message: 'Request timed out after ${timeout.inSeconds} seconds',
        isTimeout: true,
      );
    } on SocketException catch (e) {
      throw BestBuyNetworkException(
        message: 'Network connection failed: ${e.message}',
        cause: e,
      );
    } on http.ClientException catch (e) {
      throw BestBuyNetworkException(
        message: 'HTTP request failed: ${e.message}',
        cause: e,
      );
    }
  }

  /// Handles the HTTP response and returns the parsed JSON.
  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = response.body;

    // Check for error status codes
    if (response.statusCode >= 400) {
      String message;
      String? errorCode;

      try {
        final json = jsonDecode(body) as Map<String, dynamic>;
        final error = json['error'] as Map<String, dynamic>?;
        message = error?['message'] as String? ??
            json['message'] as String? ??
            'API error occurred';
        errorCode = error?['code'] as String?;
      } catch (_) {
        message = _getDefaultErrorMessage(response.statusCode);
      }

      throw BestBuyApiException(
        statusCode: response.statusCode,
        message: message,
        errorCode: errorCode,
      );
    }

    // Parse successful response
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        return json;
      }
      throw BestBuyParseException(
        message: 'Expected JSON object, got ${json.runtimeType}',
        responseBody: body,
      );
    } on FormatException catch (e) {
      throw BestBuyParseException(
        message: 'Failed to parse JSON response: ${e.message}',
        responseBody: body,
        cause: e,
      );
    }
  }

  /// Returns a default error message for a given HTTP status code.
  String _getDefaultErrorMessage(int statusCode) {
    return switch (statusCode) {
      400 => 'Bad request: invalid query syntax',
      401 => 'Unauthorized: invalid API key',
      403 => 'Forbidden: API key lacks required permissions',
      404 => 'Resource not found',
      429 => 'Rate limit exceeded: too many requests',
      500 => 'Internal server error',
      502 => 'Bad gateway',
      503 => 'Service temporarily unavailable',
      504 => 'Gateway timeout',
      _ => 'HTTP error $statusCode',
    };
  }
}

