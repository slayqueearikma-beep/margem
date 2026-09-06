import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_models.dart';
import 'api_service.dart';
import 'google_sign_in_helper.dart';

/// Handles registration, login, refresh rotation, and secure JWT persistence.
class AuthService {
  AuthService(this._api);

  final ApiService _api;
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  String? _accessToken;
  String? _refreshToken;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _cachedAuthUserKey = 'cached_auth_user';

  String? get accessToken => _accessToken;

  void bindApi({Future<void> Function()? onSessionExpired}) {
    _api.onTokenRefresh = refreshAccessToken;
    _api.onSessionExpired = onSessionExpired;
    _syncTokenProvider();
  }

  Future<void> loadStoredToken() async {
    _accessToken = await _storage.read(key: _accessTokenKey);
    _refreshToken = await _storage.read(key: _refreshTokenKey);
    _syncTokenProvider();
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    required String accountType,
    required String displayName,
    required String signupProof,
  }) async {
    final response = await _api.postJson('/auth/register', {
      'email': email,
      'password': password,
      'account_type': accountType,
      'display_name': displayName,
      'signup_proof': signupProof,
    });
    return _saveSession(AuthSession.fromJson(response));
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.postJson('/auth/login', {
      'email': email,
      'password': password,
    });
    if (response['mfa_required'] == true) {
      throw MfaRequiredException(
        mfaToken: response['mfa_token'] as String? ?? '',
      );
    }
    return _saveSession(AuthSession.fromJson(response));
  }

  Future<AuthSession> completeMfaLogin({
    required String mfaToken,
    required String code,
  }) async {
    final response = await _api.postJson('/auth/mfa/login', {
      'mfa_token': mfaToken,
      'code': code.trim(),
    });
    return _saveSession(AuthSession.fromJson(response));
  }

  Future<GoogleSignInResult> signInWithGoogle({
    required String idToken,
    String accountType = 'buyer',
    String displayName = '',
  }) async {
    final response = await _api.postJson('/auth/google', {
      'id_token': idToken,
      'account_type': accountType,
      if (displayName.isNotEmpty) 'display_name': displayName,
    });
    if (response['link_required'] != true &&
        response['mfa_required'] != true &&
        response['user'] is! Map<String, dynamic>) {
      throw ApiException(
        'Google sign-in response was incomplete. Try again.',
      );
    }
    try {
      final result = GoogleSignInResult.fromJson(response);
      if (result.session != null) {
        await _saveSession(result.session!);
      }
      return result;
    } on Object catch (error) {
      throw ApiException(
        'Could not read Google sign-in response. Try again.',
        statusCode: 200,
      );
    }
  }

  Future<GoogleSignInResult> linkGoogleAccount({
    required String idToken,
    required String password,
  }) async {
    final response = await _api.postJson('/auth/google/link', {
      'id_token': idToken,
      'password': password,
    });
    final result = GoogleSignInResult.fromJson(response);
    if (result.session != null) {
      await _saveSession(result.session!);
    }
    return result;
  }

  Future<AuthUser> fetchCurrentUser() async {
    final me = await _api.getJson('/auth/me', auth: true);
    return AuthUser.fromJson(me);
  }

  /// Returns `true` when refreshed, `false` when auth is invalid, `null` on transient errors.
  Future<bool?> refreshAccessToken() async {
    final refresh = _refreshToken;
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final response = await _api.postJson('/auth/refresh', {
        'refresh_token': refresh,
      });
      await _saveSession(AuthSession.fromJson(response));
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        _accessToken = null;
        _refreshToken = null;
        await _storage.delete(key: _accessTokenKey);
        await _storage.delete(key: _refreshTokenKey);
        _syncTokenProvider();
        return false;
      }
      return null;
    } on Object {
      return null;
    }
  }

  /// Returns true when stored credentials can access the API (refresh if needed).
  Future<bool> ensureSessionValid() async {
    await loadStoredToken();
    if ((_accessToken == null || _accessToken!.isEmpty) &&
        (_refreshToken == null || _refreshToken!.isEmpty)) {
      return false;
    }
    try {
      await _api.getJson('/auth/me', auth: true);
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        final refreshed = await refreshAccessToken();
        return refreshed == true;
      }
      // Transient API errors should not wipe a valid stored session.
      return true;
    } on Object {
      return true;
    }
  }

  Future<void> persistToken(SharedPreferences prefs) async {
    if (_accessToken != null) {
      await _storage.write(key: _accessTokenKey, value: _accessToken!);
    }
    if (_refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: _refreshToken!);
    }
  }

  Future<void> logout(SharedPreferences prefs) async {
    if (_refreshToken != null) {
      try {
        await _api.postJson('/auth/logout', {'refresh_token': _refreshToken!});
      } on Object {
        // Best-effort server revocation.
      }
    }
    _accessToken = null;
    _refreshToken = null;
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _cachedAuthUserKey);
    _syncTokenProvider();
    await GoogleSignInHelper.signOut();
  }

  Future<void> deleteAccount({required String password}) async {
    await _api.deleteJson(
      '/auth/me',
      {'password': password, 'confirmation': 'DELETE'},
      auth: true,
    );
    _accessToken = null;
    _refreshToken = null;
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _cachedAuthUserKey);
    _syncTokenProvider();
  }

  Future<AuthSession?> restoreAuthSession() async {
    await loadStoredToken();
    if ((_accessToken == null || _accessToken!.isEmpty) &&
        (_refreshToken == null || _refreshToken!.isEmpty)) {
      return null;
    }
    try {
      final me = await _api.getJson('/auth/me', auth: true);
      final user = AuthUser.fromJson(me);
      await _cacheAuthUser(user);
      return AuthSession(
        accessToken: _accessToken!,
        refreshToken: _refreshToken ?? '',
        user: user,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        final refreshed = await refreshAccessToken();
        if (refreshed == true) {
          try {
            final me = await _api.getJson('/auth/me', auth: true);
            final user = AuthUser.fromJson(me);
            await _cacheAuthUser(user);
            return AuthSession(
              accessToken: _accessToken!,
              refreshToken: _refreshToken ?? '',
              user: user,
            );
          } on Object {
            return null;
          }
        }
        return null;
      }
      // Transient API errors should not block offline session restore.
      return _offlineSession();
    } on Object {
      return _offlineSession();
    }
  }

  Future<AuthSession?> _offlineSession() async {
    if (_accessToken == null || _accessToken!.isEmpty) return null;
    final raw = await _storage.read(key: _cachedAuthUserKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final user = AuthUser.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      return AuthSession(
        accessToken: _accessToken!,
        refreshToken: _refreshToken ?? '',
        user: user,
      );
    } on Object {
      return null;
    }
  }

  Future<void> _cacheAuthUser(AuthUser user) async {
    await _storage.write(
      key: _cachedAuthUserKey,
      value: jsonEncode({
        'id': user.id,
        'email': user.email,
        'account_type': user.accountType,
        'display_name': user.displayName,
        'profile_photo_url': user.profilePhotoUrl,
        'has_seller_profile': user.hasSellerProfile,
        'legal_acceptance_complete': user.legalAcceptanceComplete,
        'pending_legal_policies': user.pendingLegalPolicies,
        'mfa_enabled': user.mfaEnabled,
        'plus_plus_active': user.plusPlusActive,
        'show_plus_badge': user.showPlusBadge,
        'promotional_ads_suppressed': user.promotionalAdsSuppressed,
        'ads_enabled': user.adsEnabled,
      }),
    );
  }

  Future<AuthSession> _saveSession(AuthSession session) async {
    _accessToken = session.accessToken;
    _refreshToken = session.refreshToken;
    await _storage.write(key: _accessTokenKey, value: _accessToken!);
    await _storage.write(key: _refreshTokenKey, value: _refreshToken!);
    await _cacheAuthUser(session.user);
    _syncTokenProvider();
    return session;
  }

  void _syncTokenProvider() {
    _api.tokenProvider = () => _accessToken;
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(apiServiceProvider);
});

final authSessionProvider = StateProvider<AuthSession?>((ref) => null);

class MfaRequiredException implements Exception {
  MfaRequiredException({required this.mfaToken});

  final String mfaToken;
}
