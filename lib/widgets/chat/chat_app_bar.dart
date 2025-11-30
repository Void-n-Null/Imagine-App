import 'package:flutter/material.dart';
import '../../services/storage/cart_service.dart';
import '../../theme/app_colors.dart';

/// Builder function for the chat page AppBar with polished styling
PreferredSizeWidget buildChatAppBar({
  required BuildContext context,
  required String selectedModelName,
  required bool isAuthenticated,
  required VoidCallback onModelSelectorTap,
  required VoidCallback onThreadSelectorTap,
  required VoidCallback onNewChat,
  required VoidCallback onScanProduct,
  required VoidCallback onOpenCart,
  required VoidCallback onShowInfo,
}) {
  return AppBar(
    backgroundColor: AppColors.background,
    elevation: 0,
    scrolledUnderElevation: 0,
    title: GestureDetector(
      onTap: onModelSelectorTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isAuthenticated ? AppColors.success : AppColors.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                selectedModelName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
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
        icon: const Icon(Icons.help_outline_rounded),
        tooltip: 'App Info',
        onPressed: onShowInfo,
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
      // Cart button with badge
      _CartIconButton(onPressed: onOpenCart),
    ],
  );
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
