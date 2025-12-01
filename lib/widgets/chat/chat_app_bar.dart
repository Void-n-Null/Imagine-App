import 'package:flutter/material.dart';
import '../../services/comparison/comparison.dart';
import '../../services/storage/cart_service.dart';
import '../../theme/app_colors.dart';

/// Builder function for the chat page AppBar with polished styling
PreferredSizeWidget buildChatAppBar({
  required BuildContext context,
  required VoidCallback onThreadSelectorTap,
  required VoidCallback onNewChat,
  required VoidCallback onScanProduct,
  required VoidCallback onOpenCart,
  required VoidCallback onOpenSettings,
  required VoidCallback onOpenComparison,
}) {
  return AppBar(
    backgroundColor: AppColors.background,
    elevation: 0,
    scrolledUnderElevation: 0,
    title: const Text(
      'Imagine',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    ),
    centerTitle: true,
    leading: IconButton(
      icon: const Icon(Icons.menu_rounded),
      tooltip: 'Chat Threads',
      onPressed: onThreadSelectorTap,
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.settings_outlined),
        tooltip: 'Settings',
        onPressed: onOpenSettings,
      ),
      IconButton(
        icon: const Icon(Icons.add_rounded),
        tooltip: 'New Chat',
        onPressed: onNewChat,
      ),
      IconButton(
        icon: const Icon(Icons.qr_code_scanner_rounded),
        tooltip: 'Scan Product',
        onPressed: onScanProduct,
      ),
      // Comparison button with badge
      _ComparisonIconButton(onPressed: onOpenComparison),
      // Cart button with badge
      _CartIconButton(onPressed: onOpenCart),
    ],
  );
}

/// Comparison icon button with item count badge
class _ComparisonIconButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _ComparisonIconButton({required this.onPressed});

  @override
  State<_ComparisonIconButton> createState() => _ComparisonIconButtonState();
}

class _ComparisonIconButtonState extends State<_ComparisonIconButton> {
  final ComparisonService _comparison = ComparisonService.instance;

  @override
  void initState() {
    super.initState();
    _comparison.addListener(_onComparisonChanged);
  }

  @override
  void dispose() {
    _comparison.removeListener(_onComparisonChanged);
    super.dispose();
  }

  void _onComparisonChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = _comparison.itemCount;
    
    return IconButton(
      icon: Badge(
        isLabelVisible: itemCount > 0,
        label: Text(
          itemCount > 99 ? '99+' : itemCount.toString(),
          style: const TextStyle(fontSize: 10),
        ),
        backgroundColor: AppColors.secondaryBlue,
        textColor: AppColors.background,
        child: const Icon(Icons.compare_outlined),
      ),
      tooltip: 'Product Comparison',
      onPressed: widget.onPressed,
    );
  }
}

/// Cart icon button with item count badge
class _CartIconButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _CartIconButton({required this.onPressed});

  @override
  State<_CartIconButton> createState() => _CartIconButtonState();
}

class _CartIconButtonState extends State<_CartIconButton> {
  final CartService _cart = CartService.instance;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = _cart.itemCount;
    
    return IconButton(
      icon: Badge(
        isLabelVisible: itemCount > 0,
        label: Text(
          itemCount > 99 ? '99+' : itemCount.toString(),
          style: const TextStyle(fontSize: 10),
        ),
        backgroundColor: AppColors.accentYellow,
        textColor: AppColors.background,
        child: const Icon(Icons.shopping_cart_outlined),
      ),
      tooltip: 'Shopping Cart',
      onPressed: widget.onPressed,
    );
  }
}
