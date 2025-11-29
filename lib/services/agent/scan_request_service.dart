import 'dart:async';
import 'package:flutter/foundation.dart';
import '../bestbuy/models/product.dart';

/// Result of a scan request
sealed class ScanResult {
  const ScanResult();
  
  /// Successfully scanned a product
  factory ScanResult.success(BestBuyProduct product) = ScanResultSuccess;
  
  /// Scan timed out
  factory ScanResult.timeout() = ScanResultTimeout;
  
  /// User cancelled the scan
  factory ScanResult.cancelled(String reason) = ScanResultCancelled;
  
  /// Product not found after scanning barcode
  factory ScanResult.notFound(String code) = ScanResultNotFound;
  
  /// Error during scan or lookup
  factory ScanResult.error(String message) = ScanResultError;
}

class ScanResultSuccess extends ScanResult {
  final BestBuyProduct product;
  const ScanResultSuccess(this.product);
}

class ScanResultTimeout extends ScanResult {
  const ScanResultTimeout();
}

class ScanResultCancelled extends ScanResult {
  final String reason;
  const ScanResultCancelled(this.reason);
}

class ScanResultNotFound extends ScanResult {
  final String code;
  const ScanResultNotFound(this.code);
}

class ScanResultError extends ScanResult {
  final String message;
  const ScanResultError(this.message);
}

/// Represents an active scan request
class ScanRequest {
  /// Description of what should be scanned (shown to user)
  final String productName;
  
  /// Completer that resolves when scan completes or times out
  final Completer<ScanResult> completer;
  
  /// When the request was created (for timeout tracking)
  final DateTime startTime;
  
  /// Timeout duration for the scan
  final Duration timeout;
  
  ScanRequest({
    required this.productName,
    required this.completer,
    required this.startTime,
    this.timeout = const Duration(seconds: 20),
  });
  
  /// Remaining time before timeout
  Duration get remainingTime {
    final elapsed = DateTime.now().difference(startTime);
    final remaining = timeout - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }
  
  /// Whether the request has timed out
  bool get isTimedOut => remainingTime == Duration.zero;
  
  /// Whether the completer has been resolved
  bool get isCompleted => completer.isCompleted;
}

/// Service that coordinates scan requests between the AI tool and the UI.
/// 
/// Usage:
/// 1. Tool calls [requestScan] and awaits the result
/// 2. UI listens to this service and navigates to scanner when [hasActiveRequest]
/// 3. Scanner calls [completeScan] or [cancelScan] when done
/// 4. The tool's await completes with the result
class ScanRequestService extends ChangeNotifier {
  ScanRequestService._();
  
  static final ScanRequestService instance = ScanRequestService._();
  
  /// The currently active scan request, if any
  ScanRequest? _activeRequest;
  
  /// Get the active scan request
  ScanRequest? get activeRequest => _activeRequest;
  
  /// Whether there's an active scan request
  bool get hasActiveRequest => _activeRequest != null && !_activeRequest!.isCompleted;
  
  /// Request a scan from the user.
  /// 
  /// Returns a Future that completes when:
  /// - User successfully scans a product
  /// - User cancels the scan
  /// - Request times out
  /// - An error occurs
  Future<ScanResult> requestScan(String productName) async {
    // Cancel any existing request
    if (_activeRequest != null && !_activeRequest!.isCompleted) {
      _activeRequest!.completer.complete(ScanResult.cancelled('New scan requested'));
    }
    
    final completer = Completer<ScanResult>();
    _activeRequest = ScanRequest(
      productName: productName,
      completer: completer,
      startTime: DateTime.now(),
    );
    
    debugPrint('📷 Scan requested for: $productName');
    notifyListeners();
    
    // The caller should handle timeout, but we have a safety net here
    try {
      return await completer.future;
    } finally {
      // Clean up after completion
      if (_activeRequest?.completer == completer) {
        _activeRequest = null;
        notifyListeners();
      }
    }
  }
  
  /// Complete the scan with a successfully found product
  void completeScan(BestBuyProduct product) {
    if (_activeRequest != null && !_activeRequest!.isCompleted) {
      debugPrint('✅ Scan completed: ${product.name}');
      _activeRequest!.completer.complete(ScanResult.success(product));
      _activeRequest = null;
      notifyListeners();
    }
  }
  
  /// Complete the scan indicating the product was not found
  void completeNotFound(String code) {
    if (_activeRequest != null && !_activeRequest!.isCompleted) {
      debugPrint('❓ Scan not found: $code');
      _activeRequest!.completer.complete(ScanResult.notFound(code));
      _activeRequest = null;
      notifyListeners();
    }
  }
  
  /// Cancel the scan request
  void cancelScan(String reason) {
    if (_activeRequest != null && !_activeRequest!.isCompleted) {
      debugPrint('❌ Scan cancelled: $reason');
      _activeRequest!.completer.complete(ScanResult.cancelled(reason));
      _activeRequest = null;
      notifyListeners();
    }
  }
  
  /// Complete the scan with a timeout
  void completeTimeout() {
    if (_activeRequest != null && !_activeRequest!.isCompleted) {
      debugPrint('⏱️ Scan timed out');
      _activeRequest!.completer.complete(ScanResult.timeout());
      _activeRequest = null;
      notifyListeners();
    }
  }
  
  /// Complete the scan with an error
  void completeError(String message) {
    if (_activeRequest != null && !_activeRequest!.isCompleted) {
      debugPrint('💥 Scan error: $message');
      _activeRequest!.completer.complete(ScanResult.error(message));
      _activeRequest = null;
      notifyListeners();
    }
  }
}

