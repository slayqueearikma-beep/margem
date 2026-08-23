import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/category_theme.dart';
import '../../core/widgets/async_error_view.dart';
import '../../l10n/app_localizations.dart';
import '../buyer/buyer_home_screen.dart';

final categoriesBrowseProvider =
    FutureProvider.autoDispose<List<CategoryModel>>((ref) {
  return apiServiceProvider.fetchCategories();
});

class CategoriesBrowseScreen extends ConsumerWidget {
  const CategoriesBrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final categoriesAsync = ref.watch(categoriesBrowseProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.categories)),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(categoriesBrowseProvider),
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return Center(child: Text(l10n.noPremiumPlans));
          }
          final locale = Localizations.localeOf(context).languageCode;
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.35,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final color = CategoryTheme.accentColor(
                category.accentColor,
                slug: category.slug,
              );
              return _CategoryCard(
                label: category.localizedName(locale),
                icon: CategoryTheme.iconFor(category.icon),
                color: color,
                onTap: () {
                  ref.read(buyerCategorySlugProvider.notifier).state =
                      category.slug;
                  context.go('/buyer/home');
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const Spacer(),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
