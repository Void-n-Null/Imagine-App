import '../../bestbuy/bestbuy.dart';
import '../../comparison/comparison.dart';
import '../tool.dart';
import '../../../config/api_keys.dart';

/// Tool for comparing multiple products by their SKUs or UPCs.
/// Returns a detailed side-by-side comparison of product specifications.
class CompareProductsTool extends Tool {
  final BestBuyClient _client;
  
  CompareProductsTool({BestBuyClient? client}) 
      : _client = client ?? BestBuyClient(apiKey: ApiKeys.bestBuy);
  
  @override
  String get name => 'compare_products';
  
  @override
  String get displayName => 'Comparing Products...';
  
  @override
  String get description => '''Compare multiple products side by side.
Provide a list of 2-5 SKUs or UPCs to get a detailed comparison of their specifications, prices, and features.
This returns a structured comparison highlighting differences and similarities between products.
Use this when users want to compare options or decide between similar products.''';
  
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'skus': {
        'type': 'array',
        'items': {'type': 'integer'},
        'description': 'List of Best Buy SKU numbers to compare (2-5 products).',
        'minItems': 2,
        'maxItems': 5,
      },
      'upcs': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'List of UPC barcode numbers to compare (2-5 products). Use this if you have UPCs instead of SKUs.',
        'minItems': 2,
        'maxItems': 5,
      },
    },
    'required': [],
  };
  
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      final skusList = args['skus'] as List<dynamic>?;
      final upcsList = args['upcs'] as List<dynamic>?;
      
      // Convert to typed lists
      final skus = skusList?.map((e) => e as int).toList() ?? [];
      final upcs = upcsList?.map((e) => e.toString()).toList() ?? [];
      
      if (skus.isEmpty && upcs.isEmpty) {
        return 'Error: Please provide at least 2 SKUs or UPCs to compare products.';
      }
      
      final totalProducts = skus.length + upcs.length;
      if (totalProducts < 2) {
        return 'Error: Need at least 2 products to compare. Provide more SKUs or UPCs.';
      }
      if (totalProducts > 5) {
        return 'Error: Can only compare up to 5 products at a time. Please reduce the number of products.';
      }
      
      // Fetch all products
      final products = <BestBuyProduct>[];
      final notFound = <String>[];
      
      // Fetch by SKU
      for (final sku in skus) {
        try {
          final product = await _client.getProductBySku(sku, attributes: ProductAttributePresets.full);
          if (product != null) {
            products.add(product);
          } else {
            notFound.add('SKU $sku');
          }
        } catch (e) {
          notFound.add('SKU $sku');
        }
      }
      
      // Fetch by UPC
      for (final upc in upcs) {
        try {
          final product = await _client.getProductByUpc(upc, attributes: ProductAttributePresets.full);
          if (product != null) {
            products.add(product);
          } else {
            notFound.add('UPC $upc');
          }
        } catch (e) {
          notFound.add('UPC $upc');
        }
      }
      
      if (products.length < 2) {
        return 'Error: Could not find enough products to compare. ${notFound.isNotEmpty ? 'Not found: ${notFound.join(", ")}' : ''}';
      }
      
      // Run comparison
      final engine = ProductComparisonEngine();
      final result = engine.compare(products);
      
      // Format the comparison result
      return _formatComparison(result, products, notFound);
    } catch (e) {
      return 'Error comparing products: $e';
    }
  }
  
  String _formatComparison(
    ProductComparisonResult result, 
    List<BestBuyProduct> products,
    List<String> notFound,
  ) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('# Product Comparison');
    buffer.writeln();
    
    if (notFound.isNotEmpty) {
      buffer.writeln('⚠️ **Note**: Could not find: ${notFound.join(", ")}');
      buffer.writeln();
    }
    
    // Product Overview
    buffer.writeln('## Products Being Compared');
    buffer.writeln();
    for (int i = 0; i < products.length; i++) {
      final p = products[i];
      buffer.writeln('**${i + 1}. ${p.name}**');
      buffer.writeln('   - SKU: ${p.sku}');
      buffer.writeln('   - Price: \$${p.effectivePrice?.toStringAsFixed(2) ?? 'N/A'}${p.onSale == true ? ' (ON SALE!)' : ''}');
      if (p.customerReviewAverage != null) {
        buffer.writeln('   - Rating: ${p.customerReviewAverage!.toStringAsFixed(1)}/5 (${p.customerReviewCount ?? 0} reviews)');
      }
      buffer.writeln();
    }
    
    // Price Comparison
    buffer.writeln('## Price Comparison');
    buffer.writeln();
    _writeComparisonRow(buffer, 'Price', result.productPrices.map((p) => p != null ? '\$${p.toStringAsFixed(2)}' : 'N/A').toList());
    
    // Find products on sale
    final saleProducts = products.where((p) => p.onSale == true).toList();
    if (saleProducts.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('🏷️ **On Sale**: ${saleProducts.map((p) => p.name.length > 30 ? '${p.name.substring(0, 30)}...' : p.name).join(', ')}');
    }
    buffer.writeln();
    
    // Key Differences
    final differences = result.rowsWithDifferences;
    if (differences.isNotEmpty) {
      buffer.writeln('## Key Differences');
      buffer.writeln();
      
      // Show most important differences first (limit to 15)
      for (final row in differences.take(15)) {
        _writeComparisonRow(buffer, row.attributeName, row.values.map((v) => v ?? '—').toList());
        
        // Add numeric insight if available
        if (row.hasNumericComparison && result.isTwoProductComparison) {
          final diff = row.comparison?.numericDifference;
          if (diff != null && diff.percentageDifference != null && diff.percentageDifference!.abs() >= 5) {
            buffer.writeln('   *(${diff.description})*');
          }
        }
      }
      
      if (differences.length > 15) {
        buffer.writeln();
        buffer.writeln('*...and ${differences.length - 15} more differences*');
      }
      buffer.writeln();
    }
    
    // Similarities (if any notable ones)
    final similarities = result.rows.where((r) => r.allValuesSame).take(10).toList();
    if (similarities.isNotEmpty) {
      buffer.writeln('## Similarities');
      buffer.writeln();
      for (final row in similarities) {
        final value = row.values.firstWhere((v) => v != null, orElse: () => '—');
        buffer.writeln('- **${row.attributeName}**: $value');
      }
      buffer.writeln();
    }
    
    // Unique Features
    if (result.uniqueRows.isNotEmpty) {
      buffer.writeln('## Unique Features');
      buffer.writeln();
      for (final row in result.uniqueRows.take(10)) {
        final productIndex = row.uniqueProductIndex ?? 0;
        final productName = products[productIndex].name;
        final shortName = productName.length > 25 ? '${productName.substring(0, 25)}...' : productName;
        final value = row.values[productIndex] ?? '—';
        buffer.writeln('- **${row.attributeName}** ($shortName): $value');
      }
      if (result.uniqueRows.length > 10) {
        buffer.writeln('*...and ${result.uniqueRows.length - 10} more unique features*');
      }
      buffer.writeln();
    }
    
    // Quick Summary for 2-product comparison
    if (result.isTwoProductComparison) {
      buffer.writeln('## Quick Summary');
      buffer.writeln();
      
      final p1 = products[0];
      final p2 = products[1];
      
      // Price comparison
      if (p1.effectivePrice != null && p2.effectivePrice != null) {
        final priceDiff = p2.effectivePrice! - p1.effectivePrice!;
        if (priceDiff.abs() > 0.01) {
          final cheaper = priceDiff > 0 ? p1 : p2;
          final savings = priceDiff.abs();
          buffer.writeln('- 💰 **${cheaper.name.length > 30 ? '${cheaper.name.substring(0, 30)}...' : cheaper.name}** is \$${savings.toStringAsFixed(2)} cheaper');
        }
      }
      
      // Rating comparison
      if (p1.customerReviewAverage != null && p2.customerReviewAverage != null) {
        final ratingDiff = p2.customerReviewAverage! - p1.customerReviewAverage!;
        if (ratingDiff.abs() >= 0.3) {
          final better = ratingDiff > 0 ? p2 : p1;
          buffer.writeln('- ⭐ **${better.name.length > 30 ? '${better.name.substring(0, 30)}...' : better.name}** is rated higher (${better.customerReviewAverage!.toStringAsFixed(1)}/5)');
        }
      }
      buffer.writeln();
    }
    
    // Display syntax
    buffer.writeln('---');
    buffer.writeln('To show this comparison to the user, use: [Compare(${result.productSkus.join(',')})]');
    buffer.writeln();
    buffer.writeln('Or show individual products:');
    for (final sku in result.productSkus) {
      buffer.writeln('- [Product($sku)]');
    }
    
    return buffer.toString();
  }
  
  void _writeComparisonRow(StringBuffer buffer, String attribute, List<String> values) {
    buffer.writeln('| **$attribute** |');
    for (int i = 0; i < values.length; i++) {
      buffer.writeln('  - Product ${i + 1}: ${values[i]}');
    }
  }
}
