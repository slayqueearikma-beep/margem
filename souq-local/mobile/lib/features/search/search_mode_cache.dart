import '../../core/models/models.dart';

/// Cached search results for one mode/sort combination.
class SearchResultsSnapshot {
  const SearchResultsSnapshot({
    required this.products,
    required this.services,
    required this.sellers,
    required this.offset,
    required this.hasMore,
  });

  final List<SearchProductModel> products;
  final List<SearchServiceModel> services;
  final List<SellerModel> sellers;
  final int offset;
  final bool hasMore;

  SearchResultsSnapshot copy() {
    return SearchResultsSnapshot(
      products: List<SearchProductModel>.from(products),
      services: List<SearchServiceModel>.from(services),
      sellers: List<SellerModel>.from(sellers),
      offset: offset,
      hasMore: hasMore,
    );
  }
}

/// Per-tab and per-sort pagination/cache metadata for marketplace search.
class SearchModeCache {
  final Map<String, SearchResultsSnapshot> _snapshots = {};

  static String cacheKey(String mode, String sort) => '$mode|$sort';

  void invalidateAll() => _snapshots.clear();

  bool isLoaded(String mode, String sort) =>
      _snapshots.containsKey(cacheKey(mode, sort));

  SearchResultsSnapshot? snapshot(String mode, String sort) =>
      _snapshots[cacheKey(mode, sort)];

  void save(String mode, String sort, SearchResultsSnapshot snapshot) {
    _snapshots[cacheKey(mode, sort)] = snapshot.copy();
  }

  int offsetFor(String mode, String sort) =>
      snapshot(mode, sort)?.offset ?? 0;

  bool hasMoreFor(String mode, String sort) =>
      snapshot(mode, sort)?.hasMore ?? false;
}
