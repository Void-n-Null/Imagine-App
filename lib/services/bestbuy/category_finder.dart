import 'dart:math' as math;

import 'bestbuy_client.dart';
import 'models/category.dart';

/// A category entry with ID and display name.
class CategoryEntry {
  final String id;
  final String name;
  final String? parentName;
  final List<String> keywords;

  const CategoryEntry({
    required this.id,
    required this.name,
    this.parentName,
    this.keywords = const [],
  });

  /// Full display name including parent if available.
  String get displayName => parentName != null ? '$parentName > $name' : name;

  @override
  String toString() => 'CategoryEntry($id: $displayName)';
}

/// Result of a category search with match confidence.
class CategoryMatch {
  final CategoryEntry category;
  final double score;
  final bool isExactMatch;

  const CategoryMatch({
    required this.category,
    required this.score,
    this.isExactMatch = false,
  });

  @override
  String toString() =>
      'CategoryMatch(${category.name}, score: ${score.toStringAsFixed(2)}, exact: $isExactMatch)';
}

/// Service for finding Best Buy categories by name with fuzzy matching.
///
/// Maintains a hardcoded list of important categories for fast lookup,
/// with optional API fallback for unknown categories.
class CategoryFinder {
  final BestBuyClient? _client;
  final Map<String, BestBuyCategory> _apiCache = {};

  CategoryFinder({BestBuyClient? client}) : _client = client;

  // ─────────────────────────────────────────────────────────────────────────
  // Hardcoded Categories
  // ─────────────────────────────────────────────────────────────────────────

  /// Top-level categories.
  static const List<CategoryEntry> topLevelCategories = [
    CategoryEntry(
      id: 'abcat0100000',
      name: 'TV & Home Theater',
      keywords: ['tv', 'television', 'home theater', 'entertainment'],
    ),
    CategoryEntry(
      id: 'abcat0200000',
      name: 'Home Audio & Speakers',
      keywords: ['audio', 'speakers', 'stereo', 'sound system'],
    ),
    CategoryEntry(
      id: 'abcat0204000',
      name: 'Headphones',
      keywords: ['headphones', 'earbuds', 'earphones', 'audio'],
    ),
    CategoryEntry(
      id: 'abcat0207000',
      name: 'Musical Instruments',
      keywords: ['music', 'instruments', 'guitar', 'piano', 'drums'],
    ),
    CategoryEntry(
      id: 'abcat0300000',
      name: 'Car Electronics & GPS',
      keywords: ['car', 'auto', 'gps', 'navigation', 'dash cam'],
    ),
    CategoryEntry(
      id: 'abcat0400000',
      name: 'Cameras, Camcorders & Drones',
      keywords: ['camera', 'photo', 'video', 'drone', 'camcorder', 'photography'],
    ),
    CategoryEntry(
      id: 'abcat0500000',
      name: 'Computers & Tablets',
      keywords: ['computer', 'pc', 'laptop', 'tablet', 'ipad'],
    ),
    CategoryEntry(
      id: 'abcat0600000',
      name: 'Music, Movies & TV Shows',
      keywords: ['music', 'movies', 'dvd', 'blu-ray', 'vinyl', 'cd'],
    ),
    CategoryEntry(
      id: 'abcat0700000',
      name: 'Video Games',
      keywords: ['games', 'gaming', 'xbox', 'playstation', 'nintendo', 'switch', 'ps5'],
    ),
    CategoryEntry(
      id: 'abcat0800000',
      name: 'Cell Phones',
      keywords: ['phone', 'cell', 'mobile', 'iphone', 'android', 'smartphone'],
    ),
    CategoryEntry(
      id: 'abcat0900000',
      name: 'Appliances',
      keywords: ['appliance', 'refrigerator', 'washer', 'dryer', 'kitchen'],
    ),
    CategoryEntry(
      id: 'pcmcat1528819595254',
      name: 'Services',
      keywords: ['service', 'geek squad', 'installation', 'repair'],
    ),
  ];

  /// Computer-related subcategories.
  static const List<CategoryEntry> computerCategories = [
    CategoryEntry(
      id: 'abcat0502000',
      name: 'Laptops',
      parentName: 'Computers & Tablets',
      keywords: ['laptop', 'notebook', 'macbook', 'chromebook', 'portable'],
    ),
    CategoryEntry(
      id: 'abcat0501000',
      name: 'Desktop & All-in-One Computers',
      parentName: 'Computers & Tablets',
      keywords: ['desktop', 'pc', 'imac', 'all-in-one', 'tower'],
    ),
    CategoryEntry(
      id: 'pcmcat209000050006',
      name: 'Tablets',
      parentName: 'Computers & Tablets',
      keywords: ['tablet', 'ipad', 'android tablet', 'surface'],
    ),
    CategoryEntry(
      id: 'abcat0507000',
      name: 'Computer Cards & Components',
      parentName: 'Computers & Tablets',
      keywords: ['components', 'gpu', 'cpu', 'motherboard', 'ram', 'pc parts'],
    ),
    CategoryEntry(
      id: 'abcat0504000',
      name: 'Hard Drives & Storage',
      parentName: 'Computers & Tablets',
      keywords: ['storage', 'hard drive', 'ssd', 'hdd', 'external drive'],
    ),
    CategoryEntry(
      id: 'abcat0509000',
      name: 'Monitors',
      parentName: 'Computers & Tablets',
      keywords: ['monitor', 'display', 'screen', 'computer monitor'],
    ),
    CategoryEntry(
      id: 'abcat0503000',
      name: 'Wi-Fi & Networking',
      parentName: 'Computers & Tablets',
      keywords: ['wifi', 'router', 'modem', 'networking', 'mesh', 'ethernet'],
    ),
    CategoryEntry(
      id: 'abcat0515000',
      name: 'Computer Accessories & Peripherals',
      parentName: 'Computers & Tablets',
      keywords: ['accessories', 'peripherals', 'computer accessories'],
    ),
    CategoryEntry(
      id: 'abcat0513000',
      name: 'Mice & Keyboards',
      parentName: 'Computer Accessories',
      keywords: ['mouse', 'keyboard', 'mice', 'mechanical keyboard'],
    ),
    CategoryEntry(
      id: 'abcat0515046',
      name: 'Webcams',
      parentName: 'Computer Accessories',
      keywords: ['webcam', 'web camera', 'streaming camera'],
    ),
    CategoryEntry(
      id: 'abcat0511001',
      name: 'Printers, Ink & Toner',
      parentName: 'Computer Accessories',
      keywords: ['printer', 'ink', 'toner', 'printing'],
    ),
  ];

  /// Cable and connector categories.
  static const List<CategoryEntry> cableCategories = [
    CategoryEntry(
      id: 'abcat0515012',
      name: 'Cables & Connectors',
      parentName: 'Computer Accessories',
      keywords: ['cable', 'connector', 'cord', 'wire', 'cables'],
    ),
    // Note: abcat0515013 is the correct category for USB cables (abcat0515018 is empty/deprecated)
    CategoryEntry(
      id: 'abcat0515013',
      name: 'USB Cables & Adapters',
      parentName: 'Cables & Connectors',
      keywords: ['usb', 'usb cable', 'usb cables', 'usb adapter', 'usb-c', 'usb c', 'type-c', 'type c', 'micro usb', 'lightning', 'charging cable', 'data cable'],
    ),
    CategoryEntry(
      id: 'abcat0515016',
      name: 'Ethernet Cables',
      parentName: 'Cables & Connectors',
      keywords: ['ethernet', 'network cable', 'cat5', 'cat6', 'lan cable'],
    ),
    CategoryEntry(
      id: 'pcmcat138100050035',
      name: 'Monitor & Video Cables',
      parentName: 'Cables & Connectors',
      keywords: ['video cable', 'display cable', 'displayport', 'vga', 'dvi'],
    ),
    CategoryEntry(
      id: 'pcmcat138100050040',
      name: 'Power Cables',
      parentName: 'Cables & Connectors',
      keywords: ['power cable', 'power cord', 'ac adapter'],
    ),
    CategoryEntry(
      id: 'pcmcat1584032708792',
      name: 'USB Hubs',
      parentName: 'Cables & Connectors',
      keywords: ['usb hub', 'port hub', 'usb splitter'],
    ),
    CategoryEntry(
      id: 'abcat0107015',
      name: 'A/V Cables & Connectors',
      parentName: 'TV & Home Theater Accessories',
      keywords: ['av cable', 'audio video', 'rca', 'component'],
    ),
    CategoryEntry(
      id: 'abcat0107020',
      name: 'HDMI Cables',
      parentName: 'A/V Cables & Connectors',
      keywords: ['hdmi', 'hdmi cable', 'hdmi cord', 'high speed hdmi'],
    ),
  ];

  /// Cell phone categories.
  static const List<CategoryEntry> cellPhoneCategories = [
    CategoryEntry(
      id: 'abcat0811002',
      name: 'Cell Phone Accessories',
      parentName: 'Cell Phones',
      keywords: ['phone accessories', 'mobile accessories', 'cell accessories'],
    ),
    CategoryEntry(
      id: 'abcat0811004',
      name: 'Cell Phone Chargers & Cables',
      parentName: 'Cell Phone Accessories',
      keywords: ['phone charger', 'charging cable', 'lightning cable', 'phone cable'],
    ),
    CategoryEntry(
      id: 'abcat0811006',
      name: 'Cell Phone Cases',
      parentName: 'Cell Phone Accessories',
      keywords: ['phone case', 'case', 'cover', 'protective case'],
    ),
    CategoryEntry(
      id: 'pcmcat171900050031',
      name: 'Cell Phone Screen Protectors',
      parentName: 'Cell Phone Accessories',
      keywords: ['screen protector', 'tempered glass', 'screen guard'],
    ),
    CategoryEntry(
      id: 'pcmcat191200050015',
      name: 'iPhone Accessories',
      parentName: 'Cell Phone Accessories',
      keywords: ['iphone', 'apple accessories', 'ios accessories'],
    ),
    CategoryEntry(
      id: 'pcmcat305200050007',
      name: 'Samsung Galaxy Accessories',
      parentName: 'Cell Phone Accessories',
      keywords: ['samsung', 'galaxy', 'android accessories'],
    ),
    CategoryEntry(
      id: 'pcmcat156400050037',
      name: 'Unlocked Cell Phones',
      parentName: 'Cell Phones',
      keywords: ['unlocked', 'unlocked phone', 'no contract'],
    ),
    CategoryEntry(
      id: 'pcmcat305200050000',
      name: 'iPhone',
      parentName: 'Cell Phones',
      keywords: ['iphone', 'apple phone', 'ios'],
    ),
    CategoryEntry(
      id: 'pcmcat305200050001',
      name: 'Samsung Galaxy',
      parentName: 'Cell Phones',
      keywords: ['samsung', 'galaxy', 'android phone'],
    ),
    CategoryEntry(
      id: 'pcmcat321000050003',
      name: 'Smartwatches & Accessories',
      parentName: 'Cell Phone Accessories',
      keywords: ['smartwatch', 'apple watch', 'fitness tracker', 'wearable'],
    ),
  ];

  /// TV and home theater categories.
  static const List<CategoryEntry> tvCategories = [
    CategoryEntry(
      id: 'abcat0101000',
      name: 'TVs',
      parentName: 'TV & Home Theater',
      keywords: ['tv', 'television', 'smart tv', 'oled', 'qled', '4k tv'],
    ),
    CategoryEntry(
      id: 'abcat0205007',
      name: 'Sound Bars',
      parentName: 'TV & Home Theater',
      keywords: ['soundbar', 'sound bar', 'tv speaker', 'home audio'],
    ),
    CategoryEntry(
      id: 'abcat0203000',
      name: 'Home Theater & Stereo Systems',
      parentName: 'TV & Home Theater',
      keywords: ['home theater', 'stereo', 'surround sound', 'receiver'],
    ),
    CategoryEntry(
      id: 'pcmcat161100050040',
      name: 'Streaming Devices',
      parentName: 'TV & Home Theater',
      keywords: ['streaming', 'roku', 'fire tv', 'chromecast', 'apple tv'],
    ),
    CategoryEntry(
      id: 'abcat0107000',
      name: 'TV & Home Theater Accessories',
      parentName: 'TV & Home Theater',
      keywords: ['tv accessories', 'home theater accessories'],
    ),
    CategoryEntry(
      id: 'abcat0106000',
      name: 'TV Stands, Mounts & Furniture',
      parentName: 'TV & Home Theater',
      keywords: ['tv stand', 'tv mount', 'wall mount', 'entertainment center'],
    ),
    CategoryEntry(
      id: 'pcmcat158900050008',
      name: 'Projectors & Screens',
      parentName: 'TV & Home Theater',
      keywords: ['projector', 'projection', 'screen', 'home cinema'],
    ),
  ];

  /// Gaming categories.
  static const List<CategoryEntry> gamingCategories = [
    CategoryEntry(
      id: 'abcat0712000',
      name: 'PC Gaming',
      parentName: 'Video Games',
      keywords: ['pc gaming', 'gaming pc', 'computer games'],
    ),
    CategoryEntry(
      id: 'abcat0701000',
      name: 'PlayStation',
      parentName: 'Video Games',
      keywords: ['playstation', 'ps5', 'ps4', 'sony', 'psn'],
    ),
    CategoryEntry(
      id: 'abcat0707000',
      name: 'Xbox',
      parentName: 'Video Games',
      keywords: ['xbox', 'xbox series x', 'xbox one', 'microsoft'],
    ),
    CategoryEntry(
      id: 'abcat0703000',
      name: 'Nintendo',
      parentName: 'Video Games',
      keywords: ['nintendo', 'switch', 'mario', 'zelda'],
    ),
    CategoryEntry(
      id: 'abcat0715000',
      name: 'Video Game Accessories',
      parentName: 'Video Games',
      keywords: ['gaming accessories', 'controller', 'headset'],
    ),
  ];

  /// Camera and drone categories.
  static const List<CategoryEntry> cameraCategories = [
    CategoryEntry(
      id: 'abcat0401000',
      name: 'Digital Cameras',
      parentName: 'Cameras, Camcorders & Drones',
      keywords: ['camera', 'digital camera', 'dslr', 'mirrorless'],
    ),
    CategoryEntry(
      id: 'pcmcat242800050021',
      name: 'Drones',
      parentName: 'Cameras, Camcorders & Drones',
      keywords: ['drone', 'quadcopter', 'dji', 'aerial'],
    ),
    CategoryEntry(
      id: 'abcat0410000',
      name: 'Digital Camera Accessories',
      parentName: 'Cameras, Camcorders & Drones',
      keywords: ['camera accessories', 'lens', 'tripod', 'camera bag'],
    ),
    CategoryEntry(
      id: 'abcat0402000',
      name: 'Camcorders',
      parentName: 'Cameras, Camcorders & Drones',
      keywords: ['camcorder', 'video camera', 'action camera', 'gopro'],
    ),
  ];

  /// Appliance categories.
  static const List<CategoryEntry> applianceCategories = [
    CategoryEntry(
      id: 'abcat0901000',
      name: 'Refrigerators',
      parentName: 'Appliances',
      keywords: ['refrigerator', 'fridge', 'freezer'],
    ),
    CategoryEntry(
      id: 'abcat0912000',
      name: 'Washers & Dryers',
      parentName: 'Appliances',
      keywords: ['washer', 'dryer', 'laundry', 'washing machine'],
    ),
    CategoryEntry(
      id: 'abcat0904000',
      name: 'Ranges, Cooktops & Ovens',
      parentName: 'Appliances',
      keywords: ['range', 'oven', 'stove', 'cooktop'],
    ),
    CategoryEntry(
      id: 'abcat0905000',
      name: 'Dishwashers',
      parentName: 'Appliances',
      keywords: ['dishwasher'],
    ),
    CategoryEntry(
      id: 'abcat0910000',
      name: 'Small Kitchen Appliances',
      parentName: 'Appliances',
      keywords: ['small appliance', 'blender', 'coffee maker', 'toaster', 'air fryer'],
    ),
    CategoryEntry(
      id: 'abcat0908000',
      name: 'Vacuums & Floor Care',
      parentName: 'Appliances',
      keywords: ['vacuum', 'floor care', 'roomba', 'robot vacuum'],
    ),
  ];

  /// Smart home categories.
  static const List<CategoryEntry> smartHomeCategories = [
    CategoryEntry(
      id: 'pcmcat254000050002',
      name: 'Smart Home',
      keywords: ['smart home', 'home automation', 'connected home'],
    ),
    CategoryEntry(
      id: 'pcmcat748302046861',
      name: 'Smart Speakers & Displays',
      parentName: 'Smart Home',
      keywords: ['smart speaker', 'alexa', 'echo', 'google home', 'homepod'],
    ),
    CategoryEntry(
      id: 'pcmcat254000050003',
      name: 'Smart Lighting',
      parentName: 'Smart Home',
      keywords: ['smart light', 'philips hue', 'smart bulb', 'led'],
    ),
    CategoryEntry(
      id: 'pcmcat254700050006',
      name: 'Smart Thermostats',
      parentName: 'Smart Home',
      keywords: ['thermostat', 'nest', 'ecobee', 'smart thermostat'],
    ),
    CategoryEntry(
      id: 'pcmcat254900050006',
      name: 'Smart Doorbells & Locks',
      parentName: 'Smart Home',
      keywords: ['doorbell', 'ring', 'smart lock', 'security'],
    ),
  ];

  /// All hardcoded categories combined.
  static List<CategoryEntry> get allCategories => [
        ...topLevelCategories,
        ...computerCategories,
        ...cableCategories,
        ...cellPhoneCategories,
        ...tvCategories,
        ...gamingCategories,
        ...cameraCategories,
        ...applianceCategories,
        ...smartHomeCategories,
      ];

  /// Categories suitable for display in a picker (top-level + important subs).
  static List<CategoryEntry> get pickerCategories => [
        ...topLevelCategories,
        // Add most commonly used subcategories
        const CategoryEntry(id: 'abcat0502000', name: 'Laptops', parentName: 'Computers & Tablets'),
        const CategoryEntry(id: 'abcat0501000', name: 'Desktops', parentName: 'Computers & Tablets'),
        const CategoryEntry(id: 'pcmcat209000050006', name: 'Tablets', parentName: 'Computers & Tablets'),
        const CategoryEntry(id: 'abcat0515000', name: 'Computer Accessories', parentName: 'Computers & Tablets'),
        const CategoryEntry(id: 'abcat0515012', name: 'Cables & Connectors', parentName: 'Computer Accessories'),
        const CategoryEntry(id: 'abcat0515013', name: 'USB Cables & Adapters', parentName: 'Cables & Connectors'),
        const CategoryEntry(id: 'abcat0101000', name: 'TVs', parentName: 'TV & Home Theater'),
        const CategoryEntry(id: 'abcat0205007', name: 'Sound Bars', parentName: 'TV & Home Theater'),
        const CategoryEntry(id: 'pcmcat161100050040', name: 'Streaming Devices', parentName: 'TV & Home Theater'),
        const CategoryEntry(id: 'abcat0811002', name: 'Cell Phone Accessories', parentName: 'Cell Phones'),
        const CategoryEntry(id: 'pcmcat156400050037', name: 'Unlocked Phones', parentName: 'Cell Phones'),
        const CategoryEntry(id: 'pcmcat321000050003', name: 'Smartwatches', parentName: 'Cell Phone Accessories'),
      ];

  // ─────────────────────────────────────────────────────────────────────────
  // Category Lookup Methods
  // ─────────────────────────────────────────────────────────────────────────

  /// Finds the best matching category for the given query.
  ///
  /// Returns null if no good match is found (score below threshold).
  CategoryMatch? findCategory(String query, {double threshold = 0.3}) {
    if (query.trim().isEmpty) return null;

    final normalizedQuery = _normalize(query);
    final matches = <CategoryMatch>[];

    for (final category in allCategories) {
      final score = _calculateMatchScore(normalizedQuery, category);
      if (score > 0) {
        matches.add(CategoryMatch(
          category: category,
          score: score,
          isExactMatch: score >= 1.0,
        ));
      }
    }

    if (matches.isEmpty) return null;

    // Sort by score descending
    matches.sort((a, b) => b.score.compareTo(a.score));

    final best = matches.first;
    return best.score >= threshold ? best : null;
  }

  /// Finds all categories matching the query, sorted by relevance.
  List<CategoryMatch> findCategories(String query, {int limit = 10, double threshold = 0.2}) {
    if (query.trim().isEmpty) return [];

    final normalizedQuery = _normalize(query);
    final matches = <CategoryMatch>[];

    for (final category in allCategories) {
      final score = _calculateMatchScore(normalizedQuery, category);
      if (score >= threshold) {
        matches.add(CategoryMatch(
          category: category,
          score: score,
          isExactMatch: score >= 1.0,
        ));
      }
    }

    // Sort by score descending
    matches.sort((a, b) => b.score.compareTo(a.score));

    return matches.take(limit).toList();
  }

  /// Gets a category by its exact ID.
  CategoryEntry? getCategoryById(String id) {
    for (final category in allCategories) {
      if (category.id == id) return category;
    }
    return null;
  }

  /// Suggests a category based on product search terms.
  ///
  /// This is useful for automatically suggesting a category filter
  /// based on what the user is searching for.
  CategoryMatch? suggestCategoryForSearch(String searchQuery) {
    // Try to find a category that matches the search terms
    final match = findCategory(searchQuery, threshold: 0.4);
    if (match != null) return match;

    // Try individual words
    final words = searchQuery.toLowerCase().split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.length < 3) continue;
      final wordMatch = findCategory(word, threshold: 0.5);
      if (wordMatch != null) return wordMatch;
    }

    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // API Lookup (Fallback)
  // ─────────────────────────────────────────────────────────────────────────

  /// Searches for categories via the API.
  ///
  /// This is a fallback when the hardcoded categories don't have a match.
  /// Results are cached to avoid repeated API calls.
  Future<List<BestBuyCategory>> searchCategoriesApi(String query) async {
    if (_client == null) return [];

    // Check cache first
    final cacheKey = _normalize(query);
    if (_apiCache.containsKey(cacheKey)) {
      return [_apiCache[cacheKey]!];
    }

    try {
      final response = await _client!.getCategories(pageSize: 20);
      final matches = <BestBuyCategory>[];

      for (final category in response.categories) {
        if (category.name.toLowerCase().contains(query.toLowerCase())) {
          matches.add(category);
          _apiCache[_normalize(category.name)] = category;
        }
      }

      return matches;
    } catch (e) {
      // Silently fail - API lookup is optional
      return [];
    }
  }

  /// Gets a category by ID from the API.
  Future<BestBuyCategory?> getCategoryByIdApi(String categoryId) async {
    if (_client == null) return null;

    // Check cache
    for (final cached in _apiCache.values) {
      if (cached.id == categoryId) return cached;
    }

    try {
      final category = await _client!.getCategoryById(categoryId);
      if (category != null) {
        _apiCache[_normalize(category.name)] = category;
      }
      return category;
    } catch (e) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Scoring Algorithm
  // ─────────────────────────────────────────────────────────────────────────

  /// Calculates a match score between a query and a category.
  ///
  /// Returns a score from 0.0 (no match) to 1.0+ (exact match).
  double _calculateMatchScore(String query, CategoryEntry category) {
    double score = 0.0;

    final categoryName = _normalize(category.name);
    final categoryKeywords = category.keywords.map(_normalize).toList();

    // Exact name match
    if (query == categoryName) {
      return 1.0;
    }

    // Name contains query
    if (categoryName.contains(query)) {
      score = math.max(score, 0.8);
    }

    // Query contains category name
    if (query.contains(categoryName)) {
      score = math.max(score, 0.7);
    }

    // Keyword exact match
    if (categoryKeywords.contains(query)) {
      score = math.max(score, 0.9);
    }

    // Keyword partial match
    for (final keyword in categoryKeywords) {
      if (keyword.contains(query) || query.contains(keyword)) {
        score = math.max(score, 0.6);
      }
    }

    // Word overlap scoring
    final queryWords = query.split(RegExp(r'\s+'));
    final categoryWords = categoryName.split(RegExp(r'\s+'));
    final allCategoryWords = [...categoryWords, ...categoryKeywords];

    int matchingWords = 0;
    for (final qWord in queryWords) {
      if (qWord.length < 2) continue;
      for (final cWord in allCategoryWords) {
        if (cWord.contains(qWord) || qWord.contains(cWord)) {
          matchingWords++;
          break;
        }
      }
    }

    if (queryWords.isNotEmpty) {
      final wordScore = matchingWords / queryWords.length * 0.5;
      score = math.max(score, wordScore);
    }

    // Fuzzy string similarity (Levenshtein-based)
    final similarity = _stringSimilarity(query, categoryName);
    if (similarity > 0.7) {
      score = math.max(score, similarity * 0.6);
    }

    return score;
  }

  /// Normalizes a string for comparison.
  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Calculates string similarity using a simplified approach.
  ///
  /// Returns a value from 0.0 (completely different) to 1.0 (identical).
  double _stringSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a == b) return 1.0;

    final longer = a.length > b.length ? a : b;
    final shorter = a.length > b.length ? b : a;

    if (longer.length == 0) return 1.0;

    final distance = _levenshteinDistance(longer, shorter);
    return (longer.length - distance) / longer.length;
  }

  /// Calculates Levenshtein distance between two strings.
  int _levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> previousRow = List<int>.generate(b.length + 1, (i) => i);
    List<int> currentRow = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      currentRow[0] = i + 1;

      for (int j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        currentRow[j + 1] = [
          currentRow[j] + 1,
          previousRow[j + 1] + 1,
          previousRow[j] + cost,
        ].reduce(math.min);
      }

      final temp = previousRow;
      previousRow = currentRow;
      currentRow = temp;
    }

    return previousRow[b.length];
  }
}

