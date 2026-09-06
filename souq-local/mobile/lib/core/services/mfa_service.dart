import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_models.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Authenticated MFA enrollment and management via existing backend endpoints.
class MfaService {
  MfaService(this._api);

  final ApiService _api;

  Future<MfaEnrollResult> startEnrollment() async {
    final response = await _api.postEmpty('/auth/mfa/enroll', auth: true);
    return MfaEnrollResult.fromJson(response);
  }

  Future<List<String>> confirmEnrollment(String code) async {
    final response = await _api.postJson(
      '/auth/mfa/confirm',
      {'code': code.trim()},
      auth: true,
    );
    final raw = response['recovery_codes'] as List<dynamic>? ?? const [];
    return raw.map((item) => item.toString()).toList();
  }

  Future<void> disable({required String password, required String code}) {
    return _api.postVoid(
      '/auth/mfa/disable',
      {
        'password': password,
        'code': code.trim(),
      },
      auth: true,
    );
  }
}

final mfaServiceProvider = Provider<MfaService>((ref) {
  return MfaService(apiServiceProvider);
});

/// Refresh `/auth/me` and update the in-memory auth session user snapshot.
Future<AuthUser> refreshAuthSessionUser(WidgetRef ref) async {
  final auth = ref.read(authServiceProvider);
  final user = await auth.fetchCurrentUser();
  final session = ref.read(authSessionProvider);
  if (session != null) {
    ref.read(authSessionProvider.notifier).state = AuthSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      user: user,
      expiresIn: session.expiresIn,
    );
  }
  return user;
}
