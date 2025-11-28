import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../config/api_keys.dart';
import '../services/bestbuy/bestbuy.dart';
import '../theme/app_colors.dart';
import 'product_detail_page.dart';
import 'product_search_page.dart';

class ScanProductPage extends StatefulWidget {
  const ScanProductPage({super.key});

  @override
  State<ScanProductPage> createState() => _ScanProductPageState();
}

class _ScanProductPageState extends State<ScanProductPage> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late final BestBuyClient _bestBuyClient;

  bool _isScanning = false;
  bool _isLoadingProduct = false;
  String? _loadingMessage;

  @override
  void initState() {
    super.initState();
    _bestBuyClient = BestBuyClient(apiKey: ApiKeys.bestBuy);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _bestBuyClient.close();
    super.dispose();
  }

  void _navigateToSearch({String? initialQuery}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductSearchPage(
          client: _bestBuyClient,
          initialQuery: initialQuery,
        ),
      ),
    ).then((_) {
      // Clear search field when returning
      _searchController.clear();
    });
  }

  Future<void> _startScanning() async {
    if (_isScanning) {
      return;
    }

    setState(() {
      _isScanning = true;
    });

    await WidgetsBinding.instance.endOfFrame;

    try {
      await _scannerController.start();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to start camera: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _stopScanning() async {
    if (!_isScanning) {
      return;
    }
    setState(() => _isScanning = false);
    try {
      await _scannerController.stop();
    } catch (_) {
      // Ignore stop failures; controller handles its own lifecycle.
    }
  }

  void _handleDetection(BarcodeCapture capture) {
    if (!_isScanning || _isLoadingProduct) {
      return;
    }

    for (final barcode in capture.barcodes) {
      final String? value = barcode.rawValue;
      if (value == null || value.isEmpty) {
        continue;
      }

      unawaited(_stopScanning());

      // Determine if this is a UPC or SKU and look up the product
      if (_isUpcFormat(barcode.format)) {
        _lookupProductByUpc(value);
      } else if (barcode.format == BarcodeFormat.qrCode) {
        // QR codes can contain either UPC or SKU
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
    // QR codes can contain UPCs (numeric, typically 12-13 digits) or SKUs (typically numeric, 7-8 digits)
    // Try to determine which one based on the format
    
    final cleanValue = value.trim();
    
    // Check if it's purely numeric
    if (RegExp(r'^\d+$').hasMatch(cleanValue)) {
      if (cleanValue.length >= 11 && cleanValue.length <= 14) {
        // Likely a UPC (UPC-A is 12 digits, EAN-13 is 13 digits)
        await _lookupProductByUpc(cleanValue);
      } else if (cleanValue.length >= 6 && cleanValue.length <= 10) {
        // Likely a SKU (Best Buy SKUs are typically 7-8 digits)
        await _lookupProductBySku(cleanValue);
      } else {
        // Try UPC first, then SKU
        await _lookupProductByUpc(cleanValue, fallbackToSku: true);
      }
    } else {
      // Non-numeric, might be a URL or other format - try as SKU
      // Extract numbers if it looks like a URL with a product ID
      final skuMatch = RegExp(r'(\d{6,10})').firstMatch(cleanValue);
      if (skuMatch != null) {
        await _lookupProductBySku(skuMatch.group(1)!);
      } else {
        _showError('Could not parse QR code: $cleanValue');
      }
    }
  }

  Future<void> _lookupProductByUpc(String upc, {bool fallbackToSku = false}) async {
    if (ApiKeys.bestBuy.isEmpty) {
      _showError('API key not configured');
      return;
    }

    setState(() {
      _isLoadingProduct = true;
      _loadingMessage = 'Looking up UPC: $upc';
    });

    try {
      final product = await _bestBuyClient.getProductByUpc(upc);
      if (!mounted) return;

      if (product != null) {
        _navigateToProduct(product);
      } else if (fallbackToSku) {
        // Try as SKU instead
        await _lookupProductBySku(upc);
      } else {
        setState(() {
          _isLoadingProduct = false;
          _loadingMessage = null;
        });
        _showError('Product not found for UPC: $upc');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProduct = false;
        _loadingMessage = null;
      });
      
      if (fallbackToSku) {
        await _lookupProductBySku(upc);
      } else {
        _showError('Error looking up product: ${_formatError(e)}');
      }
    }
  }

  Future<void> _lookupProductBySku(String sku) async {
    if (ApiKeys.bestBuy.isEmpty) {
      _showError('API key not configured');
      return;
    }

    // Try to parse as int for SKU lookup
    final skuInt = int.tryParse(sku);
    if (skuInt == null) {
      _showError('Invalid SKU format: $sku');
      return;
    }

    setState(() {
      _isLoadingProduct = true;
      _loadingMessage = 'Looking up SKU: $sku';
    });

    try {
      final product = await _bestBuyClient.getProductBySku(skuInt);
      if (!mounted) return;

      if (product != null) {
        _navigateToProduct(product);
      } else {
        setState(() {
          _isLoadingProduct = false;
          _loadingMessage = null;
        });
        _showError('Product not found for SKU: $sku');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProduct = false;
        _loadingMessage = null;
      });
      _showError('Error looking up product: ${_formatError(e)}');
    }
  }

  String _formatError(dynamic e) {
    if (e is BestBuyApiException) return e.message;
    if (e is BestBuyNetworkException) return 'Network error: ${e.message}';
    return e.toString();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _navigateToProduct(BestBuyProduct product) {
    setState(() {
      _isLoadingProduct = false;
      _loadingMessage = null;
    });
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildScanArea(),
              ),
            ),
          ],
        ),
      ),
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
          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Find Products',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search bar - real TextField that navigates on focus/submit
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
                // Unfocus and navigate immediately on tap
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

  Widget _buildScanArea() {
    return Column(
      children: [
        // Scan area - takes most of the space
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isScanning
                ? _buildScanner()
                : _buildScanPlaceholder(),
          ),
        ),
        const SizedBox(height: 16),
        // Scan button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _isScanning ? Icons.stop_rounded : Icons.qr_code_scanner_rounded,
                key: ValueKey(_isScanning),
              ),
            ),
            label: Text(
              _isScanning ? 'Stop Scanning' : 'Scan Barcode',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: _isScanning ? AppColors.error : AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _isLoadingProduct 
                ? null 
                : (_isScanning ? _stopScanning : _startScanning),
          ),
        ),
      ],
    );
  }

  Widget _buildScanner() {
    return Stack(
      key: const ValueKey('scanner'),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: MobileScanner(
            controller: _scannerController,
            fit: BoxFit.cover,
            onDetect: _handleDetection,
          ),
        ),
        // Scan overlay
        Positioned.fill(
          child: CustomPaint(
            painter: _ScanOverlayPainter(),
          ),
        ),
        // Loading overlay
        if (_isLoadingProduct)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: AppColors.primaryBlue,
                    strokeWidth: 3,
                  ),
                  if (_loadingMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _loadingMessage!,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScanPlaceholder() {
    return Container(
      key: const ValueKey('placeholder'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceVariant,
            AppColors.surface.withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(
          color: AppColors.border,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated barcode icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.9, end: 1.0),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeInOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryBlue.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.primaryBlue.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.qr_code_scanner_rounded,
                size: 64,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Scan a Product',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Point your camera at a barcode or QR code to find product details',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
            ),
          ),
          const SizedBox(height: 24),
          // Supported formats
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildFormatChip('UPC'),
              _buildFormatChip('EAN'),
              _buildFormatChip('QR Code'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormatChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentYellow.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accentYellow.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.accentYellow,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Custom painter for the scan overlay with corner brackets
class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryBlue
      ..strokeWidth = 4
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
