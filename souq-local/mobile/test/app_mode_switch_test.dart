import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:souq_local/core/services/app_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('App mode switching', () {
    late AppStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = AppStorage(prefs);
    });

    test('seller with profile can switch buyer then seller repeatedly', () async {
      final session = UserSession(
        name: 'Seller User',
        email: 'seller@example.com',
        accountType: AccountType.seller,
        sellerId: 'seller-123',
      );
      await storage.saveSession(session);

      await storage.saveAppMode(AppMode.seller);
      expect(storage.getAppMode(session: session), AppMode.seller);
      expect(storage.homeRouteFor(session), '/seller/dashboard');

      await storage.saveAppMode(AppMode.buyer);
      expect(storage.getAppMode(session: session), AppMode.buyer);
      expect(storage.homeRouteFor(session), '/buyer/home');

      await storage.saveAppMode(AppMode.seller);
      expect(storage.getAppMode(session: session), AppMode.seller);
      expect(storage.homeRouteFor(session), '/seller/dashboard');

      await storage.saveAppMode(AppMode.buyer);
      expect(storage.getAppMode(session: session), AppMode.buyer);
    });

    test('buyer without seller profile cannot open seller shell', () async {
      final session = UserSession(
        name: 'Buyer User',
        email: 'buyer@example.com',
        accountType: AccountType.buyer,
      );
      await storage.saveSession(session);
      await storage.saveAppMode(AppMode.seller);

      expect(storage.getAppMode(session: session), AppMode.buyer);
      expect(storage.homeRouteFor(session), '/buyer/home');
    });

    test('seller profile persists across buyer mode preference', () async {
      final session = UserSession(
        name: 'Dual User',
        email: 'dual@example.com',
        accountType: AccountType.seller,
        sellerId: 'seller-456',
        businessName: 'My Shop',
      );
      await storage.saveSession(session);
      await storage.saveAppMode(AppMode.buyer);

      final restored = storage.getSession();
      expect(restored?.hasSellerProfile, isTrue);
      expect(restored?.sellerId, 'seller-456');
      expect(restored?.businessName, 'My Shop');
      expect(storage.getAppMode(session: restored), AppMode.buyer);
    });
  });
}
