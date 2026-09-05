import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/features/search/search_price_input.dart';

void main() {
  group('parseSearchPriceInput', () {
    test('empty and whitespace return null', () {
      expect(parseSearchPriceInput(''), isNull);
      expect(parseSearchPriceInput('   '), isNull);
    });

    test('parses zero and decimals', () {
      expect(parseSearchPriceInput('0'), 0);
      expect(parseSearchPriceInput('99.5'), 99.5);
    });
  });

  group('formatSearchPriceInput', () {
    test('preserves decimals and formats integers without trailing zeros', () {
      expect(formatSearchPriceInput(null), '');
      expect(formatSearchPriceInput(100), '100');
      expect(formatSearchPriceInput(99.5), '99.5');
      expect(formatSearchPriceInput(0), '0');
    });
  });

  group('isSearchPriceRangeValid', () {
    test('allows open-ended and valid ranges', () {
      expect(isSearchPriceRangeValid(null, 100), isTrue);
      expect(isSearchPriceRangeValid(50, null), isTrue);
      expect(isSearchPriceRangeValid(50, 100), isTrue);
      expect(isSearchPriceRangeValid(99.5, 100), isTrue);
    });

    test('rejects min greater than max', () {
      expect(isSearchPriceRangeValid(500, 100), isFalse);
    });
  });
}
