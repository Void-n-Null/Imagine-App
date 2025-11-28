import '../../bestbuy/bestbuy.dart';
import '../../bestbuy/search_builder.dart';
import '../tool.dart';
import '../../../config/api_keys.dart';

/// Tool for searching Best Buy products with various filters.
class SearchProductsTool extends Tool {
  final BestBuyClient _client;
  
  SearchProductsTool({BestBuyClient? client}) 
      : _client = client ?? BestBuyClient(apiKey: ApiKeys.bestBuy);
  
  @override
  String get name => 'search_products';
  
  @override
  String get displayName => 'Searching Products...';
  
  @override
  String get description => '''Search for products in the Best Buy catalog.
Returns a list of matching products with basic info (SKU, name, price, availability).
Use this to find products by keyword, category, price range, or other criteria.
After finding products, you can show them to the user using [Product(SKU)] syntax.''';
  
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'query': {
        'type': 'string',
        'description': 'Search keywords (e.g., "iPhone 15", "4K TV", "gaming laptop"). Required unless searching by category.',
      },
      'category_id': {
        'type': 'string',
        'description': 'Best Buy category ID to filter results (e.g., "abcat0502000" for laptops). Optional.',
      },
      'manufacturer': {
        'type': 'string',
        'description': 'Filter by manufacturer/brand name (e.g., "Apple", "Samsung", "Sony"). Optional.',
      },
      'min_price': {
        'type': 'number',
        'description': 'Minimum price in dollars. Optional.',
      },
      'max_price': {
        'type': 'number',
        'description': 'Maximum price in dollars. Optional.',
      },
      'on_sale': {
        'type': 'boolean',
        'description': 'If true, only return products currently on sale. Optional.',
      },
      'in_stock': {
        'type': 'boolean',
        'description': 'If true, only return products available online. Optional.',
      },
      'free_shipping': {
        'type': 'boolean',
        'description': 'If true, only return products with free shipping. Optional.',
      },
      'min_rating': {
        'type': 'number',
        'description': 'Minimum customer review rating (1-5). Optional.',
      },
      'sort_by': {
        'type': 'string',
        'enum': ['best_selling', 'price_low', 'price_high', 'rating', 'newest', 'name'],
        'description': 'How to sort results. Default is "best_selling".',
      },
      'limit': {
        'type': 'integer',
        'description': 'Maximum number of results to return (1-20). Default is 5.',
      },
    },
    'required': [],
  };
  
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      var builder = _client.products();
      
      // Apply search query
      final query = args['query'] as String?;
      if (query != null && query.isNotEmpty) {
        builder = builder.search(query);
      }
      
      // Apply category filter
      final categoryId = args['category_id'] as String?;
      if (categoryId != null && categoryId.isNotEmpty) {
        builder = builder.inCategory(categoryId);
      }
      
      // Apply manufacturer filter
      final manufacturer = args['manufacturer'] as String?;
      if (manufacturer != null && manufacturer.isNotEmpty) {
        builder = builder.byManufacturer(manufacturer);
      }
      
      // Apply price range
      final minPrice = (args['min_price'] as num?)?.toDouble();
      final maxPrice = (args['max_price'] as num?)?.toDouble();
      if (minPrice != null || maxPrice != null) {
        builder = builder.priceRange(min: minPrice, max: maxPrice);
      }
      
      // Apply on sale filter
      if (args['on_sale'] == true) {
        builder = builder.onSale();
      }
      
      // Apply in stock filter
      if (args['in_stock'] == true) {
        builder = builder.availableOnline();
      }
      
      // Apply free shipping filter
      if (args['free_shipping'] == true) {
        builder = builder.freeShipping();
      }
      
      // Apply rating filter
      final minRating = (args['min_rating'] as num?)?.toDouble();
      if (minRating != null) {
        builder = builder.minRating(minRating);
      }
      
      // Apply sorting
      final sortBy = args['sort_by'] as String? ?? 'best_selling';
      final sort = switch (sortBy) {
        'price_low' => ProductSort.salePriceAsc,
        'price_high' => ProductSort.salePriceDesc,
        'rating' => ProductSort.customerReviewAverage,
        'newest' => ProductSort.releaseDateDesc,
        'name' => ProductSort.nameAsc,
        _ => ProductSort.bestSellingRank,
      };
      builder = builder.sortBy(sort);
      
      // Apply limit
      final limit = (args['limit'] as int?) ?? 5;
      builder = builder.pageSize(limit.clamp(1, 20));
      
      // Use card attributes for reasonable response size
      builder = builder.withAttributes(ProductAttributePresets.card);
      
      // Execute search
      final response = await builder.execute();
      
      if (response.products.isEmpty) {
        return 'No products found matching your criteria.';
      }
      
      // Format results
      final buffer = StringBuffer();
      buffer.writeln('Found ${response.total} products (showing ${response.products.length}):');
      buffer.writeln();
      
      for (final product in response.products) {
        buffer.writeln('---');
        buffer.writeln('**${product.name}**');
        buffer.writeln('- SKU: ${product.sku}');
        if (product.manufacturer != null) {
          buffer.writeln('- Brand: ${product.manufacturer}');
        }
        
        // Price info
        if (product.onSale == true && product.regularPrice != null) {
          buffer.writeln('- Price: \$${product.salePrice?.toStringAsFixed(2)} (was \$${product.regularPrice!.toStringAsFixed(2)}, save ${product.percentSavings?.toStringAsFixed(0)}%)');
        } else {
          buffer.writeln('- Price: \$${product.effectivePrice?.toStringAsFixed(2) ?? 'N/A'}');
        }
        
        // Availability
        final available = <String>[];
        if (product.onlineAvailability == true) available.add('Online');
        if (product.inStoreAvailability == true) available.add('In-Store');
        if (available.isNotEmpty) {
          buffer.writeln('- Available: ${available.join(', ')}');
        }
        
        // Rating
        if (product.customerReviewAverage != null) {
          buffer.writeln('- Rating: ${product.customerReviewAverage!.toStringAsFixed(1)}/5 (${product.customerReviewCount} reviews)');
        }
        
        buffer.writeln();
      }
      
      buffer.writeln('---');
      buffer.writeln('To show a product to the user, use: [Product(SKU)]');
      
      return buffer.toString();
    } catch (e) {
      return 'Error searching products: $e';
    }
  }
}

