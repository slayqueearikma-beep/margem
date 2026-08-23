import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/config/app_config.dart';

void main() {
  test('demo data is disabled without explicit DEMO_FALLBACK', () {
    expect(AppConfig.allowDemoData, isFalse);
  });

  test('non-production legal URLs are served from the API', () {
    expect(AppConfig.privacyPolicyUrl, contains('/legal/privacy.html'));
    expect(AppConfig.termsOfServiceUrl, contains('/legal/terms.html'));
    expect(AppConfig.cookiePolicyUrl, contains('/legal/cookies.html'));
  });
}
