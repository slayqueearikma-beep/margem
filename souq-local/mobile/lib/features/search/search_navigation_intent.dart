import 'search_category_resolver.dart';
import 'search_filters.dart';

class SearchIntentApplication {
  const SearchIntentApplication({
    required this.mode,
    required this.resolvedCategory,
    required this.filtersByMode,
  });

  final String mode;
  final String? resolvedCategory;
  final Map<String, SearchFilters> filtersByMode;
}

SearchIntentApplication applySearchNavigationIntent({
  required SearchNavigationIntent intent,
  required String currentMode,
  required Map<String, SearchFilters> filtersByMode,
}) {
  final mode = intent.mode;
  final resolved = resolveSearchCategorySlug(intent.categorySlug);
  final updated = Map<String, SearchFilters>.from(filtersByMode);
  updated[mode] = (updated[mode] ?? const SearchFilters()).copyWith(
    category: resolved,
    clearCategory: resolved == null,
  );
  return SearchIntentApplication(
    mode: mode,
    resolvedCategory: resolved,
    filtersByMode: updated,
  );
}
