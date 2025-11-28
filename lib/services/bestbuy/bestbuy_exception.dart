/// Base exception for all Best Buy API errors.
sealed class BestBuyException implements Exception {
  final String message;
  final Object? cause;

  const BestBuyException(this.message, [this.cause]);

  @override
  String toString() => '$runtimeType: $message';
}

/// Exception thrown when the Best Buy API returns an error response.
///
/// Common error codes:
/// - 400: Bad Request (invalid query syntax)
/// - 401: Unauthorized (invalid API key)
/// - 403: Forbidden (API key lacks permissions)
/// - 404: Not Found (product/resource not found)
/// - 429: Too Many Requests (rate limit exceeded)
/// - 500: Internal Server Error
/// - 503: Service Unavailable
class BestBuyApiException extends BestBuyException {
  /// HTTP status code from the API response.
  final int statusCode;

  /// Error code from the API response body, if available.
  final String? errorCode;

  const BestBuyApiException({
    required this.statusCode,
    required String message,
    this.errorCode,
    Object? cause,
  }) : super(message, cause);

  /// Returns true if this is a rate limit error (429).
  bool get isRateLimitError => statusCode == 429;

  /// Returns true if this is an authentication error (401 or 403).
  bool get isAuthError => statusCode == 401 || statusCode == 403;

  /// Returns true if this is a not found error (404).
  bool get isNotFound => statusCode == 404;

  /// Returns true if this is a server error (5xx).
  bool get isServerError => statusCode >= 500 && statusCode < 600;

  /// Returns true if the request should be retried.
  bool get shouldRetry => isServerError || isRateLimitError;

  @override
  String toString() =>
      'BestBuyApiException($statusCode): $message${errorCode != null ? ' [$errorCode]' : ''}';
}

/// Exception thrown when a network error occurs (no connection, timeout, etc.).
class BestBuyNetworkException extends BestBuyException {
  /// Whether this error is due to a timeout.
  final bool isTimeout;

  const BestBuyNetworkException({
    required String message,
    this.isTimeout = false,
    Object? cause,
  }) : super(message, cause);

  @override
  String toString() =>
      'BestBuyNetworkException: $message${isTimeout ? ' (timeout)' : ''}';
}

/// Exception thrown when the API response cannot be parsed.
class BestBuyParseException extends BestBuyException {
  /// The raw response body that failed to parse.
  final String? responseBody;

  const BestBuyParseException({
    required String message,
    this.responseBody,
    Object? cause,
  }) : super(message, cause);

  @override
  String toString() => 'BestBuyParseException: $message';
}

/// Exception thrown when a required configuration is missing.
class BestBuyConfigException extends BestBuyException {
  const BestBuyConfigException(super.message);
}

