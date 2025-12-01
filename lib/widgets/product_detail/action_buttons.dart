import 'package:flutter/material.dart';
import '../../services/bestbuy/bestbuy.dart';
import '../../services/comparison/comparison.dart';
import '../../theme/app_colors.dart';

class ActionButtons extends StatelessWidget {
  const ActionButtons({
    super.key,
    required this.product,
    required this.isInCart,
    required this.isInComparison,
    required this.comparisonService,
    required this.onToggleCart,
    required this.onToggleComparison,
    required this.onNavigateToComparison,
    required this.onAskAI,
    required this.onOpenUrl,
  });

  final BestBuyProduct product;
  final bool isInCart;
  final bool isInComparison;
  final ComparisonService comparisonService;
  final VoidCallback onToggleCart;
  final VoidCallback onToggleComparison;
  final VoidCallback onNavigateToComparison;
  final VoidCallback onAskAI;
  final void Function(String) onOpenUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Primary row: Add to Cart and Ask AI
        Row(
          children: [
            // Add to Cart button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onToggleCart,
                icon: Icon(
                  isInCart 
                      ? Icons.check_circle_rounded 
                      : Icons.add_shopping_cart_rounded,
                  size: 18,
                ),
                label: Text(isInCart ? 'In Cart' : 'Add to Cart'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isInCart 
                      ? AppColors.success 
                      : AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Ask AI button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onAskAI,
                icon: const Icon(Icons.smart_toy_outlined, size: 18),
                label: const Text('Ask AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentYellow,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        // Secondary row: Compare and View on BestBuy
        const SizedBox(height: 10),
        Row(
          children: [
            // Compare button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onToggleComparison,
                icon: Icon(
                  isInComparison 
                      ? Icons.compare_arrows_rounded 
                      : Icons.compare_outlined,
                  size: 16,
                  color: isInComparison 
                      ? AppColors.secondaryBlue 
                      : AppColors.textSecondary,
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isInComparison ? 'Comparing' : 'Compare'),
                    if (comparisonService.itemCount > 0 && !isInComparison) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${comparisonService.itemCount}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isInComparison 
                      ? AppColors.secondaryBlue 
                      : AppColors.textSecondary,
                  side: BorderSide(
                    color: isInComparison 
                        ? AppColors.secondaryBlue 
                        : AppColors.border,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            // View comparison button (only if items in comparison)
            if (comparisonService.canCompare) ...[
              const SizedBox(width: 10),
              SizedBox(
                width: 48,
                child: OutlinedButton(
                  onPressed: onNavigateToComparison,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(color: AppColors.primaryBlue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.open_in_new_rounded, size: 18),
                ),
              ),
            ],
          ],
        ),
        // Tertiary row: View on BestBuy
        if (product.url != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => onOpenUrl(product.url!),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('View on BestBuy.com'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
