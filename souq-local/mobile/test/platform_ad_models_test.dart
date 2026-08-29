import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/models/platform_ad_models.dart';

void main() {
  test('PlatformAdvertisementModel parses active ad payload', () {
    final model = PlatformAdvertisementModel.fromJson({
      'id': '550e8400-e29b-41d4-a716-446655440000',
      'title': 'Summer sale',
      'description': 'Great deals',
      'image_url': 'https://cdn.example.com/ad.jpg',
      'video_url': null,
      'target_url': 'https://example.com/promo',
      'placement': 'marketplace_page',
      'click_url': '/ads/click/550e8400-e29b-41d4-a716-446655440000?placement=marketplace_page',
    });

    expect(model.title, 'Summer sale');
    expect(model.placement, 'marketplace_page');
    expect(model.clickUrl, contains('/ads/click/'));
  });

  test('PlatformAdContext serializes marketplace and category params', () {
    const context = PlatformAdContext(
      marketplaceSlug: 'derb-ghallef',
      categorySlug: 'restaurants',
      city: 'Casablanca',
    );

    expect(context.toQueryParameters()['marketplace_slug'], 'derb-ghallef');
    expect(context.toQueryParameters()['category_slug'], 'restaurants');
    expect(context.toQueryParameters()['platform'], 'mobile');
  });
}
