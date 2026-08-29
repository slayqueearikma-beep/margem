import 'package:flutter_test/flutter_test.dart';

import 'package:souq_local/core/models/models.dart';

void main() {
  test('AdvertisingPackageModel parses backend payload', () {
    final model = AdvertisingPackageModel.fromJson({
      'code': 'boost_24h',
      'name': 'Boost 24 hours',
      'description': 'Increase storefront visibility for 24 hours.',
      'placement_type': 'sponsored_listing',
      'price_mad': 10,
      'duration_days': 1,
    });

    expect(model.code, 'boost_24h');
    expect(model.priceMad, 10);
    expect(model.durationDays, 1);
  });
}
