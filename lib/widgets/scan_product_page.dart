import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../config/api_keys.dart';
import '../services/agent/scan_request_service.dart';
import '../services/bestbuy/bestbuy.dart';
import '../services/comparison/comparison.dart';
import '../theme/app_colors.dart';
import 'product_detail_page.dart';
import 'product_search_page.dart';

/// Route arguments for scan request mode
class ScanRequestArgs {
  final ScanRequest request;
  const ScanRequestArgs({required this.request});
}

/// Route arguments for comparison mode
class ComparisonModeArgs {
  const ComparisonModeArgs();
}

class ScanProductPage extends StatefulWidget {
  const ScanProductPage({super.key});

  @override
  State<ScanProductPage> createState() => _ScanProductPageState();
}

class _ScanProductPageState extends State<ScanProductPage> {
  // Controller with autoStart - the MobileScanner widget handles lifecycle
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    autoStart: true,
  );
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late final BestBuyClient _bestBuyClient;
  
  // Scan request mode
  ScanRequest? _scanRequest;
  Timer? _countdownTimer;
  int _remainingSeconds = 20;
  bool _hasNavigatedBack = false;
  
  // Comparison mode
  bool _isComparisonMode = false;
  
  // Debounce/cooldown logic
  String? _lastScannedCode;
  bool _isLookingUp = false;
  Timer? _cooldownTimer;

  bool _didCheckArgs = false;

  /// Whether we're in scan request mode (triggered by AI)
  bool get _isRequestMode => _scanRequest != null;

  @override
  void initState() {
    super.initState();
    _bestBuyClient = BestBuyClient(apiKey: ApiKeys.bestBuy);
    
    // Listen to comparison changes for UI updates
    ComparisonService.instance.addListener(_onComparisonChanged);
    
    // Lock orientation to portrait for consistent camera view
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  void _onComparisonChanged() {
    if (mounted) setState(() {});
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Check for scan request args (only once)
    if (!_didCheckArgs) {
      _didCheckArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is ScanRequestArgs) {
        _scanRequest = args.request;
        // Reset timer to full duration when page opens, ignoring navigation delay
        _remainingSeconds = args.request.timeout.inSeconds;
        _startCountdown();
      } else if (args is ComparisonModeArgs) {
        _isComparisonMode = true;
      }
    }
  }

  @override
  void dispose() {
    // Restore all orientations when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    _countdownTimer?.cancel();
    _cooldownTimer?.cancel();
    ComparisonService.instance.removeListener(_onComparisonChanged);
    _scannerController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _bestBuyClient.close();
    super.dispose();
  }
  
  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _remainingSeconds--;
      });
      
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _handleTimeout();
      }
    });
  }
  
  void _handleTimeout() {
    if (_hasNavigatedBack) return;
    _hasNavigatedBack = true;
    
    ScanRequestService.instance.completeTimeout();
    Navigator.of(context).pop();
  }
  
  void _handleCancel() {
    if (_isRequestMode) {
      if (_hasNavigatedBack) return;
      _hasNavigatedBack = true;
      ScanRequestService.instance.cancelScan('User cancelled');
    }
    Navigator.of(context).pop();
  }

  void _navigateToSearch({String? initialQuery}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductSearchPage(
          client: _bestBuyClient,
          initialQuery: initialQuery,
          comparisonMode: _isComparisonMode,
        ),
      ),
    ).then((_) {
      _searchController.clear();
    });
  }

  void _handleDetection(BarcodeCapture capture) {
    // Don't process if we're already looking up, in cooldown, or navigated away
    if (_isLookingUp || _hasNavigatedBack) return;

    for (final barcode in capture.barcodes) {
      final String? value = barcode.rawValue;
      if (value == null || value.isEmpty) continue;
      
      // Skip if same as last scanned code (prevents duplicate scans)
      if (value == _lastScannedCode) continue;
      
      _lastScannedCode = value;
      
      // Determine if this is a UPC or SKU and look up the product
      if (_isUpcFormat(barcode.format)) {
        _lookupProductByUpc(value);
      } else if (barcode.format == BarcodeFormat.qrCode) {
        _lookupProductFromQrCode(value);
      } else {
        // Try as SKU for other formats
        _lookupProductBySku(value);
      }
      break;
    }
  }

  bool _isUpcFormat(BarcodeFormat format) {
    return format == BarcodeFormat.upcA ||
        format == BarcodeFormat.upcE ||
        format == BarcodeFormat.ean13 ||
        format == BarcodeFormat.ean8;
  }

  Future<void> _lookupProductFromQrCode(String value) async {
    final cleanValue = value.trim();
    
    // Check for Best Buy in-store QR code URLs
    // Format: http://bby.us/?c=BB006116636938&LMD=true
    // The 'c' parameter is: BB + 5-digit store number + SKU
    final bbyUrlMatch = RegExp(r'bby\.us/?\?c=BB\d{5}(\d+)', caseSensitive: false).firstMatch(cleanValue);
    if (bbyUrlMatch != null) {
      final sku = bbyUrlMatch.group(1)!;
      await _lookupProductBySku(sku);
      return;
    }
    
    // Check for Best Buy product page URLs (bestbuy.com/site/*/skuId.p)
    final bbySiteMatch = RegExp(r'bestbuy\.com/site/[^/]+/(\d+)\.p', caseSensitive: false).firstMatch(cleanValue);
    if (bbySiteMatch != null) {
      final sku = bbySiteMatch.group(1)!;
      await _lookupProductBySku(sku);
      return;
    }
    
    // Check if it's purely numeric
    if (RegExp(r'^\d+$').hasMatch(cleanValue)) {
      if (cleanValue.length >= 11 && cleanValue.length <= 14) {
        // Likely a UPC (UPC-A is 12 digits, EAN-13 is 13 digits)
        await _lookupProductByUpc(cleanValue);
      } else if (cleanValue.length >= 6 && cleanValue.length <= 10) {
        // Likely a SKU (Best Buy SKUs are typically 7-8 digits)
        await _lookupProductBySku(cleanValue);
      } else if (cleanValue.length < 6) {
        // Too short, probably not valid
        _handleInvalidBarcode('Code too short');
      } else {
        // Try UPC first, then SKU as fallback
        await _lookupProductByUpc(cleanValue, fallbackToSku: true);
      }
    } else {
      // Non-numeric, might be a URL or other format
      // Try to extract SKU from URL patterns or raw numbers
      final skuMatch = RegExp(r'(\d{6,10})').firstMatch(cleanValue);
      if (skuMatch != null) {
        await _lookupProductBySku(skuMatch.group(1)!);
      } else {
        _handleInvalidBarcode('Not a product code');
      }
    }
  }

  Future<void> _lookupProductByUpc(String upc, {bool fallbackToSku = false}) async {
    if (ApiKeys.bestBuy.isEmpty) {
      _handleInvalidBarcode('API key not configured');
      return;
    }

    _isLookingUp = true;

    try {
      final product = await _bestBuyClient.getProductByUpc(upc);
      if (!mounted) return;

      if (product != null) {
        _handleProductFound(product);
      } else if (fallbackToSku) {
        await _lookupProductBySku(upc);
      } else {
        _handleInvalidBarcode('Not a Best Buy product');
      }
    } catch (e) {
      if (!mounted) return;
      
      if (fallbackToSku) {
        await _lookupProductBySku(upc);
      } else {
        _handleInvalidBarcode('Not a Best Buy product');
      }
    }
  }

  Future<void> _lookupProductBySku(String sku) async {
    if (ApiKeys.bestBuy.isEmpty) {
      _handleInvalidBarcode('API key not configured');
      return;
    }

    final skuInt = int.tryParse(sku);
    if (skuInt == null) {
      _handleInvalidBarcode('Invalid code format');
      return;
    }

    _isLookingUp = true;

    try {
      final product = await _bestBuyClient.getProductBySku(skuInt);
      if (!mounted) return;

      if (product != null) {
        _handleProductFound(product);
      } else {
        _handleInvalidBarcode('Not a Best Buy product');
      }
    } catch (e) {
      if (!mounted) return;
      _handleInvalidBarcode('Not a Best Buy product');
    }
  }
  
  void _handleProductFound(BestBuyProduct product) {
    _isLookingUp = false;
    
    if (_isRequestMode) {
      // In request mode, complete the scan request and go back
      if (!_hasNavigatedBack) {
        _hasNavigatedBack = true;
        _countdownTimer?.cancel();
        ScanRequestService.instance.completeScan(product);
        Navigator.of(context).pop();
      }
    } else if (_isComparisonMode) {
      // In comparison mode, add product to comparison list
      _addToComparison(product);
    } else {
      // Normal mode: navigate to product detail
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ProductDetailPage(product: product),
        ),
      ).then((_) {
        // Reset last scanned code when returning so user can scan again
        _lastScannedCode = null;
      });
    }
  }

  Future<void> _addToComparison(BestBuyProduct product) async {
    final comparison = ComparisonService.instance;
    
    if (comparison.containsSku(product.sku)) {
      _showTip('${product.name} is already in comparison');
      _lastScannedCode = null;
      return;
    }
    
    if (comparison.isFull) {
      _showTip('Comparison list is full (max ${ComparisonService.maxComparisonItems})', isError: true);
      _lastScannedCode = null;
      return;
    }
    
    // Add product and wait for persistence
    await comparison.addToComparison(product);
    
    if (!mounted) return;
    
    HapticFeedback.lightImpact();
    
    final count = comparison.itemCount;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Added to comparison ($count item${count == 1 ? '' : 's'})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: count >= 2 ? SnackBarAction(
          label: 'Compare',
          textColor: Colors.white,
          onPressed: () => Navigator.of(context).pop(),
        ) : null,
      ),
    );
    
    // Reset so user can scan more products
    _lastScannedCode = null;
  }
  
  /// Handle invalid barcode - show tip and continue scanning after 1 second
  void _handleInvalidBarcode(String message) {
    _isLookingUp = false;
    
    // Show a brief non-blocking tip
    _showTip(message);
    
    // Start cooldown - wait 1 second before allowing next scan
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(seconds: 1), () {
      // Allow scanning the same code again after cooldown
      _lastScannedCode = null;
    });
  }

  /// Show a brief tip/toast that doesn't interrupt scanning
  void _showTip(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.surfaceVariant,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isRequestMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isRequestMode) {
          _handleCancel();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Show request mode header, comparison mode header, or normal header
              if (_isRequestMode)
                _buildRequestModeHeader()
              else if (_isComparisonMode)
                _buildComparisonModeHeader()
              else
                _buildHeader(),
              // Scanner fills the rest
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildScanner(),
                ),
              ),
              // Bottom button area
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _isRequestMode
                    ? _buildRequestModeButton()
                    : _isComparisonMode
                        ? _buildComparisonModeButton()
                        : _buildBackButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Build header for scan request mode with countdown
  Widget _buildRequestModeHeader() {
    final productName = _scanRequest?.productName ?? 'product';
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryBlue,
            AppColors.primaryBlue.withValues(alpha: 0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with back button and countdown
          Row(
            children: [
              // Back/Cancel button
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: _handleCancel,
                tooltip: 'Cancel',
              ),
              const SizedBox(width: 8),
              // AI request indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'AI Request',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Countdown timer
              _buildCountdownBadge(),
            ],
          ),
          const SizedBox(height: 16),
          // Request message
          Text(
            'Please scan $productName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Point your camera at the barcode to help the AI identify the product',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCountdownBadge() {
    final isLow = _remainingSeconds <= 5;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isLow 
            ? AppColors.error.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: isLow
            ? Border.all(color: Colors.white.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timer_outlined,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            '${_remainingSeconds}s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  /// Build header for comparison mode
  Widget _buildComparisonModeHeader() {
    final itemCount = ComparisonService.instance.itemCount;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondaryBlue,
            AppColors.secondaryBlue.withValues(alpha: 0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondaryBlue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with back button and count
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: _handleCancel,
                tooltip: 'Back',
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.compare_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Add to Compare',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Item count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.compare_arrows_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$itemCount item${itemCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Instructions
          const Text(
            'Scan or Search Products',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Products will be added to your comparison list',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onTap: () {
                _searchFocusNode.unfocus();
                _navigateToSearch();
              },
              onSubmitted: (value) {
                _navigateToSearch(initialQuery: value);
              },
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 22,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildComparisonModeButton() {
    final itemCount = ComparisonService.instance.itemCount;
    
    return Column(
      children: [
        if (itemCount >= 2)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.compare_arrows_rounded),
              label: Text(
                'Compare $itemCount Products',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.secondaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        if (itemCount >= 2) const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: Text(
              itemCount < 2 ? 'Add ${2 - itemCount} more to compare' : 'Add More Products',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: AppColors.textSecondary,
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: null, // Disabled - just informational
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with back button
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _handleCancel,
                tooltip: 'Back',
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Scan Product',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onTap: () {
                _searchFocusNode.unfocus();
                _navigateToSearch();
              },
              onSubmitted: (value) {
                _navigateToSearch(initialQuery: value);
              },
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: const TextStyle(
                  color: AppColors.textSecondary,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Best Buy',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                suffixIconConstraints: const BoxConstraints(
                  minHeight: 24,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBackButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.arrow_back_rounded),
        label: const Text(
          'Back',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          foregroundColor: AppColors.textSecondary,
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: _handleCancel,
      ),
    );
  }
  
  Widget _buildRequestModeButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.close_rounded),
        label: const Text(
          'Cancel Scan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          foregroundColor: AppColors.textSecondary,
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: _handleCancel,
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        // Scanner view - widget auto-starts with the controller
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: MobileScanner(
            controller: _scannerController,
            fit: BoxFit.cover,
            onDetect: _handleDetection,
            errorBuilder: (context, error) {
              return Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        color: AppColors.textSecondary,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Camera unavailable',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Scan overlay with corner brackets
        Positioned.fill(
          child: CustomPaint(
            painter: _ScanOverlayPainter(isRequestMode: _isRequestMode),
          ),
        ),
        // Bottom hint
        Positioned(
          left: 0,
          right: 0,
          bottom: 20,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Point at a barcode',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for the scan overlay with corner brackets
class _ScanOverlayPainter extends CustomPainter {
  final bool isRequestMode;
  
  _ScanOverlayPainter({this.isRequestMode = false});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isRequestMode ? AppColors.accentYellow : AppColors.primaryBlue
      ..strokeWidth = isRequestMode ? 5 : 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cornerLength = size.width * 0.12;
    final scanAreaPadding = size.width * 0.1;
    
    final rect = Rect.fromLTRB(
      scanAreaPadding,
      size.height / 2 - size.width * 0.4,
      size.width - scanAreaPadding,
      size.height / 2 + size.width * 0.4,
    );

    // Top left corner
    canvas.drawLine(
      Offset(rect.left, rect.top + cornerLength),
      Offset(rect.left, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLength, rect.top),
      paint,
    );

    // Top right corner
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.top),
      Offset(rect.right, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLength),
      paint,
    );

    // Bottom left corner
    canvas.drawLine(
      Offset(rect.left, rect.bottom - cornerLength),
      Offset(rect.left, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerLength, rect.bottom),
      paint,
    );

    // Bottom right corner
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.bottom),
      Offset(rect.right, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) => 
      oldDelegate.isRequestMode != isRequestMode;
}
