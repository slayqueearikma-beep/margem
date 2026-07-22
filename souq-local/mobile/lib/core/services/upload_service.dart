import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'api_service.dart';

/// Uploads images via the API presign → PUT flow.
class UploadService {
  UploadService(this._api);

  final ApiService _api;
  static const _uploadTimeout = Duration(seconds: 60);

  Future<String> uploadImage(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) {
      throw ApiException('Image must be 8 MB or smaller');
    }
    final filename = file.name.isNotEmpty ? file.name : 'upload.jpg';
    final contentType = _contentTypeFor(filename);

    final presign = await _api.postJson(
      '/uploads/presign',
      {'filename': filename, 'content_type': contentType},
      auth: true,
    );

    final uploadUrl = presign['upload_url'] as String;
    final publicUrl = presign['public_url'] as String;

    final response = await http
        .put(
          Uri.parse(uploadUrl),
          headers: {
            'Content-Type': contentType,
            'x-ms-blob-type': 'BlockBlob',
          },
          body: bytes,
        )
        .timeout(
          _uploadTimeout,
          onTimeout: () => throw ApiException('Image upload timed out'),
        );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Image upload failed (${response.statusCode})');
    }

    return publicUrl;
  }

  String _contentTypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}

final uploadServiceProvider = Provider<UploadService>((ref) {
  return UploadService(apiServiceProvider);
});
