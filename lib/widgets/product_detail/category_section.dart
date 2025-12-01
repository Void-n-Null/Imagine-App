import 'package:flutter/material.dart';
import '../../services/bestbuy/bestbuy.dart';
import '../../theme/app_colors.dart';

class CategorySection extends StatefulWidget {
  const CategorySection({super.key, required this.categories});

  final List<CategoryPath> categories;

  @override
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories;
    final showExpand = categories.length > 2;
    final collapsedCategories = categories.length <= 2
        ? categories
        : categories.sublist(categories.length - 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.category_outlined, size: 20, color: AppColors.primaryBlue),
            ),
            const SizedBox(width: 12),
            Text(
              'Category',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedCrossFade(
          firstChild: _CollapsedCategoryView(
              categories: collapsedCategories, totalCount: categories.length),
          secondChild: _ExpandedCategoryView(categories: categories),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
        if (showExpand) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Text(
                  _expanded ? 'Show less' : 'Show full hierarchy (${categories.length} levels)',
                  style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CollapsedCategoryView extends StatelessWidget {
  const _CollapsedCategoryView({required this.categories, required this.totalCount});

  final List<CategoryPath> categories;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (totalCount > 2) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '...',
              style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 12),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
          ),
        ],
        ...categories.asMap().entries.map((entry) {
          final isLast = entry.key == categories.length - 1;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isLast
                      ? AppColors.primaryBlue.withValues(alpha: 0.15)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isLast
                        ? AppColors.primaryBlue.withValues(alpha: 0.4)
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  entry.value.name ?? 'Unknown',
                  style: TextStyle(
                    color: isLast ? AppColors.primaryBlue : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (!isLast)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class _ExpandedCategoryView extends StatelessWidget {
  const _ExpandedCategoryView({required this.categories});

  final List<CategoryPath> categories;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: categories.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          final isLast = index == categories.length - 1;

          return Padding(
            padding: EdgeInsets.only(left: index * 16.0, top: index > 0 ? 8 : 0),
            child: Row(
              children: [
                if (index > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.subdirectory_arrow_right,
                      size: 16,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isLast
                        ? AppColors.primaryBlue.withValues(alpha: 0.15)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                    border: isLast
                        ? Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.4))
                        : null,
                  ),
                  child: Text(
                    category.name ?? 'Unknown',
                    style: TextStyle(
                      color: isLast ? AppColors.primaryBlue : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
