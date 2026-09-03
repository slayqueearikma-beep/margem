import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/features/search/search_category_resolver.dart';

void main() {
  test('maps marketplace slugs to fundamental listing slugs', () {
    expect(resolveSearchCategorySlug('phones'), 'electronics');
    expect(resolveSearchCategorySlug('Electronics'), 'electronics');
    expect(resolveSearchCategorySlug('services'), 'home');
    expect(resolveSearchCategorySlug('food'), 'food');
    expect(resolveSearchCategorySlug(null), isNull);
    expect(resolveSearchCategorySlug(''), isNull);
  });
}
