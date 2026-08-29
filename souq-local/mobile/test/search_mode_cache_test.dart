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
  group('SearchModeCache', () {
    test('tracks pagination independently per mode and sort', () {
      final cache = SearchModeCache();

      cache.save(
        'products',
        'relevance',
        SearchResultsSnapshot(
          products: [_product('1')],
          services: const [],
          sellers: const [],
          offset: 1,
          hasMore: true,
        ),
      );
      cache.save(
        'products',
        'distance',
        SearchResultsSnapshot(
          products: [_product('2'), _product('3')],
          services: const [],
          sellers: const [],
          offset: 2,
          hasMore: false,
        ),
      );

      expect(cache.isLoaded('products', 'relevance'), isTrue);
      expect(cache.isLoaded('products', 'distance'), isTrue);
      expect(cache.offsetFor('products', 'relevance'), 1);
      expect(cache.offsetFor('products', 'distance'), 2);
      expect(cache.hasMoreFor('products', 'relevance'), isTrue);
      expect(cache.hasMoreFor('products', 'distance'), isFalse);
      expect(cache.snapshot('products', 'relevance')!.products.first.id, '1');
      expect(cache.snapshot('products', 'distance')!.products.length, 2);
    });

    test('keeps relevance and distance snapshots isolated', () {
      final cache = SearchModeCache()
        ..save(
          'services',
          'relevance',
          const SearchResultsSnapshot(
            products: [],
            services: [],
            sellers: [],
            offset: 5,
            hasMore: true,
          ),
        )
        ..save(
          'services',
          'distance',
          const SearchResultsSnapshot(
            products: [],
            services: [],
            sellers: [],
            offset: 3,
            hasMore: false,
          ),
        );

      expect(cache.offsetFor('services', 'relevance'), 5);
      expect(cache.offsetFor('services', 'distance'), 3);
      expect(cache.hasMoreFor('services', 'relevance'), isTrue);
      expect(cache.hasMoreFor('services', 'distance'), isFalse);
    });

    test('invalidateAll clears every mode and sort snapshot', () {
      final cache = SearchModeCache()
        ..save(
          'products',
          'relevance',
          SearchResultsSnapshot(
            products: [_product('1')],
            services: const [],
            sellers: const [],
            offset: 1,
            hasMore: false,
          ),
        )
        ..save(
          'services',
          'distance',
          const SearchResultsSnapshot(
            products: [],
            services: [],
            sellers: [],
            offset: 2,
            hasMore: false,
          ),
        );

      cache.invalidateAll();

      expect(cache.isLoaded('products', 'relevance'), isFalse);
      expect(cache.isLoaded('services', 'distance'), isFalse);
      expect(cache.snapshot('products', 'relevance'), isNull);
      expect(cache.offsetFor('products', 'relevance'), 0);
    });

    test('snapshot copy prevents shared list mutation', () {
      final cache = SearchModeCache();
      final products = [_product('1')];
      cache.save(
        'products',
        'relevance',
        SearchResultsSnapshot(
          products: products,
          services: const [],
          sellers: const [],
          offset: 1,
          hasMore: false,
        ),
      );

      products.clear();

      expect(cache.snapshot('products', 'relevance')!.products, isNotEmpty);
    });
  });
}
