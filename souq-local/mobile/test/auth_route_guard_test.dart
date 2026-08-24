import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/navigation/auth_route_guard.dart';

void main() {
  group('isAuthProtectedLocation', () {
    test('allows guest favorites and profile', () {
      expect(isAuthProtectedLocation('/favorites'), isFalse);
      expect(isAuthProtectedLocation('/profile'), isFalse);
    });

    test('blocks guest seller management and premium', () {
      expect(isAuthProtectedLocation('/seller/dashboard'), isTrue);
      expect(isAuthProtectedLocation('/premium'), isTrue);
      expect(isAuthProtectedLocation('/settings/billing'), isTrue);
    });

    test('blocks guest messaging and community channels', () {
      expect(isAuthProtectedLocation('/messages/inbox'), isTrue);
      expect(isAuthProtectedLocation('/community/channels/casablanca'), isTrue);
      expect(
        isAuthProtectedLocation('/marketplace/derb-ghallef/community'),
        isTrue,
      );
    });
  });
}
