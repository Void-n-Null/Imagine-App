import 'package:flutter/material.dart';
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
  required VoidCallback onConnectOpenRouter,
  required VoidCallback onDisconnectOpenRouter,
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
      IconButton(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isAuthenticated ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            key: ValueKey(isAuthenticated),
            color: isAuthenticated ? AppColors.success : AppColors.textSecondary,
          ),
        ),
        tooltip: isAuthenticated ? 'Connected to OpenRouter' : 'Connect OpenRouter',
        onPressed: isAuthenticated ? onDisconnectOpenRouter : onConnectOpenRouter,
      ),
    ],
  );
}
