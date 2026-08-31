import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/models/models.dart';
import 'package:souq_local/features/search/search_navigation_intent.dart';

MarketplaceVenueModel _market(String slug) => MarketplaceVenueModel(
      id: slug,
      slug: slug,
      name: slug,
    );

void main() {
  final marketplaces = [_market('derb-ghallef'), _market('habous')];

  test('search marketplace scope ignores unknown slugs', () {
    expect(
      resolveSearchMarketplaceSlug('missing-market', marketplaces),
      isNull,
    );
  });

  test('search marketplace scope accepts explicit valid slug', () {
    expect(
      resolveSearchMarketplaceSlug('derb-ghallef', marketplaces),
      'derb-ghallef',
    );
  });

  test('search marketplace scope stays unscoped when slug is empty', () {
    expect(resolveSearchMarketplaceSlug(null, marketplaces), isNull);
    expect(resolveSearchMarketplaceSlug('', marketplaces), isNull);
  });
}
