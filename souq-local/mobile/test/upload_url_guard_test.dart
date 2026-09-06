import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/services/media_url_resolver.dart';
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

    test('allows API storage proxy upload path on equivalent dev host', () {
      expect(
        () => UploadUrlGuard.assertAllowedUploadUrl(
          'http://localhost:8000/uploads/storage/token123',
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

    test('trusts server-validated MinIO presign host', () {
      expect(
        () => UploadUrlGuard.assertTrustedPresignUploadUrl(
          'http://minio:9000/dribex-private/uploads/user/file.jpg?X-Amz-Signature=abc',
        ),
        returnsNormally,
      );
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

  group('MediaUrlResolver', () {
    test('rewrites localhost media URLs to configured API host', () {
      expect(
        MediaUrlResolver.resolve(
          'http://localhost:8000/media/dribex-products/products/user/photo.jpg',
        ),
        'http://10.0.2.2:8000/media/dribex-products/products/user/photo.jpg',
      );
    });
  });
}
