import '../config/app_config.dart';
import '../services/api_service.dart';
import '../../l10n/app_localizations.dart';

/// Maps raw API errors to user-facing copy (no validation regexes in production).
String friendlyErrorMessage(Object error, AppStrings l10n) {
  if (error is! ApiException) {
    return AppConfig.isProduction ? l10n.somethingWentWrong : error.toString();
  }

  final message = error.message.trim();
  final lower = message.toLowerCase();

  if (error.statusCode == 404 ||
      lower == 'not found' ||
      lower.contains('city not found')) {
    return l10n.contentNotFound;
  }
  if (error.statusCode == 503 && lower.contains('billing')) {
    return l10n.premiumBillingUnavailable;
  }
  if (error.statusCode == 429 || lower.contains('rate limit')) {
    return l10n.tooManyRequests;
  }
  if (error.statusCode == 422 ||
      lower.contains('should match pattern') ||
      lower.contains('validation error')) {
    return l10n.requestCouldNotBeProcessed;
  }
  if (message.isEmpty || AppConfig.isProduction) {
    return l10n.somethingWentWrong;
  }
  return message;
}
