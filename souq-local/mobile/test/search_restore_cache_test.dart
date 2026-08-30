import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/models/models.dart';
import 'package:souq_local/features/search/search_mode_cache.dart';

SearchProductModel _product(String id) => SearchProductModel(
      id: id,
      sellerId: 'seller-$id',
      sellerName: 'Shop',
      sellerCity: 'Casablanca',
      sellerVerified: false,
      sellerPremium: false,
      sellerRating: 0,
      name: 'Product $id',
      description: '',
      priceMad: 10,
      imageUrl: '',
      isAvailable: true,
    );

void main() {
  test('empty product snapshots should not be treated as restorable cache hits', () {
    final cache = SearchModeCache();
    const scopeKey = 'products\u0001relevance\u0001\u0001Casablanca\u0001\u0001\u0001\u0001\u0001\u0001';
    cache.save(
      scopeKey,
      SearchResultsSnapshot.forMode(
        mode: 'products',
        products: const [],
        services: const [],
        sellers: const [],
        offset: 0,
        hasMore: false,
      ),
    );

    expect(cache.isLoaded(scopeKey), isTrue);
    expect(cache.snapshot(scopeKey)?.products, isEmpty);
  });

  test('non-empty product snapshots remain cacheable', () {
    final cache = SearchModeCache();
    const scopeKey = 'products\u0001relevance\u0001phone\u0001Casablanca\u0001\u0001\u0001\u0001\u0001\u0001';
    cache.save(
      scopeKey,
      SearchResultsSnapshot.forMode(
        mode: 'products',
        products: [_product('1')],
        services: const [],
        sellers: const [],
        offset: 1,
        hasMore: false,
      ),
    );

    expect(cache.snapshot(scopeKey)?.products, hasLength(1));
  });
}
