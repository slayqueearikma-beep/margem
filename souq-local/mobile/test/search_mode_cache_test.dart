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
  group('SearchModeCache.scopeKey', () {
    test('changes when filters or query change', () {
      final base = SearchModeCache.scopeKey(
        mode: 'products',
        sort: 'relevance',
        query: 'tagine',
        city: 'Casablanca',
      );
      final otherCity = SearchModeCache.scopeKey(
        mode: 'products',
        sort: 'relevance',
        query: 'tagine',
        city: 'Rabat',
      );
      final otherQuery = SearchModeCache.scopeKey(
        mode: 'products',
        sort: 'relevance',
        query: 'bowl',
      );
      final otherSort = SearchModeCache.scopeKey(
        mode: 'products',
        sort: 'distance',
        query: 'tagine',
        lat: 33.5731,
        lng: -7.5898,
      );
      final otherLocation = SearchModeCache.scopeKey(
        mode: 'products',
        sort: 'distance',
        query: 'tagine',
        lat: 34.0209,
        lng: -6.8416,
      );
      final otherMode = SearchModeCache.scopeKey(
        mode: 'services',
        sort: 'relevance',
        query: 'tagine',
      );
      final withCategory = SearchModeCache.scopeKey(
        mode: 'products',
        sort: 'relevance',
        query: 'tagine',
        category: 'food',
      );
      final withDelivery = SearchModeCache.scopeKey(
        mode: 'products',
        sort: 'relevance',
        query: 'tagine',
        deliveryAvailable: true,
      );

      expect(otherQuery, isNot(base));
      expect(otherCity, isNot(base));
      expect(otherSort, isNot(base));
      expect(otherLocation, isNot(otherSort));
      expect(otherMode, isNot(base));
      expect(withCategory, isNot(base));
      expect(withDelivery, isNot(base));
    });

    test('keeps product-only delivery flags out of services scope', () {
      final servicesBase = SearchModeCache.scopeKey(
        mode: 'services',
        sort: 'relevance',
        query: '',
        deliveryAvailable: true,
        pickupOnly: true,
      );
      final servicesPlain = SearchModeCache.scopeKey(
        mode: 'services',
        sort: 'relevance',
        query: '',
      );
      expect(servicesBase, servicesPlain);
    });
  });

  group('SearchModeCache', () {
    test('tracks independent scopes for products and services', () {
      final cache = SearchModeCache();
      final productsKey = SearchModeCache.scopeKey(
        mode: 'products',
        sort: 'relevance',
        query: '',
        category: 'food',
      );
      final servicesKey = SearchModeCache.scopeKey(
        mode: 'services',
        sort: 'relevance',
        query: '',
        category: 'repair',
      );

      cache.save(
        productsKey,
        SearchResultsSnapshot.forMode(
          mode: 'products',
          products: [_product('1')],
          services: const [],
          sellers: const [],
          offset: 1,
          hasMore: true,
        ),
      );
      cache.save(
        servicesKey,
        SearchResultsSnapshot.forMode(
          mode: 'services',
          products: const [],
          services: const [],
          sellers: const [],
          offset: 2,
          hasMore: false,
        ),
      );

      expect(cache.isLoaded(productsKey), isTrue);
      expect(cache.isLoaded(servicesKey), isTrue);
      expect(cache.snapshot(productsKey)!.products.length, 1);
      expect(cache.snapshot(servicesKey)!.products, isEmpty);
    });

    test('invalidateAll clears scoped snapshots', () {
      final cache = SearchModeCache();
      final key = SearchModeCache.scopeKey(
        mode: 'products',
        sort: 'distance',
        query: 'test',
      );
      cache.save(
        key,
        SearchResultsSnapshot.forMode(
          mode: 'products',
          products: [_product('1')],
          services: const [],
          sellers: const [],
          offset: 1,
          hasMore: false,
        ),
      );

      cache.invalidateAll();

      expect(cache.isLoaded(key), isFalse);
      expect(cache.offsetFor(key), 0);
    });

    test('mode-specific snapshot stores only relevant list', () {
      final snapshot = SearchResultsSnapshot.forMode(
        mode: 'products',
        products: [_product('1')],
        services: const [],
        sellers: const [],
        offset: 3,
        hasMore: true,
      );

      expect(snapshot.products, isNotEmpty);
      expect(snapshot.services, isEmpty);
      expect(snapshot.sellers, isEmpty);
      expect(snapshot.copy().products, isNotEmpty);
    });

    test('invalidateMode clears only one mode prefix', () {
      final cache = SearchModeCache();
      final productsKey = SearchModeCache.scopeKey(
        mode: 'products',
        sort: 'relevance',
        query: '',
      );
      final servicesKey = SearchModeCache.scopeKey(
        mode: 'services',
        sort: 'relevance',
        query: '',
      );
      cache.save(
        productsKey,
        SearchResultsSnapshot.forMode(
          mode: 'products',
          products: [_product('1')],
          services: const [],
          sellers: const [],
          offset: 1,
          hasMore: false,
        ),
      );
      cache.save(
        servicesKey,
        SearchResultsSnapshot.forMode(
          mode: 'services',
          products: const [],
          services: const [],
          sellers: const [],
          offset: 1,
          hasMore: false,
        ),
      );

      cache.invalidateMode('products');

      expect(cache.isLoaded(productsKey), isFalse);
      expect(cache.isLoaded(servicesKey), isTrue);
    });
  });
}
