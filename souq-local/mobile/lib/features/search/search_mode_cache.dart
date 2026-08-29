import '../../core/models/models.dart';

/// Cached search results for one scoped query (mode + sort + filters + query).
class SearchResultsSnapshot {
  const SearchResultsSnapshot({
    required this.mode,
    required this.products,
    required this.services,
    required this.sellers,
    required this.offset,
    required this.hasMore,
  });

  final String mode;
  final List<SearchProductModel> products;
  final List<SearchServiceModel> services;
  final List<SellerModel> sellers;
  final int offset;
  final bool hasMore;

  SearchResultsSnapshot copy() {
    return SearchResultsSnapshot(
      mode: mode,
      products: List<SearchProductModel>.from(products),
      services: List<SearchServiceModel>.from(services),
      sellers: List<SellerModel>.from(sellers),
      offset: offset,
      hasMore: hasMore,
    );
  }

  factory SearchResultsSnapshot.forMode({
    required String mode,
    required List<SearchProductModel> products,
    required List<SearchServiceModel> services,
    required List<SellerModel> sellers,
    required int offset,
    required bool hasMore,
  }) {
    return switch (mode) {
      'services' => SearchResultsSnapshot(
          mode: mode,
          products: const [],
          services: List<SearchServiceModel>.from(services),
          sellers: const [],
          offset: offset,
          hasMore: hasMore,
        ),
      'providers' => SearchResultsSnapshot(
          mode: mode,
          products: const [],
          services: const [],
          sellers: List<SellerModel>.from(sellers),
          offset: offset,
          hasMore: hasMore,
        ),
      _ => SearchResultsSnapshot(
          mode: mode,
          products: List<SearchProductModel>.from(products),
          services: const [],
          sellers: const [],
          offset: offset,
          hasMore: hasMore,
        ),
    };
  }
}

/// Scope-aware cache for marketplace search results.
class SearchModeCache {
  final Map<String, SearchResultsSnapshot> _snapshots = {};

  static String scopeKey({
    required String mode,
    required String sort,
    required String query,
    String? marketplace,
    String? category,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    bool deliveryAvailable = false,
    bool pickupOnly = false,
  }) {
    return [
      mode,
      sort,
      query,
      marketplace ?? '',
      category ?? '',
      minPrice?.toString() ?? '',
      maxPrice?.toString() ?? '',
      minRating?.toString() ?? '',
      if (mode == 'products') deliveryAvailable,
      if (mode == 'products') pickupOnly,
    ].join('\u0001');
  }

  void invalidateAll() => _snapshots.clear();

  bool isLoaded(String scopeKey) => _snapshots.containsKey(scopeKey);

  SearchResultsSnapshot? snapshot(String scopeKey) => _snapshots[scopeKey];

  void save(String scopeKey, SearchResultsSnapshot snapshot) {
    _snapshots[scopeKey] = snapshot.copy();
  }

  int offsetFor(String scopeKey) => snapshot(scopeKey)?.offset ?? 0;

  bool hasMoreFor(String scopeKey) => snapshot(scopeKey)?.hasMore ?? false;
}
