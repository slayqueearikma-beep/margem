import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/services/secure_http_client.dart';

void main() {
  group('UploadUrlGuard', () {
    test('allows API-local upload path on equivalent dev host', () {
      expect(
        () => UploadUrlGuard.assertAllowedUploadUrl(
          'http://localhost:8000/uploads/local/token123',
          apiBaseUrl: 'http://10.0.2.2:8000',
        ),
        returnsNormally,
      );
    });

    test('rewrites localhost upload URL to configured API host', () {
      final resolved = UploadUrlGuard.resolveUploadUri(
        'http://localhost:8000/uploads/local/token123',
        apiBaseUrl: 'http://10.0.2.2:8000',
      );
      expect(resolved.toString(), 'http://10.0.2.2:8000/uploads/local/token123');
    });

    test('allows azure blob uploads', () {
      expect(
        () => UploadUrlGuard.assertAllowedUploadUrl(
          'https://account.blob.core.windows.net/media/user/file.jpg?sas=1',
          apiBaseUrl: 'https://api.example.com',
          isProduction: true,
        ),
        returnsNormally,
      );
    });

    test('rejects unknown production upload host', () {
      expect(
        () => UploadUrlGuard.assertAllowedUploadUrl(
          'https://evil.example/upload',
          apiBaseUrl: 'https://api.example.com',
          isProduction: true,
        ),
        throwsArgumentError,
      );
    });
  });
}
