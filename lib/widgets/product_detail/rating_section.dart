import 'package:flutter/material.dart';
import '../../services/bestbuy/bestbuy.dart';
import '../../theme/app_colors.dart';

class RatingSection extends StatelessWidget {
  const RatingSection({
    super.key,
    required this.product,
    required this.buildSection,
  });

  final BestBuyProduct product;
  final Widget Function(BuildContext, {required String title, required IconData icon, required Widget child}) buildSection;

  @override
  Widget build(BuildContext context) {
    if (product.customerReviewAverage == null) {
      return const SizedBox.shrink();
    }

    final rating = product.customerReviewAverage!;
    final count = product.customerReviewCount ?? 0;
    
    // Determine rating tier and color
    final (String tier, Color tierColor) = switch (rating) {
      >= 4.5 => ('Excellent', AppColors.success),
      >= 4.0 => ('Very Good', const Color(0xFF8BC34A)),
      >= 3.5 => ('Good', AppColors.accentYellow),
      >= 3.0 => ('Average', const Color(0xFFFF9800)),
      >= 2.0 => ('Fair', const Color(0xFFFF5722)),
      _ => ('Poor', AppColors.error),
    };
    
    // Review count context
    final String countContext = switch (count) {
      >= 1000 => 'Very popular',
      >= 500 => 'Popular choice',
      >= 100 => 'Well reviewed',
      >= 25 => 'Reviewed',
      >= 5 => 'Limited reviews',
      _ => 'Few reviews',
    };

    return buildSection(
      context,
      title: 'Customer Reviews',
      icon: Icons.star_outline,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            // Main rating row
            Row(
              children: [
                // Score display
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tierColor.withValues(alpha: 0.2),
                        tierColor.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: tierColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: tierColor,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'out of 5',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Rating details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: tierColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tier,
                              style: TextStyle(
                                color: tierColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            countContext,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Star display
                      Row(
                        children: List.generate(5, (index) {
                          if (index < rating.floor()) {
                            return const Icon(Icons.star,
                                color: AppColors.brightYellow, size: 20);
                          } else if (index < rating) {
                            return const Icon(Icons.star_half,
                                color: AppColors.brightYellow, size: 20);
                          } else {
                            return Icon(Icons.star_border,
                                color: AppColors.textSecondary.withValues(alpha: 0.4),
                                size: 20);
                          }
                        }),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_formatReviewCount(count)} ${count == 1 ? 'review' : 'reviews'}',
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
            const SizedBox(height: 16),
            // Rating distribution bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: (rating * 20).round(),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              tierColor,
                              tierColor.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 100 - (rating * 20).round(),
                      child: Container(
                        color: AppColors.surfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Scale labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '1',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  '5',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatReviewCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}
