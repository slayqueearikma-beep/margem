import 'package:flutter_test/flutter_test.dart';

import 'package:souq_local/core/ads/platform_ad_constants.dart';
import 'package:souq_local/core/models/models.dart';
import 'package:souq_local/core/services/api_service.dart';

void main() {
  test('PlatformAdvertisementModel parses public ad payload', () {
    final model = PlatformAdvertisementModel.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'title': 'Launch promo',
      'description': 'Limited offer',
      'image_url': 'https://cdn.example.com/ad.jpg',
      'video_url': 'https://cdn.example.com/ad.mp4',
      'target_url': 'https://example.com/promo',
      'placement': PlatformAdPlacements.fullPage,
      'click_url': '/ads/click/11111111-1111-1111-1111-111111111111?placement=full_page',
    });

    expect(model.title, 'Launch promo');
    expect(model.placement, PlatformAdPlacements.fullPage);
    expect(model.videoUrl, 'https://cdn.example.com/ad.mp4');
  });

  test('buildAdClickUrl appends platform and click_key', () {
    final ad = PlatformAdvertisementModel.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'title': 'Promo',
      'image_url': 'https://cdn.example.com/ad.jpg',
      'target_url': 'https://example.com/promo',
      'placement': PlatformAdPlacements.fullPage,
      'click_url': '/ads/click/11111111-1111-1111-1111-111111111111?placement=full_page',
    });

    final url = apiServiceProvider.buildAdClickUrl(
      ad: ad,
      clickKey: 'click-abc',
    );

    expect(url, contains('platform=mobile'));
    expect(url, contains('click_key=click-abc'));
    expect(url, contains('placement=full_page'));
  });
}
