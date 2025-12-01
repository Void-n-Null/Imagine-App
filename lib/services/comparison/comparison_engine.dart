import '../bestbuy/models/product.dart';
import 'comparison_models.dart';

/// Engine for comparing multiple products.
/// 
/// Handles:
/// - Fuzzy matching of attribute names across products
/// - Parsing numeric values with units
/// - Building comparison tables with intelligent difference calculations
class ProductComparisonEngine {
  /// Compare multiple products and generate a comparison result.
  ProductComparisonResult compare(List<BestBuyProduct> products) {
    if (products.isEmpty) {
      return const ProductComparisonResult(
        productSkus: [],
        productNames: [],
        productImages: [],
        productPrices: [],
        rows: [],
        uniqueRows: [],
      );
    }

    // Extract product metadata
    final skus = products.map((p) => p.sku).toList();
    final names = products.map((p) => p.name).toList();
    final images = products.map((p) => p.bestImage).toList();
    final prices = products.map((p) => p.effectivePrice).toList();

    // Collect all attributes from all products
    final attributeMap = _collectAttributes(products);

    // Build comparison rows
    final rows = <ComparisonRow>[];
    final uniqueRows = <ComparisonRow>[];

    for (final entry in attributeMap.entries) {
      final normalizedName = entry.key;
      final attributeData = entry.value;

      // Get values for each product
      final values = <String?>[];
      for (int i = 0; i < products.length; i++) {
        values.add(attributeData.valuesByProductIndex[i]);
      }

      // Determine if this is a unique attribute (only one product has it)
      final nonNullCount = values.where((v) => v != null).length;
      final isUnique = nonNullCount == 1;
      int? uniqueIndex;
      
      if (isUnique) {
        uniqueIndex = values.indexWhere((v) => v != null);
      }

      // Parse values for comparison
      final parsedValues = values
          .map((v) => v != null ? ParsedValue.parse(v) : null)
          .toList();

      // Determine if numeric comparison is possible
      final nonNullParsed = parsedValues.whereType<ParsedValue>().toList();
      final canCompareNumeric = nonNullParsed.length >= 2 &&
          nonNullParsed.every((v) => v.isNumeric) &&
          _areValuesComparable(nonNullParsed);

      ValueComparison? comparison;
      if (nonNullParsed.isNotEmpty) {
        comparison = ValueComparison(
          attributeName: attributeData.displayName,
          values: nonNullParsed,
          isNumericComparison: canCompareNumeric,
        );
      }

      final row = ComparisonRow(
        attributeName: attributeData.displayName,
        normalizedName: normalizedName,
        values: values,
        comparison: comparison,
        isUnique: isUnique,
        uniqueProductIndex: uniqueIndex,
      );

      if (isUnique) {
        uniqueRows.add(row);
      } else {
        rows.add(row);
      }
    }

    // Sort rows: put important attributes first, then alphabetical
    rows.sort((a, b) => _compareRowPriority(a, b));

    return ProductComparisonResult(
      productSkus: skus,
      productNames: names,
      productImages: images,
      productPrices: prices,
      rows: rows,
      uniqueRows: uniqueRows,
    );
  }

  /// Collect all attributes from all products, normalizing and matching names.
  Map<String, _AttributeData> _collectAttributes(List<BestBuyProduct> products) {
    final attributeMap = <String, _AttributeData>{};

    // First, add built-in attributes
    for (int i = 0; i < products.length; i++) {
      final product = products[i];
      
      _addAttribute(attributeMap, 'Price', 
          product.effectivePrice?.toStringAsFixed(2), i, 'Price');
      _addAttribute(attributeMap, 'Regular Price',
          product.regularPrice?.toStringAsFixed(2), i, 'Regular Price');
      _addAttribute(attributeMap, 'Brand', 
          product.manufacturer, i, 'Brand');
      _addAttribute(attributeMap, 'Model Number', 
          product.modelNumber, i, 'Model');
      _addAttribute(attributeMap, 'Color', 
          product.color, i, 'Color');
      _addAttribute(attributeMap, 'Weight', 
          product.weight, i, 'Weight');
      _addAttribute(attributeMap, 'Height', 
          product.height, i, 'Height');
      _addAttribute(attributeMap, 'Width', 
          product.width, i, 'Width');
      _addAttribute(attributeMap, 'Depth', 
          product.depth, i, 'Depth');
      _addAttribute(attributeMap, 'Rating',
          product.customerReviewAverage?.toStringAsFixed(1), i, 'Rating');
      _addAttribute(attributeMap, 'Review Count',
          product.customerReviewCount?.toString(), i, 'Reviews');
      _addAttribute(attributeMap, 'Condition',
          product.condition, i, 'Condition');
    }

    // Then add product details (variant attributes)
    for (int i = 0; i < products.length; i++) {
      for (final detail in products[i].details) {
        if (detail.name == null || detail.value == null) continue;
        
        final normalizedName = _normalizeAttributeName(detail.name!);
        final displayName = _findBestDisplayName(
          attributeMap, 
          normalizedName, 
          detail.name!,
        );
        
        _addAttribute(attributeMap, normalizedName, detail.value, i, displayName);
      }
    }

    return attributeMap;
  }

  void _addAttribute(
    Map<String, _AttributeData> map,
    String name,
    String? value,
    int productIndex,
    String displayName,
  ) {
    if (value == null || value.isEmpty) return;
    
    final normalized = _normalizeAttributeName(name);
    
    if (!map.containsKey(normalized)) {
      map[normalized] = _AttributeData(displayName: displayName);
    }
    
    map[normalized]!.valuesByProductIndex[productIndex] = value;
  }

  /// Normalize an attribute name for fuzzy matching.
  String _normalizeAttributeName(String name) {
    var normalized = name.toLowerCase().trim();
    
    // Remove common prefixes/suffixes
    normalized = normalized
        .replaceAll(RegExp(r'^product\s+'), '')
        .replaceAll(RegExp(r'\s+size$'), '')
        .replaceAll(RegExp(r'\s+type$'), '')
        .replaceAll(RegExp(r'\s*\(.*?\)\s*'), '') // Remove parenthetical content
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Apply synonym mappings
    normalized = _applySynonyms(normalized);
    
    return normalized;
  }

  /// Apply synonym mappings to normalize similar attribute names.
  String _applySynonyms(String name) {
    // Define groups of synonyms - all map to the first item
    const synonymGroups = <List<String>>[
      ['screen size', 'display size', 'screen diagonal', 'display diagonal', 'panel size'],
      ['resolution', 'display resolution', 'screen resolution', 'native resolution'],
      ['refresh rate', 'refresh frequency', 'screen refresh rate'],
      ['storage', 'storage capacity', 'internal storage', 'memory capacity', 'hard drive capacity', 'ssd capacity', 'hdd capacity'],
      ['ram', 'memory', 'system memory', 'installed ram', 'total memory'],
      ['processor', 'cpu', 'processor model', 'processor type', 'chip'],
      ['graphics', 'gpu', 'graphics card', 'video card', 'graphics processor'],
      ['battery', 'battery capacity', 'battery life', 'battery size'],
      ['weight', 'product weight', 'item weight', 'unit weight'],
      ['height', 'product height', 'item height', 'unit height'],
      ['width', 'product width', 'item width', 'unit width'],
      ['depth', 'product depth', 'item depth', 'unit depth', 'length'],
      ['color', 'colour', 'product color', 'finish'],
      ['brand', 'manufacturer', 'make'],
      ['model', 'model number', 'model name', 'model no'],
      ['warranty', 'warranty period', 'warranty length', 'manufacturer warranty'],
      ['ports', 'connectivity', 'connections', 'i/o ports'],
      ['bluetooth', 'bluetooth version', 'bluetooth connectivity'],
      ['wifi', 'wi-fi', 'wireless', 'wireless connectivity', 'wlan'],
      ['operating system', 'os', 'platform'],
      ['camera', 'camera resolution', 'rear camera', 'main camera'],
      ['front camera', 'selfie camera', 'front facing camera'],
      ['speakers', 'speaker system', 'audio', 'sound system'],
      ['display type', 'panel type', 'screen type', 'display technology'],
      ['aspect ratio', 'screen aspect ratio', 'display aspect ratio'],
      ['contrast ratio', 'contrast', 'dynamic contrast'],
      ['brightness', 'max brightness', 'peak brightness', 'luminance'],
      ['response time', 'pixel response', 'gtg response'],
      ['hdmi', 'hdmi ports', 'hdmi inputs'],
      ['usb', 'usb ports', 'usb connections'],
      ['ethernet', 'lan', 'network port', 'rj45'],
    ];

    for (final group in synonymGroups) {
      if (group.contains(name)) {
        return group.first;
      }
    }
    
    return name;
  }

  /// Find the best display name for an attribute.
  String _findBestDisplayName(
    Map<String, _AttributeData> existingMap,
    String normalizedName,
    String candidateName,
  ) {
    // If we already have this attribute, keep the existing display name
    if (existingMap.containsKey(normalizedName)) {
      return existingMap[normalizedName]!.displayName;
    }
    
    // Otherwise use the candidate, with title case cleanup
    return _toTitleCase(candidateName);
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      // Keep acronyms uppercase
      if (word.toUpperCase() == word && word.length <= 4) return word;
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }

  /// Check if parsed values can be numerically compared.
  bool _areValuesComparable(List<ParsedValue> values) {
    if (values.length < 2) return false;
    
    // Get the unit from the first value that has one
    String? referenceUnit;
    for (final v in values) {
      if (v.unit != null) {
        referenceUnit = v.unit;
        break;
      }
    }
    
    // All values should have the same (or no) unit for comparison
    for (final v in values) {
      if (v.unit != null && referenceUnit != null && v.unit != referenceUnit) {
        // Check if units are convertible
        if (!v.canCompareWith(values.first)) {
          return false;
        }
      }
    }
    
    return true;
  }

  /// Compare row priority for sorting.
  int _compareRowPriority(ComparisonRow a, ComparisonRow b) {
    // Priority order for common attributes
    const priorityOrder = [
      'price',
      'brand',
      'model',
      'screen size',
      'display size',
      'resolution',
      'processor',
      'ram',
      'storage',
      'graphics',
      'battery',
      'weight',
      'color',
      'rating',
      'review count',
    ];
    
    final aIndex = priorityOrder.indexOf(a.normalizedName);
    final bIndex = priorityOrder.indexOf(b.normalizedName);
    
    // Both in priority list
    if (aIndex >= 0 && bIndex >= 0) {
      return aIndex.compareTo(bIndex);
    }
    
    // Only one in priority list - prioritized one comes first
    if (aIndex >= 0) return -1;
    if (bIndex >= 0) return 1;
    
    // Neither in priority list - alphabetical
    return a.attributeName.compareTo(b.attributeName);
  }
}

/// Internal helper class for collecting attribute data.
class _AttributeData {
  final String displayName;
  final Map<int, String> valuesByProductIndex = {};

  _AttributeData({required this.displayName});
}
