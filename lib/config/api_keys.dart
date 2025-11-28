// lib/config/api_keys.dart
class ApiKeys {
  // Loaded from --dart-define at build time
  static const String bestBuy = String.fromEnvironment(
    'BESTBUY_API_KEY',
    defaultValue: '', // Empty default for safety
  );
}