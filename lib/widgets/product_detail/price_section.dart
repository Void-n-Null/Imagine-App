import 'package:flutter/material.dart';
import '../../services/bestbuy/bestbuy.dart';
import '../../theme/app_colors.dart';

class PriceSection extends StatelessWidget {
  const PriceSection({
    super.key,
    required this.product,
  });

  final BestBuyProduct product;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main price
        Text(
          '\$${product.effectivePrice?.toStringAsFixed(2) ?? 'N/A'}',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: product.onSale == true
                    ? AppColors.sale
                    : AppColors.accentYellow,
                fontWeight: FontWeight.bold,
              ),
        ),
        // Sale info: savings amount and original price
        if (product.onSale == true && product.dollarSavings != null) ...[
          const SizedBox(height: 4),
          Text(
            'You save \$${product.dollarSavings!.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
        if (product.onSale == true && product.regularPrice != null) ...[
          const SizedBox(height: 2),
          Text(
            'Originally \$${product.regularPrice!.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}
