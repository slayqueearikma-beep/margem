import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/features/search/search_mode_cache.dart';

void main() {
  group('SearchModeCache', () {
    test('tracks pagination independently per mode', () {
      final cache = SearchModeCache();

      cache.recordPage(
        mode: 'products',
        itemCount: 20,
        pageHasMore: true,
        append: false,
      );
      cache.recordPage(
        mode: 'services',
        itemCount: 15,
        pageHasMore: false,
        append: false,
      );

      expect(cache.isLoaded('products'), isTrue);
      expect(cache.isLoaded('services'), isTrue);
      expect(cache.offsetFor('products'), 20);
      expect(cache.offsetFor('services'), 15);
      expect(cache.hasMoreFor('products'), isTrue);
      expect(cache.hasMoreFor('services'), isFalse);
    });

    test('append preserves other mode offsets', () {
      final cache = SearchModeCache();

      cache.recordPage(
        mode: 'products',
        itemCount: 20,
        pageHasMore: true,
        append: false,
      );
      cache.recordPage(
        mode: 'services',
        itemCount: 10,
        pageHasMore: true,
        append: false,
      );
      cache.recordPage(
        mode: 'products',
        itemCount: 5,
        pageHasMore: false,
        append: true,
      );

      expect(cache.offsetFor('products'), 25);
      expect(cache.offsetFor('services'), 10);
      expect(cache.hasMoreFor('products'), isFalse);
      expect(cache.hasMoreFor('services'), isTrue);
    });

    test('invalidateAll clears loaded state for every mode', () {
      final cache = SearchModeCache()
        ..recordPage(
          mode: 'products',
          itemCount: 3,
          pageHasMore: false,
          append: false,
        )
        ..recordPage(
          mode: 'services',
          itemCount: 2,
          pageHasMore: false,
          append: false,
        );

      cache.invalidateAll();

      expect(cache.isLoaded('products'), isFalse);
      expect(cache.isLoaded('services'), isFalse);
      expect(cache.offsetFor('products'), 0);
      expect(cache.offsetFor('services'), 0);
      expect(cache.hasMoreFor('products'), isFalse);
      expect(cache.hasMoreFor('services'), isFalse);
    });
  });
}
