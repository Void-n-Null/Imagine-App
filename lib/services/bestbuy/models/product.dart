/// Represents a product from the Best Buy Products API.
///
/// Contains comprehensive product information including pricing, availability,
/// media assets, specifications, and customer reviews.
class BestBuyProduct {
  // Core identifiers
  final int sku;
  final String? upc;
  final String name;
  final String? type;
  final String? modelNumber;
  final String? manufacturer;
  final String? url;
  final String? addToCartUrl;
  final String? mobileUrl;

  // Pricing
  final double? regularPrice;
  final double? salePrice;
  final bool? onSale;
  final double? percentSavings;
  final double? dollarSavings;
  final String? priceRestriction;
  final String? priceUpdateDate;

  // Availability
  final bool? inStoreAvailability;
  final String? inStoreAvailabilityText;
  final String? inStoreAvailabilityUpdateDate;
  final bool? onlineAvailability;
  final String? onlineAvailabilityText;
  final String? onlineAvailabilityUpdateDate;
  final String? orderable;
  final bool? freeShipping;
  final String? shippingCost;
  final String? releaseDate;

  // Media
  final String? image;
  final String? thumbnailImage;
  final String? mediumImage;
  final String? largeFrontImage;
  final String? largeImage;
  final String? angleImage;
  final String? backViewImage;
  final String? leftViewImage;
  final String? rightViewImage;
  final String? topViewImage;
  final String? alternateViewsImage;
  final List<ProductImage> images;

  // Description & details
  final String? longDescription;
  final String? shortDescription;
  final String? longDescriptionHtml;
  final String? plot;
  final List<String> features;
  final List<String> includedItemList;
  final String? condition;

  // Categories & classification
  final List<CategoryPath> categoryPath;
  final String? productClass;
  final String? classId;
  final String? subclass;
  final String? subclassId;
  final String? department;
  final String? departmentId;

  // Reviews & ratings
  final double? customerReviewAverage;
  final int? customerReviewCount;

  // Physical specifications
  final String? weight;
  final String? shippingWeight;
  final String? height;
  final String? width;
  final String? depth;
  final String? color;

  // Status & flags
  final bool? active;
  final bool? activeUpdateDate;
  final bool? new_;
  final bool? preowned;
  final bool? refurbished;
  final bool? digital;
  final bool? marketplace;
  final bool? bestBuyOnly;
  final bool? quantityLimit;

  // Shipping & fulfillment
  final bool? homeDelivery;
  final bool? storePickup;
  final bool? friendsAndFamilyPickup;

  // Offers
  final List<Offer> offers;

  // Details (variant attributes)
  final List<ProductDetail> details;

  BestBuyProduct({
    required this.sku,
    this.upc,
    required this.name,
    this.type,
    this.modelNumber,
    this.manufacturer,
    this.url,
    this.addToCartUrl,
    this.mobileUrl,
    this.regularPrice,
    this.salePrice,
    this.onSale,
    this.percentSavings,
    this.dollarSavings,
    this.priceRestriction,
    this.priceUpdateDate,
    this.inStoreAvailability,
    this.inStoreAvailabilityText,
    this.inStoreAvailabilityUpdateDate,
    this.onlineAvailability,
    this.onlineAvailabilityText,
    this.onlineAvailabilityUpdateDate,
    this.orderable,
    this.freeShipping,
    this.shippingCost,
    this.releaseDate,
    this.image,
    this.thumbnailImage,
    this.mediumImage,
    this.largeFrontImage,
    this.largeImage,
    this.angleImage,
    this.backViewImage,
    this.leftViewImage,
    this.rightViewImage,
    this.topViewImage,
    this.alternateViewsImage,
    this.images = const [],
    this.longDescription,
    this.shortDescription,
    this.longDescriptionHtml,
    this.plot,
    this.features = const [],
    this.includedItemList = const [],
    this.condition,
    this.categoryPath = const [],
    this.productClass,
    this.classId,
    this.subclass,
    this.subclassId,
    this.department,
    this.departmentId,
    this.customerReviewAverage,
    this.customerReviewCount,
    this.weight,
    this.shippingWeight,
    this.height,
    this.width,
    this.depth,
    this.color,
    this.active,
    this.activeUpdateDate,
    this.new_,
    this.preowned,
    this.refurbished,
    this.digital,
    this.marketplace,
    this.bestBuyOnly,
    this.quantityLimit,
    this.homeDelivery,
    this.storePickup,
    this.friendsAndFamilyPickup,
    this.offers = const [],
    this.details = const [],
  });

  factory BestBuyProduct.fromJson(Map<String, dynamic> json) {
    return BestBuyProduct(
      sku: _parseInt(json['sku']) ?? 0,
      upc: json['upc'] as String?,
      name: json['name'] as String? ?? '',
      type: json['type'] as String?,
      modelNumber: json['modelNumber'] as String?,
      manufacturer: json['manufacturer'] as String?,
      url: json['url'] as String?,
      addToCartUrl: json['addToCartUrl'] as String?,
      mobileUrl: json['mobileUrl'] as String?,
      regularPrice: _parseDouble(json['regularPrice']),
      salePrice: _parseDouble(json['salePrice']),
      onSale: json['onSale'] as bool?,
      percentSavings: _parseDouble(json['percentSavings']),
      dollarSavings: _parseDouble(json['dollarSavings']),
      priceRestriction: json['priceRestriction'] as String?,
      priceUpdateDate: json['priceUpdateDate'] as String?,
      inStoreAvailability: json['inStoreAvailability'] as bool?,
      inStoreAvailabilityText: json['inStoreAvailabilityText'] as String?,
      inStoreAvailabilityUpdateDate:
          json['inStoreAvailabilityUpdateDate'] as String?,
      onlineAvailability: json['onlineAvailability'] as bool?,
      onlineAvailabilityText: json['onlineAvailabilityText'] as String?,
      onlineAvailabilityUpdateDate:
          json['onlineAvailabilityUpdateDate'] as String?,
      orderable: json['orderable'] as String?,
      freeShipping: json['freeShipping'] as bool?,
      shippingCost: json['shippingCost']?.toString(),
      releaseDate: json['releaseDate'] as String?,
      image: json['image'] as String?,
      thumbnailImage: json['thumbnailImage'] as String?,
      mediumImage: json['mediumImage'] as String?,
      largeFrontImage: json['largeFrontImage'] as String?,
      largeImage: json['largeImage'] as String?,
      angleImage: json['angleImage'] as String?,
      backViewImage: json['backViewImage'] as String?,
      leftViewImage: json['leftViewImage'] as String?,
      rightViewImage: json['rightViewImage'] as String?,
      topViewImage: json['topViewImage'] as String?,
      alternateViewsImage: json['alternateViewsImage'] as String?,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => ProductImage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      longDescription: json['longDescription'] as String?,
      shortDescription: json['shortDescription'] as String?,
      longDescriptionHtml: json['longDescriptionHtml'] as String?,
      plot: json['plot'] as String?,
      features: (json['features'] as List<dynamic>?)
              ?.map((e) => (e as Map<String, dynamic>)['feature'] as String)
              .whereType<String>()
              .toList() ??
          const [],
      includedItemList: (json['includedItemList'] as List<dynamic>?)
              ?.map((e) =>
                  (e as Map<String, dynamic>)['includedItem'] as String?)
              .whereType<String>()
              .toList() ??
          const [],
      condition: json['condition'] as String?,
      categoryPath: (json['categoryPath'] as List<dynamic>?)
              ?.map((e) => CategoryPath.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      productClass: json['class'] as String?,
      classId: json['classId']?.toString(),
      subclass: json['subclass'] as String?,
      subclassId: json['subclassId']?.toString(),
      department: json['department'] as String?,
      departmentId: json['departmentId']?.toString(),
      customerReviewAverage: _parseDouble(json['customerReviewAverage']),
      customerReviewCount: _parseInt(json['customerReviewCount']),
      weight: json['weight'] as String?,
      shippingWeight: json['shippingWeight'] as String?,
      height: json['height'] as String?,
      width: json['width'] as String?,
      depth: json['depth'] as String?,
      color: json['color'] as String?,
      active: json['active'] as bool?,
      activeUpdateDate: json['activeUpdateDate'] as bool?,
      new_: json['new'] as bool?,
      preowned: json['preowned'] as bool?,
      refurbished: json['refurbished'] as bool?,
      digital: json['digital'] as bool?,
      marketplace: json['marketplace'] as bool?,
      bestBuyOnly: json['bestBuyOnly'] as bool?,
      quantityLimit: json['quantityLimit'] as bool?,
      homeDelivery: json['homeDelivery'] as bool?,
      storePickup: json['storePickup'] as bool?,
      friendsAndFamilyPickup: json['friendsAndFamilyPickup'] as bool?,
      offers: (json['offers'] as List<dynamic>?)
              ?.map((e) => Offer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      details: (json['details'] as List<dynamic>?)
              ?.map((e) => ProductDetail.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sku': sku,
      'upc': upc,
      'name': name,
      'type': type,
      'modelNumber': modelNumber,
      'manufacturer': manufacturer,
      'url': url,
      'addToCartUrl': addToCartUrl,
      'mobileUrl': mobileUrl,
      'regularPrice': regularPrice,
      'salePrice': salePrice,
      'onSale': onSale,
      'percentSavings': percentSavings,
      'dollarSavings': dollarSavings,
      'priceRestriction': priceRestriction,
      'priceUpdateDate': priceUpdateDate,
      'inStoreAvailability': inStoreAvailability,
      'inStoreAvailabilityText': inStoreAvailabilityText,
      'inStoreAvailabilityUpdateDate': inStoreAvailabilityUpdateDate,
      'onlineAvailability': onlineAvailability,
      'onlineAvailabilityText': onlineAvailabilityText,
      'onlineAvailabilityUpdateDate': onlineAvailabilityUpdateDate,
      'orderable': orderable,
      'freeShipping': freeShipping,
      'shippingCost': shippingCost,
      'releaseDate': releaseDate,
      'image': image,
      'thumbnailImage': thumbnailImage,
      'mediumImage': mediumImage,
      'largeFrontImage': largeFrontImage,
      'largeImage': largeImage,
      'angleImage': angleImage,
      'backViewImage': backViewImage,
      'leftViewImage': leftViewImage,
      'rightViewImage': rightViewImage,
      'topViewImage': topViewImage,
      'alternateViewsImage': alternateViewsImage,
      'images': images.map((e) => e.toJson()).toList(),
      'longDescription': longDescription,
      'shortDescription': shortDescription,
      'longDescriptionHtml': longDescriptionHtml,
      'plot': plot,
      'features': features.map((e) => {'feature': e}).toList(),
      'includedItemList':
          includedItemList.map((e) => {'includedItem': e}).toList(),
      'condition': condition,
      'categoryPath': categoryPath.map((e) => e.toJson()).toList(),
      'class': productClass,
      'classId': classId,
      'subclass': subclass,
      'subclassId': subclassId,
      'department': department,
      'departmentId': departmentId,
      'customerReviewAverage': customerReviewAverage,
      'customerReviewCount': customerReviewCount,
      'weight': weight,
      'shippingWeight': shippingWeight,
      'height': height,
      'width': width,
      'depth': depth,
      'color': color,
      'active': active,
      'activeUpdateDate': activeUpdateDate,
      'new': new_,
      'preowned': preowned,
      'refurbished': refurbished,
      'digital': digital,
      'marketplace': marketplace,
      'bestBuyOnly': bestBuyOnly,
      'quantityLimit': quantityLimit,
      'homeDelivery': homeDelivery,
      'storePickup': storePickup,
      'friendsAndFamilyPickup': friendsAndFamilyPickup,
      'offers': offers.map((e) => e.toJson()).toList(),
      'details': details.map((e) => e.toJson()).toList(),
    };
  }

  /// Returns the best available price (sale price if on sale, otherwise regular).
  double? get effectivePrice => onSale == true ? salePrice : regularPrice;

  /// Returns the best available image URL.
  String? get bestImage =>
      largeImage ?? largeFrontImage ?? mediumImage ?? image ?? thumbnailImage;

  /// Returns true if the product is available for purchase online or in-store.
  bool get isAvailable =>
      (onlineAvailability == true) || (inStoreAvailability == true);

  /// Formats product information for AI consumption.
  /// Returns a concise text block with key product details.
  String toAIContext() {
    final buffer = StringBuffer();
    
    buffer.writeln('=== PRODUCT CONTEXT ===');
    buffer.writeln('Name: $name');
    buffer.writeln('SKU: $sku');
    if (upc != null) buffer.writeln('UPC: $upc');
    if (manufacturer != null) buffer.writeln('Brand: $manufacturer');
    if (modelNumber != null) buffer.writeln('Model: $modelNumber');
    
    // Pricing
    buffer.writeln();
    buffer.writeln('PRICING:');
    if (effectivePrice != null) {
      buffer.writeln('Current Price: \$${effectivePrice!.toStringAsFixed(2)}');
    }
    if (onSale == true && regularPrice != null) {
      buffer.writeln('Regular Price: \$${regularPrice!.toStringAsFixed(2)}');
      if (percentSavings != null) {
        buffer.writeln('Savings: ${percentSavings!.toStringAsFixed(0)}% off');
      }
    }
    
    // Availability
    buffer.writeln();
    buffer.writeln('AVAILABILITY:');
    buffer.writeln('Online: ${onlineAvailability == true ? "Available" : "Not available"}');
    buffer.writeln('In-Store: ${inStoreAvailability == true ? "Available" : "Not available"}');
    if (freeShipping == true) buffer.writeln('Free Shipping: Yes');
    
    // Description
    if (shortDescription != null && shortDescription!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('DESCRIPTION:');
      buffer.writeln(shortDescription);
    }
    
    // Features
    if (features.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('KEY FEATURES:');
      for (final feature in features.take(5)) {
        buffer.writeln('• $feature');
      }
      if (features.length > 5) {
        buffer.writeln('• ... and ${features.length - 5} more features');
      }
    }
    
    // Specifications
    final specs = <String>[];
    if (color != null) specs.add('Color: $color');
    if (weight != null) specs.add('Weight: $weight');
    if (height != null && width != null && depth != null) {
      specs.add('Dimensions: $height x $width x $depth');
    }
    if (condition != null) specs.add('Condition: $condition');
    
    if (specs.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('SPECIFICATIONS:');
      for (final spec in specs) {
        buffer.writeln('• $spec');
      }
    }
    
    // Reviews
    if (customerReviewAverage != null) {
      buffer.writeln();
      buffer.writeln('REVIEWS:');
      buffer.writeln('Rating: ${customerReviewAverage!.toStringAsFixed(1)}/5');
      if (customerReviewCount != null) {
        buffer.writeln('Review Count: $customerReviewCount');
      }
    }
    
    // Category
    if (categoryPath.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('CATEGORY: ${categoryPath.map((c) => c.name).join(' > ')}');
    }
    
    buffer.writeln('=== END PRODUCT CONTEXT ===');
    
    return buffer.toString();
  }

  @override
  String toString() => 'BestBuyProduct(sku: $sku, name: $name)';

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// Represents an image associated with a product.
class ProductImage {
  final String? rel;
  final String? href;
  final int? height;
  final int? width;
  final bool? primary;
  final String? unitOfMeasure;

  ProductImage({
    this.rel,
    this.href,
    this.height,
    this.width,
    this.primary,
    this.unitOfMeasure,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      rel: json['rel'] as String?,
      href: json['href'] as String?,
      height: _parseInt(json['height']),
      width: _parseInt(json['width']),
      primary: json['primary'] as bool?,
      unitOfMeasure: json['unitOfMeasure'] as String?,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'rel': rel,
      'href': href,
      'height': height,
      'width': width,
      'primary': primary,
      'unitOfMeasure': unitOfMeasure,
    };
  }
}

/// Represents a category in the product's category path.
class CategoryPath {
  final String? id;
  final String? name;

  CategoryPath({this.id, this.name});

  factory CategoryPath.fromJson(Map<String, dynamic> json) {
    return CategoryPath(
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

/// Represents a special offer for a product.
class Offer {
  final String? id;
  final String? type;
  final String? text;
  final String? startDate;
  final String? endDate;
  final String? url;

  Offer({
    this.id,
    this.type,
    this.text,
    this.startDate,
    this.endDate,
    this.url,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      id: json['id'] as String?,
      type: json['type'] as String?,
      text: json['text'] as String?,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'text': text,
      'startDate': startDate,
      'endDate': endDate,
      'url': url,
    };
  }
}

/// Represents a product detail/attribute (like color, storage size, etc.).
class ProductDetail {
  final String? name;
  final String? value;

  ProductDetail({this.name, this.value});

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    return ProductDetail(
      name: json['name'] as String?,
      value: json['value'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
    };
  }

  @override
  String toString() => '$name: $value';
}

