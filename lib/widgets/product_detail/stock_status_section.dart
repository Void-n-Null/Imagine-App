import 'package:flutter/material.dart';
import '../../services/bestbuy/bestbuy.dart';
import '../../theme/app_colors.dart';

class StockStatusSection extends StatelessWidget {
  const StockStatusSection({
    super.key,
    required this.product,
    required this.storeAvailabilityWidget,
  });

  final BestBuyProduct product;
  final Widget storeAvailabilityWidget;

  @override
  Widget build(BuildContext context) {
    final isOnline = product.onlineAvailability == true;
    final isInStore = product.inStoreAvailability == true;
    final isAvailable = isOnline || isInStore;

    return Column(
      children: [
        // Main stock status card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isAvailable
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isAvailable
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.error.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? AppColors.success.withValues(alpha: 0.2)
                      : AppColors.error.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAvailable ? Icons.check_circle : Icons.cancel,
                  color: isAvailable ? AppColors.success : AppColors.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAvailable ? 'In Stock' : 'Out of Stock',
                      style: TextStyle(
                        color: isAvailable ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOnline && isInStore
                          ? 'Available online & in-store'
                          : isOnline
                              ? 'Available online only'
                              : isInStore
                                  ? 'Available in-store only'
                                  : 'Currently unavailable',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Store availability section (only for in-store products)
        if (isInStore) ...[
          const SizedBox(height: 12),
          storeAvailabilityWidget,
        ],
      ],
    );
  }
}
