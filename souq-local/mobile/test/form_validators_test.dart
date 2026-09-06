import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/validation/form_validators.dart';

void main() {
  test('isValidEmail accepts well-formed addresses', () {
    expect(FormValidators.isValidEmail('user@example.com'), isTrue);
    expect(FormValidators.isValidEmail('bad'), isFalse);
  });

  test('isValidPassword enforces complexity rules', () {
    expect(FormValidators.isValidPassword('SecurePass1'), isTrue);
    expect(FormValidators.isValidPassword('password'), isFalse);
    expect(FormValidators.isValidPassword('short1A'), isFalse);
  });
}
