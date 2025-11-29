import 'dart:async';
import '../scan_request_service.dart';
import '../tool.dart';

/// Tool that requests the user to scan a product barcode.
/// 
/// This enables human-in-the-loop interaction where the AI can ask
/// the user to scan a product and receive the product information
/// as the tool result.
class RequestScanTool extends Tool {
  final ScanRequestService _scanService;
  
  RequestScanTool({ScanRequestService? scanService})
      : _scanService = scanService ?? ScanRequestService.instance;
  
  @override
  String get name => 'request_scan';
  
  @override
  String get displayName => 'Requesting Scan...';
  
  @override
  String get description => '''Request the user to scan a product barcode or QR code.

Use this when:
- The user has a physical product and you need to identify it
- The user mentions they're looking at a product in-store
- You need to look up a product but don't have the SKU or UPC
- The user asks about compatibility or details of a product they have

The app will automatically open the camera scanner and wait for the user to scan.
Returns the full product details if found, or an appropriate message if the scan times out, 
is cancelled, or the product is not found.''';
  
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'product_name': {
        'type': 'string',
        'description': 'A brief description of what product the user should scan. '
            'This is shown to the user to help them know what to scan. '
            'Example: "the USB cable", "the laptop", "the product barcode"',
      },
    },
    'required': ['product_name'],
  };
  
  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final productName = args['product_name'] as String? ?? 'the product';
    
    try {
      // Request the scan and wait for result
      // We use a long safety timeout (60s) here to handle cases where the UI fails to open.
      // The actual user interaction timeout (20s) is handled by the ScanProductPage.
      final result = await _scanService
          .requestScan(productName)
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              _scanService.completeTimeout();
              return ScanResult.timeout();
            },
          );
      
      return _formatResult(result);
    } catch (e) {
      return 'Error requesting scan: $e';
    }
  }
  
  String _formatResult(ScanResult result) {
    return switch (result) {
      ScanResultSuccess(:final product) => _formatSuccessResult(product),
      ScanResultTimeout() => _formatTimeoutResult(),
      ScanResultCancelled(:final reason) => _formatCancelledResult(reason),
      ScanResultNotFound(:final code) => _formatNotFoundResult(code),
      ScanResultError(:final message) => _formatErrorResult(message),
    };
  }
  
  String _formatSuccessResult(product) {
    final buffer = StringBuffer();
    buffer.writeln('=== SCANNED PRODUCT ===');
    buffer.writeln();
    buffer.writeln(product.toAIContext());
    buffer.writeln();
    buffer.writeln('To display this product to the user, use: [Product(${product.sku})]');
    return buffer.toString();
  }
  
  String _formatTimeoutResult() {
    return '''The user did not scan a product within the time limit (20 seconds).

Possible reasons:
- They couldn't find the barcode on the product
- They decided not to scan
- They had technical difficulties with the camera

You should:
1. Ask if they still want to scan (they can try again)
2. Offer to search for the product by name instead
3. Ask for any identifying information they can see (brand, model number, etc.)''';
  }
  
  String _formatCancelledResult(String reason) {
    return '''The scan was cancelled: $reason

The user chose not to complete the scan. You should:
1. Ask if they'd like to try again
2. Offer alternative ways to identify the product (search by name, describe it, etc.)
3. Continue the conversation naturally''';
  }
  
  String _formatNotFoundResult(String code) {
    return '''The barcode was scanned but no matching product was found in the Best Buy catalog.

Scanned code: $code

This could mean:
- The product is not sold at Best Buy
- The barcode is for a different retailer's internal use
- The product has been discontinued

You should:
1. Let the user know the product wasn't found in Best Buy's system
2. Offer to search for similar products by description
3. Ask for more details about the product they're looking for''';
  }
  
  String _formatErrorResult(String message) {
    return '''An error occurred while processing the scan: $message

You should:
1. Acknowledge the technical issue
2. Offer to try scanning again
3. Suggest searching for the product by name as an alternative''';
  }
}

