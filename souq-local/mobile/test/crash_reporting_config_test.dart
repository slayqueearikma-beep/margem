import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/services/crash_reporting.dart';

void main() {
  test('CrashReporting is configured when SENTRY_DSN dart-define is set', () {
    expect(
      CrashReporting.isConfigured,
      isTrue,
      reason: 'Run with --dart-define=SENTRY_DSN=... from mobile-production-dart-defines.sh',
    );
  });
}
