import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/navigation/app_back_handler.dart';
import 'package:souq_local/core/navigation/margem_navigation_leading.dart';

void main() {
  group('margemFallbackBackLocation', () {
    test('returns buyer home for marketplace detail routes', () {
      expect(margemFallbackBackLocation('/product/s1/p1'), '/buyer/home');
      expect(margemFallbackBackLocation('/seller/abc'), '/buyer/home');
      expect(margemFallbackBackLocation('/favorites'), '/buyer/home');
      expect(margemFallbackBackLocation('/community'), '/buyer/home');
      expect(margemFallbackBackLocation('/search'), '/buyer/home');
      expect(margemFallbackBackLocation('/messages'), '/buyer/home');
    });

    test('returns seller dashboard for seller management routes', () {
      expect(margemFallbackBackLocation('/seller/products'), '/seller/dashboard');
      expect(margemFallbackBackLocation('/seller/products/new'), '/seller/dashboard');
      expect(margemFallbackBackLocation('/seller/services/s1'), '/seller/dashboard');
      expect(margemFallbackBackLocation('/seller/settings'), '/seller/dashboard');
    });

    test('returns null for root routes', () {
      expect(margemFallbackBackLocation('/buyer/home'), isNull);
      expect(margemFallbackBackLocation('/seller/dashboard'), isNull);
      expect(margemFallbackBackLocation('/login'), isNull);
      expect(margemFallbackBackLocation('/onboarding'), isNull);
      expect(margemFallbackBackLocation(''), isNull);
    });
  });

  group('isAppRootLocation alignment', () {
    test('root paths never receive a fallback destination', () {
      for (final path in [
        '/buyer/home',
        '/seller/dashboard',
        '/login',
        '/splash',
        '/language',
        '/onboarding',
      ]) {
        expect(isAppRootLocation(path), isTrue);
        expect(margemFallbackBackLocation(path), isNull);
      }
    });
  });
}
