import 'product.dart';

/// Paginated response from Best Buy Products API search.
///
/// Contains the list of products along with pagination metadata.
class ProductSearchResponse {
  /// Start index of the current page (1-based).
  final int from;

  /// End index of the current page.
  final int to;

  /// Total number of products matching the query.
  final int total;

  /// Current page number (1-based).
  final int currentPage;

  /// Total number of pages available.
  final int totalPages;

  /// The search query that was used.
  final String? queryTime;

  /// Total time taken for the query in milliseconds.
  final String? totalTime;

  /// Canonical URL for the query.
  final String? canonicalUrl;

  /// List of products in this response.
  final List<BestBuyProduct> products;

  ProductSearchResponse({
    required this.from,
    required this.to,
    required this.total,
    required this.currentPage,
    required this.totalPages,
    this.queryTime,
    this.totalTime,
    this.canonicalUrl,
    required this.products,
  });

  factory ProductSearchResponse.fromJson(Map<String, dynamic> json) {
    return ProductSearchResponse(
      from: json['from'] as int? ?? 1,
      to: json['to'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      currentPage: json['currentPage'] as int? ?? 1,
      totalPages: json['totalPages'] as int? ?? 0,
      queryTime: json['queryTime'] as String?,
      totalTime: json['totalTime'] as String?,
      canonicalUrl: json['canonicalUrl'] as String?,
      products: (json['products'] as List<dynamic>?)
              ?.map((e) => BestBuyProduct.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from': from,
      'to': to,
      'total': total,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'queryTime': queryTime,
      'totalTime': totalTime,
      'canonicalUrl': canonicalUrl,
      'products': products.map((e) => e.toJson()).toList(),
    };
  }

  /// Returns true if there are more pages after the current one.
  bool get hasNextPage => currentPage < totalPages;

  /// Returns true if there are pages before the current one.
  bool get hasPreviousPage => currentPage > 1;

  /// Returns true if the response contains no products.
  bool get isEmpty => products.isEmpty;

  /// Returns true if the response contains products.
  bool get isNotEmpty => products.isNotEmpty;

  /// Number of products in this page.
  int get count => products.length;

  @override
  String toString() =>
      'ProductSearchResponse(total: $total, page: $currentPage/$totalPages, count: $count)';
}

