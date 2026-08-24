import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:souq_local/core/services/app_storage.dart';

void main() {
  test('guestFavoritesMigrationPayload omits empty product_id for seller favorites', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = AppStorage(prefs);
    await storage.addGuestFavoriteItem(
      GuestFavoriteItem(
        productId: '',
        sellerId: '00000000-0000-4000-8000-000000000001',
        name: 'Shop',
        price: 0,
        imageUrl: '',
      ),
    );

    final payload = guestFavoritesMigrationPayload(storage);
    expect(payload, hasLength(1));
    expect(payload.first.containsKey('product_id'), isFalse);
    expect(payload.first['seller_id'], '00000000-0000-4000-8000-000000000001');
  });
}
