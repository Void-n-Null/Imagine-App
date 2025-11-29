/// Best Buy API client for Flutter.
///
/// A comprehensive client for the Best Buy Products, Categories, and Stores APIs.
///
/// ## Getting Started
///
/// 1. Get an API key from the [Best Buy Developer Portal](https://developer.bestbuy.com/)
/// 2. Create a client instance:
///
/// ```dart
/// import 'package:imagineapp/services/bestbuy/bestbuy.dart';
///
/// final client = BestBuyClient(apiKey: 'YOUR_API_KEY');
/// ```
///
/// ## Searching Products
///
/// Use the fluent search builder for powerful queries:
///
/// ```dart
/// // Simple keyword search
/// final results = await client.products()
///     .search("laptop")
///     .execute();
///
/// // Advanced search with filters
/// final results = await client.products()
///     .search("gaming laptop")
///     .inCategory("abcat0502000")
///     .priceRange(min: 800, max: 2000)
///     .onSale()
///     .availableOnline()
///     .minRating(4.0)
///     .sortBy(ProductSort.customerReviewAverage)
///     .withAttributes(ProductAttributePresets.card)
///     .pageSize(25)
///     .execute();
/// ```
///
/// ## Looking Up Products
///
/// ```dart
/// // By UPC (barcode)
/// final product = await client.getProductByUpc("194253715375");
///
/// // By SKU
/// final product = await client.getProductBySku(6525432);
///
/// // Multiple products
/// final products = await client.getProductsBySkus([6525432, 6525433, 6525434]);
/// ```
///
/// ## Error Handling
///
/// ```dart
/// try {
///   final product = await client.getProductByUpc(upc);
/// } on BestBuyApiException catch (e) {
///   if (e.isRateLimitError) {
///     // Wait and retry
///   } else if (e.isAuthError) {
///     // Check API key
///   }
/// } on BestBuyNetworkException catch (e) {
///   // Handle network issues
/// }
/// ```
///
/// ## Cleanup
///
/// ```dart
/// // When done, close the client to release resources
/// client.close();
/// ```
library;

export 'bestbuy_client.dart';
export 'bestbuy_exception.dart';
export 'category_finder.dart';
export 'models/category.dart';
export 'models/product.dart';
export 'models/search_response.dart';
export 'models/store.dart';
export 'search_builder.dart';
export 'search_debug_logger.dart';

