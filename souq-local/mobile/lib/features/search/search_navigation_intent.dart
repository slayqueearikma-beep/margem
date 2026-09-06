import '../../core/models/models.dart';
import 'search_category_resolver.dart';
import 'search_filters.dart';

/// Atomic search navigation from home/marketplace screens.
class SearchNavigationIntent {
  const SearchNavigationIntent({
    required this.mode,
    this.categorySlug,
    this.marketplaceSlug,
  });

  final String mode;
  final String? categorySlug;
  final String? marketplaceSlug;
}

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

/// Search marketplace scope is explicit — never inherit the home tab chip.
String? resolveSearchMarketplaceSlug(
  String? slug,
  List<MarketplaceVenueModel> marketplaces,
) {
  if (slug == null || slug.isEmpty) return null;
  return marketplaces.any((market) => market.slug == slug) ? slug : null;
}
