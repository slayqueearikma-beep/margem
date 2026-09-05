import 'package:flutter/foundation.dart';

/// Debug logging for Google Sign-In troubleshooting (`adb logcat | grep DribexGoogleAuth`).
void logGoogleAuth(String message, [Object? detail]) {
  if (!kDebugMode) return;
  if (detail == null) {
    debugPrint('DribexGoogleAuth: $message');
    return;
  }
  debugPrint('DribexGoogleAuth: $message — $detail');
}

void logGoogleAuthError(Object error, [StackTrace? stack, String? step]) {
  final prefix = step == null ? 'DribexGoogleAuth' : 'DribexGoogleAuth[$step]';
  if (kDebugMode) {
    debugPrint('$prefix ERROR ${error.runtimeType}: $error');
    if (stack != null) {
      debugPrint(stack.toString().split('\n').take(8).join('\n'));
    }
  }
}
