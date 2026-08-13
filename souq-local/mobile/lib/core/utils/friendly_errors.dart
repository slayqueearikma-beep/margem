import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../services/api_service.dart';

/// Maps exceptions and API errors to user-safe messages in production.
String friendlyErrorMessage(Object error, {String fallback = 'Something went wrong'}) {
  if (error is ApiException) {
    final status = error.statusCode;
    if (status == 401) return 'Please sign in again to continue.';
    if (status == 403) return 'You do not have permission to do that.';
    if (status == 404) return 'We could not find what you were looking for.';
    if (status == 429) {
      return 'Too many requests. Please wait a moment and try again.';
    }
    if (status != null && status >= 500) {
      return kReleaseMode
          ? 'Our servers are having trouble. Please try again shortly.'
          : error.message;
    }
    if (!kReleaseMode) return error.message;
    if (error.message.length <= 120 && !_looksInternal(error.message)) {
      return error.message;
    }
    return fallback;
  }

  if (!kReleaseMode) {
    return error.toString();
  }
  return fallback;
}

bool _looksInternal(String message) {
  final lower = message.toLowerCase();
  return lower.contains('exception') ||
      lower.contains('stack') ||
      lower.contains('sql') ||
      lower.contains('traceback') ||
      lower.contains('socket') ||
      lower.contains('dart:');
}
