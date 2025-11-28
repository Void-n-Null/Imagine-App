/// Represents a category from the Best Buy Categories API.
class BestBuyCategory {
  /// Unique category identifier (e.g., "abcat0101000").
  final String id;

  /// Display name of the category.
  final String name;

  /// Whether this category is currently active.
  final bool? active;

  /// Full URL path to the category on bestbuy.com.
  final String? url;

  /// List of child subcategory IDs.
  final List<String> subCategories;

  /// Path of ancestor category IDs from root to this category.
  final List<CategoryPathItem> path;

  BestBuyCategory({
    required this.id,
    required this.name,
    this.active,
    this.url,
    this.subCategories = const [],
    this.path = const [],
  });

  factory BestBuyCategory.fromJson(Map<String, dynamic> json) {
    return BestBuyCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      active: json['active'] as bool?,
      url: json['url'] as String?,
      subCategories: (json['subCategories'] as List<dynamic>?)
              ?.map((e) => (e as Map<String, dynamic>)['id'] as String)
              .whereType<String>()
              .toList() ??
          const [],
      path: (json['path'] as List<dynamic>?)
              ?.map((e) => CategoryPathItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'active': active,
      'url': url,
      'subCategories': subCategories.map((e) => {'id': e}).toList(),
      'path': path.map((e) => e.toJson()).toList(),
    };
  }

  /// Returns true if this is a top-level category (no parent).
  bool get isTopLevel => path.length <= 1;

  /// Returns the parent category ID, if any.
  String? get parentId => path.length > 1 ? path[path.length - 2].id : null;

  @override
  String toString() => 'BestBuyCategory(id: $id, name: $name)';
}

/// Represents an item in a category's path hierarchy.
class CategoryPathItem {
  final String? id;
  final String? name;

  CategoryPathItem({this.id, this.name});

  factory CategoryPathItem.fromJson(Map<String, dynamic> json) {
    return CategoryPathItem(
      id: json['id'] as String?,
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  @override
  String toString() => name ?? id ?? 'Unknown';
}

/// Paginated response from Best Buy Categories API.
class CategorySearchResponse {
  final int from;
  final int to;
  final int total;
  final int currentPage;
  final int totalPages;
  final List<BestBuyCategory> categories;

  CategorySearchResponse({
    required this.from,
    required this.to,
    required this.total,
    required this.currentPage,
    required this.totalPages,
    required this.categories,
  });

  factory CategorySearchResponse.fromJson(Map<String, dynamic> json) {
    return CategorySearchResponse(
      from: json['from'] as int? ?? 1,
      to: json['to'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      currentPage: json['currentPage'] as int? ?? 1,
      totalPages: json['totalPages'] as int? ?? 0,
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => BestBuyCategory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  bool get hasNextPage => currentPage < totalPages;
  bool get hasPreviousPage => currentPage > 1;
  bool get isEmpty => categories.isEmpty;
  bool get isNotEmpty => categories.isNotEmpty;
  int get count => categories.length;
}

