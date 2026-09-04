import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';

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
      scopes: const ['email', 'profile'],
      serverClientId: AppConfig.googleOAuthClientId.isNotEmpty
          ? AppConfig.googleOAuthClientId
          : null,
    );
    return _client!;
  }

  static Future<String> signInAndGetIdToken() async {
    if (AppConfig.googleOAuthClientId.isEmpty) {
      throw const GoogleSignInNotConfiguredException();
    }

    try {
      final account = await client.signIn();
      if (account == null) {
        throw const GoogleSignInCancelledException();
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleSignInNoIdTokenException();
      }
      return idToken;
    } on PlatformException catch (error) {
      if (error.code == 'sign_in_canceled' ||
          error.code == '12501' ||
          error.message?.toLowerCase().contains('cancel') == true) {
        throw const GoogleSignInCancelledException();
      }
      if (isDeveloperMisconfiguration(error)) {
        throw GoogleSignInDeveloperException(error.message ?? error.code);
      }
      rethrow;
    }
  }

  static bool isDeveloperMisconfiguration(PlatformException error) {
    const developerCodes = {'10', '12500', 'developer_error'};
    if (developerCodes.contains(error.code)) return true;
    final message = (error.message ?? '').toLowerCase();
    return message.contains('developer_error') ||
        message.contains('misconfigured') ||
        message.contains('invalid_client') ||
        message.contains('configuration');
  }

  static Future<void> signOut() async {
    try {
      await client.signOut();
    } on Object {
      // Best-effort — Dribex session is authoritative.
    }
  }
}
