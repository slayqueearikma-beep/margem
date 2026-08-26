import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'api_service.dart';
import 'media_url_resolver.dart';
import 'secure_http_client.dart';

class VideoUploadResult {
  const VideoUploadResult({
    required this.publicUrl,
    required this.durationSeconds,
    required this.contentType,
  });

  final String publicUrl;
  final double durationSeconds;
  final String contentType;
}

/// Uploads images and videos via the API presign → PUT flow.
class UploadService {
  UploadService(this._api);

  final ApiService _api;
  static const _uploadTimeout = Duration(seconds: 60);
  static const _videoUploadTimeout = Duration(minutes: 3);
  static const maxVideoDurationSeconds = 59.0;
  final http.Client _uploadClient = createSecureHttpClient();

  Future<String> uploadImage(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) {
      throw ApiException('Image must be 8 MB or smaller');
    }
    final filename = file.name.isNotEmpty ? file.name : 'upload.jpg';
    final contentType = _contentTypeFor(filename);

    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _uploadOnce(
          bytes: bytes,
          filename: filename,
          contentType: contentType,
        );
      } on ApiException catch (error) {
        lastError = error;
        // Retry once on transient storage / network failures.
        final retryable = error.statusCode == null ||
            error.statusCode == 503 ||
            error.statusCode == 502 ||
            error.message.toLowerCase().contains('timeout') ||
            error.message.toLowerCase().contains('unavailable');
        if (!retryable || attempt == 1) rethrow;
      }
    }
    throw lastError is ApiException
        ? lastError
        : ApiException('Image upload failed');
  }

  Future<String> _uploadOnce({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    final presign = await _api.postJson(
      '/uploads/presign',
      {'filename': filename, 'content_type': contentType},
      auth: true,
    );

    final uploadUrl = presign['upload_url'] as String?;
    final publicUrl = presign['public_url'] as String?;
    if (uploadUrl == null ||
        uploadUrl.isEmpty ||
        publicUrl == null ||
        publicUrl.isEmpty) {
      throw ApiException('Storage did not return upload URLs');
    }

    UploadUrlGuard.assertTrustedPresignUploadUrl(uploadUrl);

    final resolvedUpload = UploadUrlGuard.resolveUploadUri(uploadUrl);
    final isLocalApiUpload = resolvedUpload.path.startsWith('/uploads/');
    final response = await _uploadClient
        .put(
          resolvedUpload,
          headers: {
            'Content-Type': contentType,
            'x-ms-blob-type': 'BlockBlob',
            if (isLocalApiUpload) ..._api.authHeaders,
          },
          body: bytes,
        )
        .timeout(
          _uploadTimeout,
          onTimeout: () => throw ApiException('Image upload timed out'),
        );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Image upload to storage failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    if (!isLocalApiUpload) {
      await _api.postJson(
        '/uploads/validate',
        {'public_url': publicUrl, 'content_type': contentType},
        auth: true,
      );
    }

    return MediaUrlResolver.resolve(publicUrl);
  }

  Future<VideoUploadResult> uploadVideo(
    XFile file, {
    required double durationSeconds,
  }) async {
    if (durationSeconds < 0 || durationSeconds >= 60) {
      throw ApiException('Video must be less than 1 minute');
    }

    final bytes = await file.readAsBytes();
    if (bytes.length > 50 * 1024 * 1024) {
      throw ApiException('Video must be 50 MB or smaller');
    }
    final filename = file.name.isNotEmpty ? file.name : 'video.mp4';
    final contentType = _videoContentTypeFor(filename);

    final presign = await _api.postJson(
      '/uploads/presign',
      {
        'filename': filename,
        'content_type': contentType,
        'purpose': 'video',
      },
      auth: true,
    );

    final uploadUrl = presign['upload_url'] as String?;
    final publicUrl = presign['public_url'] as String?;
    if (uploadUrl == null ||
        uploadUrl.isEmpty ||
        publicUrl == null ||
        publicUrl.isEmpty) {
      throw ApiException('Storage did not return upload URLs');
    }

    UploadUrlGuard.assertTrustedPresignUploadUrl(uploadUrl);

    final resolvedUpload = UploadUrlGuard.resolveUploadUri(uploadUrl);
    final isLocalApiUpload = resolvedUpload.path.startsWith('/uploads/');
    final response = await _uploadClient
        .put(
          resolvedUpload,
          headers: {
            'Content-Type': contentType,
            'x-ms-blob-type': 'BlockBlob',
            if (isLocalApiUpload) ..._api.authHeaders,
          },
          body: bytes,
        )
        .timeout(
          _videoUploadTimeout,
          onTimeout: () => throw ApiException('Video upload timed out'),
        );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Video upload to storage failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final validated = await _api.postJson(
      '/uploads/validate-video',
      {
        'public_url': publicUrl,
        'content_type': contentType,
        'duration_seconds': durationSeconds,
      },
      auth: true,
    );
    final measured = (validated['duration_seconds'] as num?)?.toDouble();
    if (measured == null || measured >= 60) {
      throw ApiException('Video must be less than 1 minute');
    }

    return VideoUploadResult(
      publicUrl: MediaUrlResolver.resolve(publicUrl),
      durationSeconds: measured,
      contentType: contentType,
    );
  }

  String _contentTypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  String _videoContentTypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.mov')) return 'video/quicktime';
    return 'video/mp4';
  }
}

final uploadServiceProvider = Provider<UploadService>((ref) {
  return UploadService(apiServiceProvider);
});
