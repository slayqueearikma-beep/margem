import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/config/app_config.dart';

void main() {
  group('normalizeApiBaseUrl', () {
    test('inserts missing colon before common ports', () {
      expect(
        AppConfig.normalizeApiBaseUrl('http://192.168.11.1038000'),
        'http://192.168.11.103:8000',
      );
      expect(
        AppConfig.normalizeApiBaseUrl('http://10.0.2.28080'),
        'http://10.0.2.2:8080',
      );
    });

    test('preserves correctly formed URLs', () {
      expect(
        AppConfig.normalizeApiBaseUrl('http://192.168.11.103:8000'),
        'http://192.168.11.103:8000',
      );
      expect(
        AppConfig.normalizeApiBaseUrl('https://api.dribex.ma'),
        'https://api.dribex.ma',
      );
    });

    test('strips trailing slashes', () {
      expect(
        AppConfig.normalizeApiBaseUrl('http://192.168.11.103:8000/'),
        'http://192.168.11.103:8000',
      );
    });
  });

  group('isDevelopmentApiHost', () {
    test('flags emulator and loopback hosts', () {
      expect(AppConfig.isDevelopmentApiHost('10.0.2.2'), isTrue);
      expect(AppConfig.isDevelopmentApiHost('localhost'), isTrue);
      expect(AppConfig.isDevelopmentApiHost('127.0.0.1'), isTrue);
      expect(AppConfig.isDevelopmentApiHost('192.168.1.10'), isTrue);
      expect(AppConfig.isDevelopmentApiHost('api.dribex.ma'), isFalse);
      expect(AppConfig.isDevelopmentApiHost('100.80.43.124'), isTrue);
    });

    test('rejects Tailscale CGNAT hosts in release validation', () {
      expect(
        () => AppConfig.validateReleaseApiBaseUrl(
          'https://100.80.43.124',
          productionFlag: false,
        ),
        throwsStateError,
      );
    });
  });

  group('validateReleaseApiBaseUrl', () {
    test('accepts canonical production API URL', () {
      expect(
        AppConfig.validateReleaseApiBaseUrl(
          'https://api.dribex.ma',
          productionFlag: true,
        ),
        'https://api.dribex.ma',
      );
    });

    test('rejects development hosts in release validation', () {
      expect(
        () => AppConfig.validateReleaseApiBaseUrl(
          'http://10.0.2.2:8000',
          productionFlag: false,
        ),
        throwsStateError,
      );
      expect(
        () => AppConfig.validateReleaseApiBaseUrl(
          'http://localhost:8000',
          productionFlag: false,
        ),
        throwsStateError,
      );
      expect(
        () => AppConfig.validateReleaseApiBaseUrl(
          'http://192.168.1.10:8000',
          productionFlag: false,
        ),
        throwsStateError,
      );
    });

    test('rejects non-HTTPS URLs in release validation', () {
      expect(
        () => AppConfig.validateReleaseApiBaseUrl(
          'http://api.dribex.ma',
          productionFlag: false,
        ),
        throwsStateError,
      );
    });

    test('requires canonical production URL when productionFlag is true', () {
      expect(
        () => AppConfig.validateReleaseApiBaseUrl(
          'https://api-staging.dribex.ma',
          productionFlag: true,
        ),
        throwsStateError,
      );
    });
  });
}
