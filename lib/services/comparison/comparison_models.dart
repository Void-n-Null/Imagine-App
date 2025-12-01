/// Represents a parsed numeric value with its unit.
/// Used for intelligent comparison of specifications like "27 inches", "256 GB", etc.
class ParsedValue {
  final double? numericValue;
  final String? unit;
  final String originalValue;
  final bool isNumeric;

  const ParsedValue({
    this.numericValue,
    this.unit,
    required this.originalValue,
    required this.isNumeric,
  });

  /// Create from a raw string value.
  /// Attempts to extract numeric value and unit.
  factory ParsedValue.parse(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return ParsedValue(originalValue: value, isNumeric: false);
    }

    // Common patterns for numeric values with units
    // Handles: "27 inches", "256GB", "3.5 lbs", "1920 x 1080", "4K", etc.
    
    // Try to extract a number and unit
    final numericPattern = RegExp(
      r'^([+-]?\d+\.?\d*)\s*([a-zA-Z%°"\x27]+)?$',
      caseSensitive: false,
    );
    
    final match = numericPattern.firstMatch(trimmed);
    if (match != null) {
      final numStr = match.group(1);
      final unit = match.group(2)?.toLowerCase();
      final num = double.tryParse(numStr ?? '');
      
      if (num != null) {
        return ParsedValue(
          numericValue: num,
          unit: _normalizeUnit(unit),
          originalValue: value,
          isNumeric: true,
        );
      }
    }

    // Try extracting first number from more complex strings
    // e.g., "27-inch display" -> 27, "inches"
    final firstNumPattern = RegExp(r'(\d+\.?\d*)[\s-]*([a-zA-Z]+)');
    final firstMatch = firstNumPattern.firstMatch(trimmed);
    if (firstMatch != null) {
      final numStr = firstMatch.group(1);
      final unit = firstMatch.group(2)?.toLowerCase();
      final num = double.tryParse(numStr ?? '');
      
      if (num != null) {
        return ParsedValue(
          numericValue: num,
          unit: _normalizeUnit(unit),
          originalValue: value,
          isNumeric: true,
        );
      }
    }

    return ParsedValue(originalValue: value, isNumeric: false);
  }

  /// Normalize common unit variations.
  static String? _normalizeUnit(String? unit) {
    if (unit == null || unit.isEmpty) return null;
    
    final lower = unit.toLowerCase();
    
    // Length units
    if (lower == 'in' || lower == 'inch' || lower == '"') return 'inches';
    if (lower == 'ft' || lower == 'foot' || lower == "'") return 'feet';
    if (lower == 'cm' || lower == 'centimeter' || lower == 'centimeters') return 'cm';
    if (lower == 'mm' || lower == 'millimeter' || lower == 'millimeters') return 'mm';
    if (lower == 'm' || lower == 'meter' || lower == 'meters') return 'm';
    
    // Weight units
    if (lower == 'lb' || lower == 'lbs' || lower == 'pound' || lower == 'pounds') return 'lbs';
    if (lower == 'oz' || lower == 'ounce' || lower == 'ounces') return 'oz';
    if (lower == 'kg' || lower == 'kilogram' || lower == 'kilograms') return 'kg';
    if (lower == 'g' || lower == 'gram' || lower == 'grams') return 'g';
    
    // Storage units
    if (lower == 'gb' || lower == 'gigabyte' || lower == 'gigabytes') return 'GB';
    if (lower == 'tb' || lower == 'terabyte' || lower == 'terabytes') return 'TB';
    if (lower == 'mb' || lower == 'megabyte' || lower == 'megabytes') return 'MB';
    
    // Frequency units
    if (lower == 'hz' || lower == 'hertz') return 'Hz';
    if (lower == 'ghz' || lower == 'gigahertz') return 'GHz';
    if (lower == 'mhz' || lower == 'megahertz') return 'MHz';
    
    // Power/electrical units
    if (lower == 'w' || lower == 'watt' || lower == 'watts') return 'W';
    if (lower == 'v' || lower == 'volt' || lower == 'volts') return 'V';
    if (lower == 'mah' || lower == 'milliampere' || lower == 'milliamp') return 'mAh';
    
    // Time units
    if (lower == 'hr' || lower == 'hrs' || lower == 'hour' || lower == 'hours') return 'hours';
    if (lower == 'min' || lower == 'mins' || lower == 'minute' || lower == 'minutes') return 'minutes';
    if (lower == 'sec' || lower == 'secs' || lower == 's' || lower == 'second' || lower == 'seconds') return 'seconds';
    if (lower == 'ms' || lower == 'millisecond' || lower == 'milliseconds') return 'ms';
    
    // Percentage
    if (lower == '%' || lower == 'percent' || lower == 'pct') return '%';
    
    return lower;
  }

  /// Check if this value can be compared numerically with another.
  bool canCompareWith(ParsedValue other) {
    if (!isNumeric || !other.isNumeric) return false;
    if (numericValue == null || other.numericValue == null) return false;
    
    // Same unit or both unitless
    if (unit == other.unit) return true;
    
    // One is unitless - assume comparable
    if (unit == null || other.unit == null) return true;
    
    // Check for convertible units
    return _areUnitsConvertible(unit!, other.unit!);
  }

  static bool _areUnitsConvertible(String unit1, String unit2) {
    // Define groups of convertible units
    const lengthUnits = {'inches', 'feet', 'cm', 'mm', 'm'};
    const weightUnits = {'lbs', 'oz', 'kg', 'g'};
    const storageUnits = {'GB', 'TB', 'MB'};
    const frequencyUnits = {'Hz', 'GHz', 'MHz'};
    const timeUnits = {'hours', 'minutes', 'seconds', 'ms'};

    for (final group in [lengthUnits, weightUnits, storageUnits, frequencyUnits, timeUnits]) {
      if (group.contains(unit1) && group.contains(unit2)) {
        return true;
      }
    }
    return false;
  }

  @override
  String toString() => isNumeric 
      ? '$numericValue ${unit ?? ''}' 
      : originalValue;
}

/// Represents the comparison between values across multiple products.
class ValueComparison {
  final String attributeName;
  final List<ParsedValue> values;
  final bool isNumericComparison;
  
  const ValueComparison({
    required this.attributeName,
    required this.values,
    required this.isNumericComparison,
  });

  /// Check if all values are the same.
  bool get allSame {
    if (values.isEmpty) return true;
    if (values.length == 1) return true;
    
    if (isNumericComparison) {
      final firstNum = values.first.numericValue;
      return values.every((v) => v.numericValue == firstNum);
    } else {
      final firstVal = values.first.originalValue.toLowerCase();
      return values.every((v) => v.originalValue.toLowerCase() == firstVal);
    }
  }

  /// Get the numeric difference between two values (for 2-product comparison).
  NumericDifference? get numericDifference {
    if (!isNumericComparison || values.length != 2) return null;
    
    final v1 = values[0].numericValue;
    final v2 = values[1].numericValue;
    
    if (v1 == null || v2 == null) return null;
    
    final absoluteDiff = v2 - v1;
    final percentDiff = v1 != 0 ? ((v2 - v1) / v1.abs()) * 100 : null;
    
    return NumericDifference(
      absoluteDifference: absoluteDiff,
      percentageDifference: percentDiff,
      unit: values[0].unit ?? values[1].unit,
      baseValue: v1,
      compareValue: v2,
    );
  }

  /// Get min/max/range statistics (for 3+ product comparison).
  NumericStats? get numericStats {
    if (!isNumericComparison || values.length < 2) return null;
    
    final numericValues = values
        .where((v) => v.numericValue != null)
        .map((v) => v.numericValue!)
        .toList();
    
    if (numericValues.length < 2) return null;
    
    numericValues.sort();
    
    final min = numericValues.first;
    final max = numericValues.last;
    final range = max - min;
    final avg = numericValues.reduce((a, b) => a + b) / numericValues.length;
    
    // Find indices of min/max products
    final minIndices = <int>[];
    final maxIndices = <int>[];
    
    for (int i = 0; i < values.length; i++) {
      if (values[i].numericValue == min) minIndices.add(i);
      if (values[i].numericValue == max) maxIndices.add(i);
    }
    
    return NumericStats(
      min: min,
      max: max,
      range: range,
      average: avg,
      unit: values.firstWhere((v) => v.unit != null, orElse: () => values.first).unit,
      minProductIndices: minIndices,
      maxProductIndices: maxIndices,
    );
  }
}

/// Represents the numeric difference between two values.
class NumericDifference {
  final double absoluteDifference;
  final double? percentageDifference;
  final String? unit;
  final double baseValue;
  final double compareValue;

  const NumericDifference({
    required this.absoluteDifference,
    this.percentageDifference,
    this.unit,
    required this.baseValue,
    required this.compareValue,
  });

  /// Get a human-readable description of the difference.
  String get description {
    final absStr = _formatNumber(absoluteDifference.abs());
    final unitStr = unit != null ? ' $unit' : '';
    
    String direction;
    if (absoluteDifference > 0) {
      direction = 'larger';
    } else if (absoluteDifference < 0) {
      direction = 'smaller';
    } else {
      return 'Same';
    }
    
    final pctStr = percentageDifference != null 
        ? ' (${_formatNumber(percentageDifference!.abs())}%)'
        : '';
    
    return '$absStr$unitStr $direction$pctStr';
  }

  /// Get a short comparison description.
  String get shortDescription {
    if (absoluteDifference == 0) return '=';
    
    final sign = absoluteDifference > 0 ? '+' : '';
    final absStr = _formatNumber(absoluteDifference);
    final unitStr = unit != null ? ' $unit' : '';
    
    return '$sign$absStr$unitStr';
  }

  static String _formatNumber(double num) {
    if (num == num.roundToDouble()) {
      return num.round().toString();
    }
    return num.toStringAsFixed(1);
  }
}

/// Represents statistics for multi-product numeric comparison.
class NumericStats {
  final double min;
  final double max;
  final double range;
  final double average;
  final String? unit;
  final List<int> minProductIndices;
  final List<int> maxProductIndices;

  const NumericStats({
    required this.min,
    required this.max,
    required this.range,
    required this.average,
    this.unit,
    required this.minProductIndices,
    required this.maxProductIndices,
  });

  /// Get a description of the range.
  String get rangeDescription {
    final unitStr = unit != null ? ' $unit' : '';
    return '${_formatNumber(min)}$unitStr - ${_formatNumber(max)}$unitStr';
  }

  /// Get the spread as percentage of the average.
  double? get spreadPercentage {
    if (average == 0) return null;
    return (range / average) * 100;
  }

  static String _formatNumber(double num) {
    if (num == num.roundToDouble()) {
      return num.round().toString();
    }
    return num.toStringAsFixed(1);
  }
}

/// Represents a row in the comparison table.
class ComparisonRow {
  final String attributeName;
  final String normalizedName;
  final List<String?> values; // null means attribute doesn't exist for that product
  final ValueComparison? comparison;
  final bool isUnique; // Only one product has this attribute
  final int? uniqueProductIndex;

  const ComparisonRow({
    required this.attributeName,
    required this.normalizedName,
    required this.values,
    this.comparison,
    this.isUnique = false,
    this.uniqueProductIndex,
  });

  /// Check if this row has comparable numeric values.
  bool get hasNumericComparison => comparison?.isNumericComparison ?? false;

  /// Check if all non-null values are the same.
  bool get allValuesSame {
    final nonNullValues = values.whereType<String>().toList();
    if (nonNullValues.length <= 1) return true;
    return nonNullValues.every((v) => v == nonNullValues.first);
  }
}

/// The complete comparison result for multiple products.
class ProductComparisonResult {
  final List<int> productSkus;
  final List<String> productNames;
  final List<String?> productImages;
  final List<double?> productPrices;
  final List<ComparisonRow> rows;
  final List<ComparisonRow> uniqueRows; // Attributes unique to one product

  const ProductComparisonResult({
    required this.productSkus,
    required this.productNames,
    required this.productImages,
    required this.productPrices,
    required this.rows,
    required this.uniqueRows,
  });

  /// Number of products being compared.
  int get productCount => productSkus.length;

  /// Check if this is a simple two-product comparison.
  bool get isTwoProductComparison => productCount == 2;

  /// Get rows with differences (for highlighting).
  List<ComparisonRow> get rowsWithDifferences =>
      rows.where((r) => !r.allValuesSame).toList();

  /// Get rows with numeric comparisons.
  List<ComparisonRow> get numericRows =>
      rows.where((r) => r.hasNumericComparison).toList();

  /// Find the best product for a given attribute (highest numeric value).
  int? getBestProductForAttribute(String attributeName, {bool higherIsBetter = true}) {
    final row = rows.firstWhere(
      (r) => r.normalizedName == attributeName.toLowerCase(),
      orElse: () => rows.first,
    );
    
    if (row.comparison == null || !row.comparison!.isNumericComparison) {
      return null;
    }
    
    if (isTwoProductComparison) {
      final diff = row.comparison!.numericDifference;
      if (diff == null) return null;
      
      if (higherIsBetter) {
        return diff.absoluteDifference >= 0 ? 1 : 0;
      } else {
        return diff.absoluteDifference <= 0 ? 1 : 0;
      }
    } else {
      final stats = row.comparison!.numericStats;
      if (stats == null) return null;
      
      if (higherIsBetter) {
        return stats.maxProductIndices.isNotEmpty ? stats.maxProductIndices.first : null;
      } else {
        return stats.minProductIndices.isNotEmpty ? stats.minProductIndices.first : null;
      }
    }
  }
}
