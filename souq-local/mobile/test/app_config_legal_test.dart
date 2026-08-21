import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/config/app_config.dart';
import 'package:souq_local/core/services/app_storage.dart';
import 'package:souq_local/l10n/strings/app_strings.dart';
import 'package:souq_local/l10n/strings/app_strings_ar.dart';

void main() {
  test('legal document URLs always use authoritative French path', () {
    expect(AppConfig.legalDocumentUrl('terms'), contains('/legal/fr/terms'));
    expect(AppConfig.legalDocumentUrl('privacy'), contains('/legal/fr/privacy'));
    expect(AppConfig.legalContentLanguageCode, 'fr');
  });

  test('default language code is Arabic', () {
    expect(AppStorage.defaultLanguageCode, 'ar');
  });

  test('unknown locale falls back to Arabic strings', () {
    final strings = AppStrings.forLocale('xx');
    expect(strings, isA<AppStringsAr>());
  });
}
