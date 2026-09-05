import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/models/models.dart';
import 'package:souq_local/core/providers/buyer_discovery_providers.dart';

void main() {
  group('validatedMarketplaceSlug', () {
    final marketplaces = <MarketplaceVenueModel>[
      const MarketplaceVenueModel(
        id: '1',
        slug: 'central-market',
        name: 'Central Market',
        city: 'Casablanca',
        sellerCount: 3,
      ),
    ];

    test('returns null for unknown slug', () {
      expect(
        validatedMarketplaceSlug('missing-market', marketplaces),
        isNull,
      );
    });

    test('returns slug when marketplace exists', () {
      expect(
        validatedMarketplaceSlug('central-market', marketplaces),
        'central-market',
      );
    });

    test('returns null for empty slug', () {
      expect(validatedMarketplaceSlug(null, marketplaces), isNull);
      expect(validatedMarketplaceSlug('', marketplaces), isNull);
    });
  });
}
