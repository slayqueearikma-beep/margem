import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';

/// Maps unexpected auth failures to a user-visible message.
String authUnexpectedErrorMessage(Object error, AppStrings l10n) {
  if (kDebugMode) {
    debugPrint('Auth unexpected error (${error.runtimeType}): $error');
    final text = error.toString().trim();
    if (text.isNotEmpty) {
      return text;
    }
  }
  return l10n.serverUnreachable;
}
