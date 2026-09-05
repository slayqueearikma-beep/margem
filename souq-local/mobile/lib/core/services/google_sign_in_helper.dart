import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';
import '../auth/google_auth_logging.dart';
import '../../l10n/strings/app_strings.dart';

class GoogleSignInCancelledException implements Exception {
  const GoogleSignInCancelledException();
}

class GoogleSignInNotConfiguredException implements Exception {
  const GoogleSignInNotConfiguredException();
}

class GoogleSignInNoIdTokenException implements Exception {
  const GoogleSignInNoIdTokenException();
}

class GoogleSignInDeveloperException implements Exception {
  const GoogleSignInDeveloperException([this.detail = '']);

  final String detail;
}

class GoogleSignInHelper {
  GoogleSignInHelper._();

  static GoogleSignIn? _client;

  static GoogleSignIn get client {
    _client ??= GoogleSignIn(
      scopes: const ['email', 'profile', 'openid'],
      serverClientId: AppConfig.googleOAuthClientId.isNotEmpty
          ? AppConfig.googleOAuthClientId
          : null,
      forceCodeForRefreshToken: true,
    );
    return _client!;
  }

  static Future<String> signInAndGetIdToken() async {
    if (AppConfig.googleOAuthClientId.isEmpty) {
      throw const GoogleSignInNotConfiguredException();
    }

    logGoogleAuth(
      'Starting sign-in',
      'serverClientId=${AppConfig.googleOAuthClientId.substring(0, 8)}…',
    );

    try {
      // Clear stale Google sessions that can return accounts without ID tokens.
      await client.signOut();

      final account = await client.signIn();
      if (account == null) {
        throw const GoogleSignInCancelledException();
      }
      logGoogleAuth('Account selected', account.email);

      final auth = await account.authentication;
      final idToken = auth.idToken;
      logGoogleAuth(
        'Authentication result',
        'idToken=${idToken == null ? 'null' : '${idToken.length} chars'}',
      );
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleSignInNoIdTokenException();
      }
      return idToken;
    } on PlatformException catch (error) {
      logGoogleAuthError(error, StackTrace.current, 'platform');
      if (error.code == 'sign_in_canceled' ||
          error.code == '12501' ||
          error.message?.toLowerCase().contains('cancel') == true) {
        throw const GoogleSignInCancelledException();
      }
      if (isDeveloperMisconfiguration(error)) {
        throw GoogleSignInDeveloperException(error.message ?? error.code);
      }
      rethrow;
    } on GoogleSignInCancelledException {
      rethrow;
    } on GoogleSignInNoIdTokenException {
      rethrow;
    } on GoogleSignInNotConfiguredException {
      rethrow;
    } on GoogleSignInDeveloperException {
      rethrow;
    } on Object catch (error, stack) {
      logGoogleAuthError(error, stack, 'signIn');
      rethrow;
    }
  }

  static bool isDeveloperMisconfiguration(PlatformException error) {
    const developerCodes = {
      '10',
      '12500',
      'developer_error',
      'sign_in_failed',
    };
    if (developerCodes.contains(error.code)) return true;
    final message = (error.message ?? '').toLowerCase();
    return message.contains('developer_error') ||
        message.contains('misconfigured') ||
        message.contains('invalid_client') ||
        message.contains('configuration') ||
        message.contains('serverclientid') ||
        message.contains('12500');
  }

  static String userMessageForPlatformException(
    PlatformException error,
    AppStrings l10n,
  ) {
    if (isDeveloperMisconfiguration(error)) {
      return l10n.googleSignInDeveloperError;
    }
    if (error.code == '7' ||
        (error.message ?? '').toLowerCase().contains('network')) {
      return l10n.serverUnreachable;
    }
    final code = error.code.trim();
    if (code.isNotEmpty) {
      return '${l10n.googleSignInFailed} (code: $code)';
    }
    return l10n.googleSignInFailed;
  }

  static Future<void> signOut() async {
    try {
      await client.signOut();
    } on Object {
      // Best-effort — Dribex session is authoritative.
    }
  }
}
