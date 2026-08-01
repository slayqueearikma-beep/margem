import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/category_theme.dart';
import '../../l10n/app_localizations.dart';

final onboardingCategoriesProvider =
    FutureProvider.autoDispose<List<CategoryModel>>((ref) {
  return apiServiceProvider.fetchCategories();
});

const int maxSellerCategories = 3;

Future<CategoryModel?> showCategoryPicker(
  BuildContext context,
  List<CategoryModel> categories, {
  CategoryModel? selected,
}) {
  return showCategoryMultiPicker(
    context,
    categories,
    selected: selected != null ? [selected] : const [],
    maxSelection: 1,
  ).then((value) => value.isEmpty ? null : value.first);
}

Future<List<CategoryModel>> showCategoryMultiPicker(
  BuildContext context,
  List<CategoryModel> categories, {
  List<CategoryModel> selected = const [],
  int maxSelection = maxSellerCategories,
}) {
  return showModalBottomSheet<List<CategoryModel>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final locale = Localizations.localeOf(ctx).languageCode;
      var query = '';
      final picked = List<CategoryModel>.from(selected);

      return StatefulBuilder(
        builder: (context, setState) {
          final filtered = query.isEmpty
              ? categories
              : categories
                  .where(
                    (c) => c.localizedName(locale)
                        .toLowerCase()
                        .contains(query.toLowerCase()),
                  )
                  .toList();

          void toggle(CategoryModel category) {
            setState(() {
              final index = picked.indexWhere((item) => item.id == category.id);
              if (index >= 0) {
                picked.removeAt(index);
              } else if (picked.length < maxSelection) {
                picked.add(category);
              }
            });
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (_, controller) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    0,
                    AppSpacing.screenHorizontal,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        maxSelection == 1
                            ? context.l10n.businessCategory
                            : context.l10n.businessCategories,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (maxSelection > 1) ...[
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.businessCategoriesHint(maxSelection),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        decoration: InputDecoration(
                          hintText: context.l10n.search,
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onChanged: (value) => setState(() => query = value.trim()),
                      ),
                    ],
                  ),
                ),
                if (picked.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: picked.map((category) {
                          final color = CategoryTheme.accentColor(
                            category.accentColor,
                            slug: category.slug,
                          );
                          return InputChip(
                            label: Text(category.localizedName(locale)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => toggle(category),
                            avatar: Icon(
                              CategoryTheme.iconFor(category.icon),
                              size: 16,
                              color: color,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: filtered.length,
                    itemBuilder: (_, index) {
                      final category = filtered[index];
                      final color = CategoryTheme.accentColor(
                        category.accentColor,
                        slug: category.slug,
                      );
                      final isSelected =
                          picked.any((item) => item.id == category.id);
                      final atLimit = !isSelected && picked.length >= maxSelection;
                      return ListTile(
                        enabled: !atLimit,
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(
                            CategoryTheme.iconFor(category.icon),
                            color: color,
                            size: 20,
                          ),
                        ),
                        title: Text(category.localizedName(locale)),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: color)
                            : atLimit
                                ? const Icon(Icons.block, color: AppColors.textSecondary)
                                : null,
                        onTap: () => toggle(category),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: picked.isEmpty ? null : () => Navigator.pop(ctx, picked),
                        child: Text(context.l10n.confirm),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  ).then((value) => value ?? List<CategoryModel>.from(selected));
}
