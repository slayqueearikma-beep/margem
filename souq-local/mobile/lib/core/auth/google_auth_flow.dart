import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_session_completion.dart';
import '../models/auth_models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/google_sign_in_helper.dart';
import '../services/crash_reporting.dart';
import '../auth/google_auth_logging.dart';
import '../widgets/error_dialog.dart';
import '../../l10n/app_localizations.dart';

class GoogleAuthFlow {
  GoogleAuthFlow._();

  /// Returns `buyer` or `seller` for Google auth, or null when [accountType] is missing/unknown.
  static String? normalizeRegistrationAccountType(String accountType) {
    final raw = accountType.trim().toLowerCase();
    switch (raw) {
      case 'buyer':
      case 'customer':
        return 'buyer';
      case 'seller':
      case 'provider':
        return 'seller';
      default:
        return null;
    }
  }

  static Future<void> start({
    required BuildContext context,
    required WidgetRef ref,
    required String accountType,
    bool markOnboardingComplete = false,
    void Function(AuthSession session)? onNewSellerAccount,
  }) async {
    final l10n = context.l10n;
    final normalizedAccountType = normalizeRegistrationAccountType(accountType);
    if (normalizedAccountType == null) {
      if (!context.mounted) return;
      await showAppErrorDialog(
        context,
        title: l10n.somethingWentWrong,
        message: l10n.chooseAccountTypeSubtitle,
      );
      return;
    }

    final auth = ref.read(authServiceProvider);

    try {
      await apiServiceProvider.checkHealth();
      logGoogleAuth('API health OK');

      final idToken = await GoogleSignInHelper.signInAndGetIdToken();
      logGoogleAuth('Calling POST /auth/google');

      var result = await auth.signInWithGoogle(
        idToken: idToken,
        accountType: normalizedAccountType,
      );
      logGoogleAuth(
        'Backend response',
        'link=${result.linkRequired} mfa=${result.mfaRequired} session=${result.session != null}',
      );

      if (result.linkRequired) {
        if (!context.mounted) return;
        final password = await _promptLinkPassword(context, result.emailHint);
        if (password == null || password.isEmpty) return;
        result = await auth.linkGoogleAccount(
          idToken: idToken,
          password: password,
        );
      }

      if (result.mfaRequired) {
        if (!context.mounted) return;
        if (result.mfaToken == null || result.mfaToken!.isEmpty) {
          throw ApiException('Two-factor authentication is required.');
        }
        final code = await _promptMfaCode(context);
        if (code == null || code.isEmpty) return;
        final session = await auth.completeMfaLogin(
          mfaToken: result.mfaToken!,
          code: code,
        );
        if (!context.mounted) return;
        await _finish(
          context,
          ref,
          session,
          normalizedAccountType,
          onNewSellerAccount,
          markOnboardingComplete: markOnboardingComplete,
        );
        return;
      }

      final session = result.session;
      if (session == null) {
        throw ApiException(l10n.googleSignInFailed);
      }
      if (!context.mounted) return;
      await _finish(
        context,
        ref,
        session,
        normalizedAccountType,
        onNewSellerAccount,
        markOnboardingComplete: markOnboardingComplete,
      );
    } on GoogleSignInCancelledException {
      return;
    } on GoogleSignInNotConfiguredException {
      if (!context.mounted) return;
      await showAppErrorDialog(
        context,
        title: l10n.somethingWentWrong,
        message: l10n.googleSignInNotConfigured,
      );
    } on GoogleSignInNoIdTokenException {
      if (!context.mounted) return;
      await showAppErrorDialog(
        context,
        title: l10n.somethingWentWrong,
        message: l10n.googleSignInNoIdToken,
      );
    } on GoogleSignInDeveloperException {
      if (!context.mounted) return;
      await showAppErrorDialog(
        context,
        title: l10n.somethingWentWrong,
        message: l10n.googleSignInDeveloperError,
      );
    } on MfaRequiredException catch (mfa) {
      if (!context.mounted) return;
      final code = await _promptMfaCode(context);
      if (code == null || code.isEmpty) return;
      final session = await auth.completeMfaLogin(
        mfaToken: mfa.mfaToken,
        code: code,
      );
      if (!context.mounted) return;
      await _finish(
        context,
        ref,
        session,
        normalizedAccountType,
        onNewSellerAccount,
        markOnboardingComplete: markOnboardingComplete,
      );
    } on ApiException catch (error, stack) {
      logGoogleAuthError(error, stack, 'api:${error.statusCode ?? 0}');
      CrashReporting.recordError(
        error,
        stack,
        context: 'GoogleAuthFlow.api:${error.statusCode ?? 0}',
      );
      if (!context.mounted) return;
      await showAppErrorDialog(
        context,
        title: l10n.somethingWentWrong,
        message: _apiErrorMessage(error, l10n),
      );
    } on PlatformException catch (error, stack) {
      logGoogleAuthError(error, stack, 'platform:${error.code}');
      CrashReporting.recordError(
        error,
        stack,
        context: 'GoogleAuthFlow.platform:${error.code}',
      );
      if (!context.mounted) return;
      await showAppErrorDialog(
        context,
        title: l10n.somethingWentWrong,
        message: GoogleSignInHelper.userMessageForPlatformException(error, l10n),
      );
    } on Object catch (error, stack) {
      logGoogleAuthError(error, stack, 'unexpected');
      CrashReporting.recordError(
        error,
        stack,
        context: 'GoogleAuthFlow.start',
      );
      if (!context.mounted) return;
      await showAppErrorDialog(
        context,
        title: l10n.somethingWentWrong,
        message: _unexpectedErrorMessage(error, l10n),
      );
    }
  }

  static String _unexpectedErrorMessage(Object error, AppStrings l10n) {
    if (kDebugMode) {
      return '${l10n.googleSignInFailed}\n\nDebug: ${error.runtimeType}: $error';
    }
    return l10n.googleSignInFailed;
  }

  /// Maps unexpected Google auth errors to user-facing copy (for tests).
  @visibleForTesting
  static String messageForError(Object error, AppStrings l10n) {
    if (error is GoogleSignInNotConfiguredException) {
      return l10n.googleSignInNotConfigured;
    }
    if (error is GoogleSignInNoIdTokenException) {
      return l10n.googleSignInNoIdToken;
    }
    if (error is GoogleSignInDeveloperException) {
      return l10n.googleSignInDeveloperError;
    }
    if (error is ApiException) {
      return _apiErrorMessage(error, l10n);
    }
    return l10n.googleSignInFailed;
  }

  static String _apiErrorMessage(ApiException error, AppStrings l10n) {
    final message = error.message.trim();
    if (message.isEmpty) return l10n.googleSignInFailed;

    final lower = message.toLowerCase();
    if (error.statusCode == 401 &&
        (lower.contains('invalid google credential') ||
            lower.contains('google email address is not verified'))) {
      return l10n.googleSignInInvalidCredential;
    }
    if (error.statusCode == 503 && lower.contains('not configured')) {
      return l10n.googleSignInNotConfigured;
    }
    return message;
  }

  static Future<void> _finish(
    BuildContext context,
    WidgetRef ref,
    AuthSession session,
    String accountType,
    void Function(AuthSession session)? onNewSellerAccount, {
    bool markOnboardingComplete = false,
  }) async {
    final isSellerIntent = accountType == 'seller';
    final sellerOnboarding = isSellerIntent && !session.user.hasSellerProfile;

    if (sellerOnboarding && onNewSellerAccount != null) {
      onNewSellerAccount(session);
      return;
    }

    await completeAuthenticatedSessionFromContext(
      ref: ref,
      context: context,
      session: session,
      postAuthRouteOverride:
          sellerOnboarding ? '/onboarding/become-seller' : null,
      markOnboardingComplete: markOnboardingComplete,
    );
  }

  static Future<String?> _promptLinkPassword(
    BuildContext context,
    String? emailHint,
  ) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.googleLinkAccountTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.googleLinkAccountMessage(emailHint ?? l10n.email),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(labelText: l10n.password),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.googleLinkAccountAction),
          ),
        ],
      ),
    );
    controller.dispose();
    return password?.trim();
  }

  static Future<String?> _promptMfaCode(BuildContext context) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.twoFactorAuthTitle),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l10n.twoFactorAuthCodeLabel,
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.signupOtpVerify),
          ),
        ],
      ),
    );
    controller.dispose();
    return code;
  }
}
