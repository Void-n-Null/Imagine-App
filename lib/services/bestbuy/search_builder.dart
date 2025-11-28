import 'dart:async';

import 'models/search_response.dart';

/// Sorting options for product search results.
enum ProductSort {
  /// Sort by best selling rank (most popular first).
  bestSellingRank('bestSellingRank.asc'),

  /// Sort by customer review rating (highest first).
  customerReviewAverage('customerReviewAverage.dsc'),

  /// Sort by customer review count (most reviews first).
  customerReviewCount('customerReviewCount.dsc'),

  /// Sort by sale price (lowest first).
  salePriceAsc('salePrice.asc'),

  /// Sort by sale price (highest first).
  salePriceDesc('salePrice.dsc'),

  /// Sort by product name (A-Z).
  nameAsc('name.asc'),

  /// Sort by product name (Z-A).
  nameDesc('name.dsc'),

  /// Sort by SKU (ascending).
  skuAsc('sku.asc'),

  /// Sort by release date (newest first).
  releaseDateDesc('releaseDate.dsc'),

  /// Sort by release date (oldest first).
  releaseDateAsc('releaseDate.asc');

  final String value;
  const ProductSort(this.value);
}

/// Common product attributes that can be requested.
///
/// Use these with [ProductSearchBuilder.withAttributes] to limit response size
/// and improve performance by only requesting the fields you need.
enum ProductAttribute {
  // Core
  sku('sku'),
  upc('upc'),
  name('name'),
  type('type'),
  modelNumber('modelNumber'),
  manufacturer('manufacturer'),
  url('url'),
  addToCartUrl('addToCartUrl'),
  mobileUrl('mobileUrl'),

  // Pricing
  regularPrice('regularPrice'),
  salePrice('salePrice'),
  onSale('onSale'),
  percentSavings('percentSavings'),
  dollarSavings('dollarSavings'),
  priceUpdateDate('priceUpdateDate'),

  // Availability
  inStoreAvailability('inStoreAvailability'),
  inStoreAvailabilityText('inStoreAvailabilityText'),
  onlineAvailability('onlineAvailability'),
  onlineAvailabilityText('onlineAvailabilityText'),
  orderable('orderable'),
  freeShipping('freeShipping'),
  shippingCost('shippingCost'),
  releaseDate('releaseDate'),

  // Media
  image('image'),
  thumbnailImage('thumbnailImage'),
  mediumImage('mediumImage'),
  largeFrontImage('largeFrontImage'),
  largeImage('largeImage'),
  images('images'),

  // Description
  longDescription('longDescription'),
  shortDescription('shortDescription'),
  features('features'),
  includedItemList('includedItemList'),
  condition('condition'),

  // Categories
  categoryPath('categoryPath'),
  productClass('class'),
  classId('classId'),
  subclass('subclass'),
  department('department'),

  // Reviews
  customerReviewAverage('customerReviewAverage'),
  customerReviewCount('customerReviewCount'),

  // Physical
  weight('weight'),
  shippingWeight('shippingWeight'),
  height('height'),
  width('width'),
  depth('depth'),
  color('color'),

  // Flags
  active('active'),
  isNew('new'),
  preowned('preowned'),
  refurbished('refurbished'),
  digital('digital'),
  marketplace('marketplace'),
  bestBuyOnly('bestBuyOnly'),

  // Fulfillment
  homeDelivery('homeDelivery'),
  storePickup('storePickup'),
  friendsAndFamilyPickup('friendsAndFamilyPickup'),

  // Extras
  offers('offers'),
  details('details');

  final String value;
  const ProductAttribute(this.value);
}

/// Preset attribute collections for common use cases.
class ProductAttributePresets {
  ProductAttributePresets._();

  /// Minimal attributes for list views (name, price, image).
  static const List<ProductAttribute> minimal = [
    ProductAttribute.sku,
    ProductAttribute.name,
    ProductAttribute.salePrice,
    ProductAttribute.regularPrice,
    ProductAttribute.onSale,
    ProductAttribute.thumbnailImage,
  ];

  /// Standard attributes for product cards.
  static const List<ProductAttribute> card = [
    ProductAttribute.sku,
    ProductAttribute.upc,
    ProductAttribute.name,
    ProductAttribute.manufacturer,
    ProductAttribute.salePrice,
    ProductAttribute.regularPrice,
    ProductAttribute.onSale,
    ProductAttribute.percentSavings,
    ProductAttribute.image,
    ProductAttribute.customerReviewAverage,
    ProductAttribute.customerReviewCount,
    ProductAttribute.onlineAvailability,
    ProductAttribute.inStoreAvailability,
  ];

  /// Full attributes for product detail views.
  static const List<ProductAttribute> full = [
    ProductAttribute.sku,
    ProductAttribute.upc,
    ProductAttribute.name,
    ProductAttribute.type,
    ProductAttribute.modelNumber,
    ProductAttribute.manufacturer,
    ProductAttribute.url,
    ProductAttribute.addToCartUrl,
    ProductAttribute.regularPrice,
    ProductAttribute.salePrice,
    ProductAttribute.onSale,
    ProductAttribute.percentSavings,
    ProductAttribute.dollarSavings,
    ProductAttribute.inStoreAvailability,
    ProductAttribute.inStoreAvailabilityText,
    ProductAttribute.onlineAvailability,
    ProductAttribute.onlineAvailabilityText,
    ProductAttribute.freeShipping,
    ProductAttribute.shippingCost,
    ProductAttribute.releaseDate,
    ProductAttribute.image,
    ProductAttribute.mediumImage,
    ProductAttribute.largeImage,
    ProductAttribute.images,
    ProductAttribute.longDescription,
    ProductAttribute.shortDescription,
    ProductAttribute.features,
    ProductAttribute.includedItemList,
    ProductAttribute.categoryPath,
    ProductAttribute.customerReviewAverage,
    ProductAttribute.customerReviewCount,
    ProductAttribute.color,
    ProductAttribute.condition,
    ProductAttribute.offers,
    ProductAttribute.details,
  ];
}

/// Fluent builder for constructing Best Buy product search queries.
///
/// Example usage:
/// ```dart
/// final results = await client.products()
///     .search("laptop")
///     .inCategory("abcat0502000")
///     .priceRange(min: 500, max: 1500)
///     .onSale()
///     .sortBy(ProductSort.bestSellingRank)
///     .pageSize(25)
///     .execute();
/// ```
class ProductSearchBuilder {
  final Future<ProductSearchResponse> Function(
      Map<String, String> params, List<String> filters) _executor;

  final List<String> _searchTerms = [];
  final List<String> _filters = [];
  final List<ProductAttribute> _attributes = [];
  ProductSort? _sort;
  int _page = 1;
  int _pageSize = 10;

  ProductSearchBuilder(this._executor);

  // ─────────────────────────────────────────────────────────────────────────
  // Search terms
  // ─────────────────────────────────────────────────────────────────────────

  /// Adds a keyword search term.
  ///
  /// Multiple search terms are combined with AND logic.
  ProductSearchBuilder search(String keyword) {
    if (keyword.trim().isNotEmpty) {
      _searchTerms.add(keyword.trim());
    }
    return this;
  }

  /// Searches for products matching all of the given keywords.
  ProductSearchBuilder searchAll(List<String> keywords) {
    for (final keyword in keywords) {
      search(keyword);
    }
    return this;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filters
  // ─────────────────────────────────────────────────────────────────────────

  /// Filters by SKU (Stock Keeping Unit).
  ProductSearchBuilder bySku(int sku) {
    _filters.add('sku=$sku');
    return this;
  }

  /// Filters by multiple SKUs.
  ProductSearchBuilder bySkus(List<int> skus) {
    if (skus.isNotEmpty) {
      _filters.add('sku in(${skus.join(',')})');
    }
    return this;
  }

  /// Filters by UPC (Universal Product Code).
  ProductSearchBuilder byUpc(String upc) {
    _filters.add('upc=$upc');
    return this;
  }

  /// Filters by multiple UPCs.
  ProductSearchBuilder byUpcs(List<String> upcs) {
    if (upcs.isNotEmpty) {
      _filters.add('upc in(${upcs.join(',')})');
    }
    return this;
  }

  /// Filters by category ID.
  ProductSearchBuilder inCategory(String categoryId) {
    _filters.add('categoryPath.id=$categoryId');
    return this;
  }

  /// Filters by multiple category IDs (OR logic).
  ProductSearchBuilder inCategories(List<String> categoryIds) {
    if (categoryIds.isNotEmpty) {
      _filters.add('categoryPath.id in(${categoryIds.join(',')})');
    }
    return this;
  }

  /// Filters by manufacturer name (exact match).
  ProductSearchBuilder byManufacturer(String manufacturer) {
    _filters.add('manufacturer="$manufacturer"');
    return this;
  }

  /// Filters by manufacturers (OR logic).
  ProductSearchBuilder byManufacturers(List<String> manufacturers) {
    if (manufacturers.isNotEmpty) {
      final quoted = manufacturers.map((m) => '"$m"').join(',');
      _filters.add('manufacturer in($quoted)');
    }
    return this;
  }

  /// Filters by condition.
  ProductSearchBuilder condition(ProductCondition condition) {
    _filters.add('condition=${condition.value}');
    return this;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Price filters
  // ─────────────────────────────────────────────────────────────────────────

  /// Filters by price range.
  ///
  /// Both [min] and [max] are optional. If only one is provided,
  /// the filter will be >= min or <= max respectively.
  ProductSearchBuilder priceRange({double? min, double? max}) {
    if (min != null && max != null) {
      _filters.add('salePrice>=$min&salePrice<=$max');
    } else if (min != null) {
      _filters.add('salePrice>=$min');
    } else if (max != null) {
      _filters.add('salePrice<=$max');
    }
    return this;
  }

  /// Filters by exact price.
  ProductSearchBuilder exactPrice(double price) {
    _filters.add('salePrice=$price');
    return this;
  }

  /// Filters to only show products currently on sale.
  ProductSearchBuilder onSale() {
    _filters.add('onSale=true');
    return this;
  }

  /// Filters to only show products with free shipping.
  ProductSearchBuilder freeShipping() {
    _filters.add('freeShipping=true');
    return this;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Availability filters
  // ─────────────────────────────────────────────────────────────────────────

  /// Filters to only show products available online.
  ProductSearchBuilder availableOnline() {
    _filters.add('onlineAvailability=true');
    return this;
  }

  /// Filters to only show products available in-store.
  ProductSearchBuilder availableInStore() {
    _filters.add('inStoreAvailability=true');
    return this;
  }

  /// Filters to only show products available at a specific store.
  ProductSearchBuilder availableAtStore(int storeId) {
    _filters.add('storeAvailability.storeId=$storeId');
    return this;
  }

  /// Filters to only show orderable products.
  ProductSearchBuilder orderable() {
    _filters.add('orderable=Available');
    return this;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Product type filters
  // ─────────────────────────────────────────────────────────────────────────

  /// Filters to only show new products.
  ProductSearchBuilder isNew() {
    _filters.add('new=true');
    return this;
  }

  /// Filters to only show preowned products.
  ProductSearchBuilder preowned() {
    _filters.add('preowned=true');
    return this;
  }

  /// Filters to only show refurbished products.
  ProductSearchBuilder refurbished() {
    _filters.add('refurbished=true');
    return this;
  }

  /// Filters to only show digital products.
  ProductSearchBuilder digital() {
    _filters.add('digital=true');
    return this;
  }

  /// Filters to only show physical products.
  ProductSearchBuilder physical() {
    _filters.add('digital=false');
    return this;
  }

  /// Filters to only show Best Buy exclusive products.
  ProductSearchBuilder bestBuyOnly() {
    _filters.add('bestBuyOnly=true');
    return this;
  }

  /// Filters to only show marketplace products.
  ProductSearchBuilder marketplace() {
    _filters.add('marketplace=true');
    return this;
  }

  /// Filters to exclude marketplace products.
  ProductSearchBuilder excludeMarketplace() {
    _filters.add('marketplace=false');
    return this;
  }

  /// Filters to only show active products.
  ProductSearchBuilder active() {
    _filters.add('active=true');
    return this;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Rating filters
  // ─────────────────────────────────────────────────────────────────────────

  /// Filters by minimum customer review average (1-5 scale).
  ProductSearchBuilder minRating(double rating) {
    _filters.add('customerReviewAverage>=$rating');
    return this;
  }

  /// Filters by minimum number of customer reviews.
  ProductSearchBuilder minReviewCount(int count) {
    _filters.add('customerReviewCount>=$count');
    return this;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Physical attribute filters
  // ─────────────────────────────────────────────────────────────────────────

  /// Filters by color.
  ProductSearchBuilder color(String color) {
    _filters.add('color="$color"');
    return this;
  }

  /// Filters by colors (OR logic).
  ProductSearchBuilder colors(List<String> colors) {
    if (colors.isNotEmpty) {
      final quoted = colors.map((c) => '"$c"').join(',');
      _filters.add('color in($quoted)');
    }
    return this;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Date filters
  // ─────────────────────────────────────────────────────────────────────────

  /// Filters by release date range.
  ///
  /// Dates should be in ISO 8601 format (YYYY-MM-DD).
  ProductSearchBuilder releasedBetween({String? after, String? before}) {
    if (after != null) {
      _filters.add('releaseDate>=$after');
    }
    if (before != null) {
      _filters.add('releaseDate<=$before');
    }
    return this;
  }

  /// Filters to only show products released after the given date.
  ProductSearchBuilder releasedAfter(String date) {
    _filters.add('releaseDate>=$date');
    return this;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Custom filter
  // ─────────────────────────────────────────────────────────────────────────

  /// Adds a custom filter expression.
  ///
  /// Use this for filters not covered by the builder methods.
  /// Example: `filter('longDescription=iPhone*')`
  ProductSearchBuilder filter(String expression) {
    _filters.add(expression);
    return this;
  }

  /// Adds multiple custom filter expressions.
  ProductSearchBuilder filters(List<String> expressions) {
    _filters.addAll(expressions);
    return this;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Response shaping
  // ─────────────────────────────────────────────────────────────────────────

  /// Sets the attributes to include in the response.
  ///
  /// This reduces response size and improves performance.
  /// If not called, all attributes are returned.
  ProductSearchBuilder withAttributes(List<ProductAttribute> attributes) {
    _attributes.clear();
    _attributes.addAll(attributes);
    return this;
  }

  /// Uses a preset collection of attributes.
  ProductSearchBuilder withPreset(List<ProductAttribute> preset) {
    return withAttributes(preset);
  }

  /// Adds additional attributes to the current selection.
  ProductSearchBuilder addAttributes(List<ProductAttribute> attributes) {
    _attributes.addAll(attributes);
    return this;
  }

  /// Sets the sort order for results.
  ProductSearchBuilder sortBy(ProductSort sort) {
    _sort = sort;
    return this;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pagination
  // ─────────────────────────────────────────────────────────────────────────

  /// Sets the page number (1-based).
  ProductSearchBuilder page(int page) {
    _page = page.clamp(1, 1000);
    return this;
  }

  /// Sets the number of results per page.
  ///
  /// Maximum is 100 per Best Buy API limits.
  ProductSearchBuilder pageSize(int size) {
    _pageSize = size.clamp(1, 100);
    return this;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Execution
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds the query parameters without executing.
  ///
  /// Useful for debugging or logging the query.
  Map<String, String> buildParams() {
    final params = <String, String>{};

    // Build the combined filter/search string
    final queryParts = <String>[];

    // Add search terms
    if (_searchTerms.isNotEmpty) {
      final searchQuery = _searchTerms.map((t) => 'search=$t').join('&');
      queryParts.add('($searchQuery)');
    }

    // Add filters
    queryParts.addAll(_filters);

    // The query is passed as part of the URL path for the Products API
    // We'll return it separately for the client to handle
    if (queryParts.isNotEmpty) {
      params['_query'] = queryParts.join('&');
    }

    // Pagination
    params['page'] = _page.toString();
    params['pageSize'] = _pageSize.toString();

    // Sorting
    if (_sort != null) {
      params['sort'] = _sort!.value;
    }

    // Attributes (show parameter)
    if (_attributes.isNotEmpty) {
      params['show'] = _attributes.map((a) => a.value).join(',');
    }

    // Always request JSON
    params['format'] = 'json';

    return params;
  }

  /// Executes the search and returns the results.
  Future<ProductSearchResponse> execute() {
    final params = buildParams();
    final query = params.remove('_query') ?? '';
    final filterParts = query.isNotEmpty ? query.split('&') : <String>[];
    return _executor(params, filterParts);
  }

  /// Returns the built filter string for debugging.
  @override
  String toString() {
    final params = buildParams();
    return 'ProductSearchBuilder(${params.entries.map((e) => '${e.key}=${e.value}').join(', ')})';
  }
}

/// Product condition options.
enum ProductCondition {
  isNew('new'),
  refurbished('refurbished'),
  preOwned('pre-owned');

  final String value;
  const ProductCondition(this.value);
}

