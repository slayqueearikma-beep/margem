import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_spacing.dart';
import '../theme/category_theme.dart';
import '../../l10n/app_localizations.dart';

final onboardingCategoriesProvider =
    FutureProvider.autoDispose<List<CategoryModel>>((ref) {
  return apiServiceProvider.fetchCategories();
});

Future<CategoryModel?> showCategoryPicker(
  BuildContext context,
  List<CategoryModel> categories, {
  CategoryModel? selected,
}) {
  return showModalBottomSheet<CategoryModel>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final locale = Localizations.localeOf(ctx).languageCode;
      var query = '';
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
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
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
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: context.l10n.search,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => query = value.trim()),
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
                      final isSelected = selected?.id == category.id;
                      return ListTile(
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
                            : null,
                        onTap: () => Navigator.pop(ctx, category),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
