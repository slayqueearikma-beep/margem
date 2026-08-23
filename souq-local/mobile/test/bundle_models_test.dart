import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/models/bundle_models.dart';

void main() {
  test('BundleResolveResultModel parses seller breakdown', () {
    final result = BundleResolveResultModel.fromJson({
      'marketplace': 'derb-ghallef',
      'template_slug': 'gaming-pc',
      'slots_requested': 2,
      'slots_matched': 2,
      'total_price_mad': 6700,
      'reference_price_mad': 7700,
      'savings_mad': 1000,
      'savings_percent': 13,
      'all_available': true,
      'missing_slots': [],
      'picks': [
        {
          'slot_key': 'cpu',
          'slot_label': 'CPU',
          'product_id': 'a',
          'product_name': 'Budget CPU',
          'price_mad': 2800,
          'image_url': '',
          'category_slug': 'electronics',
          'is_available': true,
          'stock_quantity': 2,
          'availability_note': '',
          'warranty_note': '6 months',
          'seller_id': 's1',
          'seller_name': 'Tech Beta',
          'seller_verified': false,
          'seller_rating': 4.5,
          'value_score': 0.8,
          'reference_price_mad': 3200,
        },
      ],
      'seller_breakdown': [
        {
          'seller_id': 's1',
          'seller_name': 'Tech Beta',
          'seller_verified': false,
          'seller_rating': 4.5,
          'subtotal_mad': 6700,
          'item_count': 2,
          'warranty_summary': '6 months',
          'items': [],
        },
      ],
    });

    expect(result.totalPriceMad, 6700);
    expect(result.savingsMad, 1000);
    expect(result.picks.first.warrantyNote, '6 months');
    expect(result.sellerBreakdown.first.sellerName, 'Tech Beta');
  });
}
