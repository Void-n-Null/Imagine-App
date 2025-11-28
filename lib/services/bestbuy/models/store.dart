/// Represents a Best Buy store from the Stores API.
class BestBuyStore {
  final int storeId;
  final String? name;
  final String? address;
  final String? address2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final String? phone;
  final double? lat;
  final double? lng;
  final String? storeType;
  final double? distance;
  final String? hours;
  final String? hoursAmPm;
  final String? gmtOffset;

  const BestBuyStore({
    required this.storeId,
    this.name,
    this.address,
    this.address2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.phone,
    this.lat,
    this.lng,
    this.storeType,
    this.distance,
    this.hours,
    this.hoursAmPm,
    this.gmtOffset,
  });

  factory BestBuyStore.fromJson(Map<String, dynamic> json) {
    return BestBuyStore(
      storeId: _parseInt(json['storeId'] ?? json['storeID']) ?? 0,
      name: json['name'] as String?,
      address: json['address'] as String?,
      address2: json['address2'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String? ?? json['region'] as String?,
      postalCode: json['postalCode'] as String? ?? json['fullPostalCode'] as String?,
      country: json['country'] as String?,
      phone: json['phone'] as String?,
      lat: _parseDouble(json['lat']),
      lng: _parseDouble(json['lng'] ?? json['long']),
      storeType: json['storeType'] as String?,
      distance: _parseDouble(json['distance']),
      hours: json['hours'] as String?,
      hoursAmPm: json['hoursAmPm'] as String?,
      gmtOffset: json['gmtOffset']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'storeId': storeId,
    'name': name,
    'address': address,
    'address2': address2,
    'city': city,
    'state': state,
    'postalCode': postalCode,
    'country': country,
    'phone': phone,
    'lat': lat,
    'lng': lng,
    'storeType': storeType,
    'distance': distance,
    'hours': hours,
    'hoursAmPm': hoursAmPm,
    'gmtOffset': gmtOffset,
  };

  /// Returns the full address as a single string.
  String get fullAddress {
    final parts = <String>[];
    if (address != null) parts.add(address!);
    if (address2 != null && address2!.isNotEmpty) parts.add(address2!);
    if (city != null) {
      final cityLine = <String>[city!];
      if (state != null) cityLine.add(state!);
      if (postalCode != null) cityLine.add(postalCode!);
      parts.add(cityLine.join(', '));
    }
    return parts.join('\n');
  }

  /// Returns city and state formatted (e.g., "Maplewood, MN").
  String get cityState {
    final parts = <String>[];
    if (city != null) parts.add(city!);
    if (state != null) parts.add(state!);
    return parts.join(', ');
  }

  /// Returns formatted distance string (e.g., "2.5 mi").
  String? get distanceFormatted {
    if (distance == null) return null;
    return '${distance!.toStringAsFixed(1)} mi';
  }

  @override
  String toString() => 'BestBuyStore(storeId: $storeId, name: $name, distance: $distance)';

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

/// Response from the store availability API for a specific product.
class StoreAvailabilityResponse {
  /// Whether the product is eligible for in-store pickup.
  final bool ispuEligible;

  /// List of stores that have the product, sorted by distance.
  final List<StoreAvailability> stores;

  const StoreAvailabilityResponse({
    required this.ispuEligible,
    required this.stores,
  });

  factory StoreAvailabilityResponse.fromJson(Map<String, dynamic> json) {
    final storesList = json['stores'] as List<dynamic>? ?? [];
    return StoreAvailabilityResponse(
      ispuEligible: json['ispuEligible'] as bool? ?? false,
      stores: storesList
          .map((s) => StoreAvailability.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Returns the nearest store with the product in stock.
  StoreAvailability? get nearestStore => stores.isNotEmpty ? stores.first : null;

  /// Returns whether any stores have the product.
  bool get hasAvailableStores => stores.isNotEmpty;
}

/// Availability information for a product at a specific store.
class StoreAvailability {
  final int storeId;
  final String? name;
  final String? address;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? storeType;
  final double? distance;
  final bool lowStock;
  final int? minPickupHours;

  const StoreAvailability({
    required this.storeId,
    this.name,
    this.address,
    this.city,
    this.state,
    this.postalCode,
    this.storeType,
    this.distance,
    this.lowStock = false,
    this.minPickupHours,
  });

  factory StoreAvailability.fromJson(Map<String, dynamic> json) {
    return StoreAvailability(
      storeId: _parseInt(json['storeID'] ?? json['storeId']) ?? 0,
      name: json['name'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postalCode'] as String?,
      storeType: json['storeType'] as String?,
      distance: _parseDouble(json['distance']),
      lowStock: json['lowStock'] as bool? ?? false,
      minPickupHours: json['minPickupHours'] as int?,
    );
  }

  /// Returns city and state formatted (e.g., "Maplewood, MN").
  String get cityState {
    final parts = <String>[];
    if (city != null) parts.add(city!);
    if (state != null) parts.add(state!);
    return parts.join(', ');
  }

  /// Returns formatted distance string (e.g., "2.5 mi").
  String? get distanceFormatted {
    if (distance == null) return null;
    return '${distance!.toStringAsFixed(1)} mi';
  }

  /// Returns formatted address (street, city state zip).
  String get fullAddress {
    final parts = <String>[];
    if (address != null) parts.add(address!);
    final cityLine = <String>[];
    if (city != null) cityLine.add(city!);
    if (state != null) cityLine.add(state!);
    if (postalCode != null) cityLine.add(postalCode!);
    if (cityLine.isNotEmpty) parts.add(cityLine.join(' '));
    return parts.join(', ');
  }

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

