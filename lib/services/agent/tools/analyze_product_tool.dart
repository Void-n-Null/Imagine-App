import '../../bestbuy/bestbuy.dart';
import '../../bestbuy/search_builder.dart';
import '../tool.dart';
import '../../../config/api_keys.dart';

/// Tool for getting detailed product information by SKU or UPC.
class AnalyzeProductTool extends Tool {
  final BestBuyClient _client;
  
  AnalyzeProductTool({BestBuyClient? client}) 
      : _client = client ?? BestBuyClient(apiKey: ApiKeys.bestBuy);
  
  @override
  String get name => 'analyze_product';
  
  @override
  String get displayName => 'Analyzing Product...';
  
  @override
  String get description => '''Get comprehensive details about a specific product.
Use this when you need full product information including specs, features, reviews, and availability.
Provide either a SKU (numeric ID) or UPC (barcode number).
This returns detailed data suitable for answering specific questions about a product.''';
  
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'sku': {
        'type': 'integer',
        'description': 'The Best Buy SKU (Stock Keeping Unit) number. A unique numeric identifier for the product.',
      },
      'upc': {
        'type': 'string',
        'description': 'The UPC (Universal Product Code) barcode number. Usually 12-13 digits.',
      },
    },
    'required': [],
  };
  
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      final sku = args['sku'] as int?;
      final upc = args['upc'] as String?;
      
      if (sku == null && upc == null) {
        return 'Error: Please provide either a SKU or UPC to look up the product.';
      }
      
      BestBuyProduct? product;
      
      if (sku != null) {
        product = await _client.getProductBySku(sku, attributes: ProductAttributePresets.full);
      } else if (upc != null) {
        product = await _client.getProductByUpc(upc, attributes: ProductAttributePresets.full);
      }
      
      if (product == null) {
        return 'Product not found. Please verify the ${sku != null ? 'SKU' : 'UPC'} and try again.';
      }
      
      return _formatProductDetails(product);
    } catch (e) {
      return 'Error analyzing product: $e';
    }
  }
  
  String _formatProductDetails(BestBuyProduct product) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('# ${product.name}');
    buffer.writeln();
    
    // Identifiers
    buffer.writeln('## Identifiers');
    buffer.writeln('- **SKU**: ${product.sku}');
    if (product.upc != null) buffer.writeln('- **UPC**: ${product.upc}');
    if (product.modelNumber != null) buffer.writeln('- **Model**: ${product.modelNumber}');
    if (product.manufacturer != null) buffer.writeln('- **Brand**: ${product.manufacturer}');
    buffer.writeln();
    
    // Pricing
    buffer.writeln('## Pricing');
    if (product.onSale == true) {
      buffer.writeln('- **Current Price**: \$${product.salePrice?.toStringAsFixed(2)} (ON SALE!)');
      buffer.writeln('- **Regular Price**: \$${product.regularPrice?.toStringAsFixed(2)}');
      buffer.writeln('- **You Save**: \$${product.dollarSavings?.toStringAsFixed(2)} (${product.percentSavings?.toStringAsFixed(0)}% off)');
    } else {
      buffer.writeln('- **Price**: \$${product.regularPrice?.toStringAsFixed(2)}');
    }
    buffer.writeln();
    
    // Availability
    buffer.writeln('## Availability');
    buffer.writeln('- **Online**: ${product.onlineAvailability == true ? '✅ Available' : '❌ Not available'}');
    if (product.onlineAvailabilityText != null) {
      buffer.writeln('  - ${product.onlineAvailabilityText}');
    }
    buffer.writeln('- **In-Store**: ${product.inStoreAvailability == true ? '✅ Available' : '❌ Not available'}');
    if (product.inStoreAvailabilityText != null) {
      buffer.writeln('  - ${product.inStoreAvailabilityText}');
    }
    if (product.freeShipping == true) {
      buffer.writeln('- **Shipping**: 🚚 FREE shipping');
    } else if (product.shippingCost != null) {
      buffer.writeln('- **Shipping**: \$${product.shippingCost}');
    }
    buffer.writeln();
    
    // Customer Reviews
    if (product.customerReviewAverage != null) {
      buffer.writeln('## Customer Reviews');
      final stars = '⭐' * product.customerReviewAverage!.round();
      buffer.writeln('- **Rating**: $stars ${product.customerReviewAverage!.toStringAsFixed(1)}/5');
      buffer.writeln('- **Total Reviews**: ${product.customerReviewCount ?? 0}');
      buffer.writeln();
    }
    
    // Description
    if (product.shortDescription != null || product.longDescription != null) {
      buffer.writeln('## Description');
      if (product.shortDescription != null) {
        buffer.writeln(product.shortDescription);
      } else if (product.longDescription != null) {
        // Truncate long description
        final desc = product.longDescription!;
        buffer.writeln(desc.length > 500 ? '${desc.substring(0, 500)}...' : desc);
      }
      buffer.writeln();
    }
    
    // Features
    if (product.features.isNotEmpty) {
      buffer.writeln('## Key Features');
      for (final feature in product.features.take(10)) {
        buffer.writeln('- $feature');
      }
      if (product.features.length > 10) {
        buffer.writeln('- ... and ${product.features.length - 10} more features');
      }
      buffer.writeln();
    }
    
    // Specifications
    if (product.details.isNotEmpty) {
      buffer.writeln('## Specifications');
      for (final detail in product.details.take(15)) {
        if (detail.name != null && detail.value != null) {
          buffer.writeln('- **${detail.name}**: ${detail.value}');
        }
      }
      if (product.details.length > 15) {
        buffer.writeln('- ... and ${product.details.length - 15} more specs');
      }
      buffer.writeln();
    }
    
    // Physical Dimensions
    if (product.height != null || product.width != null || product.depth != null || product.weight != null) {
      buffer.writeln('## Physical Dimensions');
      if (product.height != null) buffer.writeln('- **Height**: ${product.height}');
      if (product.width != null) buffer.writeln('- **Width**: ${product.width}');
      if (product.depth != null) buffer.writeln('- **Depth**: ${product.depth}');
      if (product.weight != null) buffer.writeln('- **Weight**: ${product.weight}');
      buffer.writeln();
    }
    
    // Category
    if (product.categoryPath.isNotEmpty) {
      buffer.writeln('## Category');
      buffer.writeln(product.categoryPath.map((c) => c.name ?? c.id).join(' > '));
      buffer.writeln();
    }
    
    // What's Included
    if (product.includedItemList.isNotEmpty) {
      buffer.writeln('## What\'s in the Box');
      for (final item in product.includedItemList) {
        buffer.writeln('- $item');
      }
      buffer.writeln();
    }
    
    // Special Offers
    if (product.offers.isNotEmpty) {
      buffer.writeln('## Special Offers');
      for (final offer in product.offers) {
        if (offer.text != null) {
          buffer.writeln('- 🏷️ ${offer.text}');
        }
      }
      buffer.writeln();
    }
    
    // Status Flags
    final flags = <String>[];
    if (product.new_ == true) flags.add('🆕 New');
    if (product.bestBuyOnly == true) flags.add('⭐ Best Buy Exclusive');
    if (product.refurbished == true) flags.add('♻️ Refurbished');
    if (product.preowned == true) flags.add('📦 Pre-owned');
    if (product.digital == true) flags.add('💾 Digital');
    if (product.marketplace == true) flags.add('🏪 Marketplace');
    
    if (flags.isNotEmpty) {
      buffer.writeln('## Product Status');
      buffer.writeln(flags.join(' • '));
      buffer.writeln();
    }
    
    // Links
    buffer.writeln('## Links');
    if (product.url != null) {
      buffer.writeln('- Product Page: ${product.url}');
    }
    buffer.writeln();
    
    // Reminder
    buffer.writeln('---');
    buffer.writeln('To display this product to the user, use: [Product(${product.sku})]');
    
    return buffer.toString();
  }
}

