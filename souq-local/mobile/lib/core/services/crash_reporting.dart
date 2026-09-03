import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Production crash reporting via Sentry when `SENTRY_DSN` is provided.
///
/// Build with: `--dart-define=SENTRY_DSN=https://...@...`
/// Without a DSN, errors are logged locally in debug and dropped in release
/// (never crash-loop).
class CrashReporting {
  CrashReporting._();

  static const String _sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  static const bool _verifyTest = bool.fromEnvironment(
    'SENTRY_VERIFY_TEST',
    defaultValue: false,
  );

  static bool get isConfigured => _sentryDsn.isNotEmpty;
  static bool _sentryReady = false;

  static void _configureOptions(SentryFlutterOptions options) {
    options.dsn = _sentryDsn;
    options.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
    options.sendDefaultPii = false;
    options.environment = kReleaseMode ? 'production' : 'debug';
    options.beforeSend = (event, hint) => _scrubEvent(event);
  }

  /// Bootstraps Sentry (when configured) and runs [appRunner] inside Sentry's zone.
  static Future<void> bootstrap(Future<void> Function() appRunner) async {
    if (!isConfigured) {
      if (kDebugMode) {
        debugPrint('CrashReporting: no SENTRY_DSN — local logging only');
      }
      await appRunner();
      return;
    }

    await SentryFlutter.init(
      _configureOptions,
      appRunner: () async {
        _sentryReady = true;
        if (kDebugMode) {
          debugPrint('CrashReporting: Sentry initialized');
        }
        if (_verifyTest) {
          await _sendVerifyEvent();
        }
        await appRunner();
      },
    );
  }

  static Future<void> _sendVerifyEvent() async {
    await Sentry.captureException(
      StateError('dribex_sentry_verify'),
      stackTrace: StackTrace.current,
      withScope: (scope) {
        scope.level = SentryLevel.error;
        scope.setTag('verify', 'true');
      },
    );
    // Give the SDK time to flush before the user backgrounds the app.
    await Future<void>.delayed(const Duration(seconds: 3));
  }

  static void recordFlutterError(FlutterErrorDetails details) {
    recordError(
      details.exception,
      details.stack,
      fatal: true,
      context: details.context?.toString(),
    );
  }

  static void recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? context,
  }) {
    final summary = error.runtimeType.toString();
    if (kDebugMode) {
      debugPrint(
        'CrashReporting[${fatal ? 'fatal' : 'error'}] $summary'
        '${context == null ? '' : ' context=$context'}',
      );
      if (stack != null) {
        debugPrint(stack.toString().split('\n').take(12).join('\n'));
      }
    }
    if (_sentryReady) {
      Sentry.captureException(
        error,
        stackTrace: stack,
        withScope: (scope) {
          scope.level = fatal ? SentryLevel.fatal : SentryLevel.error;
          if (context != null) {
            scope.setTag(
              'error_context',
              context.substring(0, context.length.clamp(0, 80)),
            );
          }
        },
      );
    }
  }

  static SentryEvent? _scrubEvent(SentryEvent event) {
    final sensitive = RegExp(
      r'(password|token|authorization|secret|api[_-]?key|refresh)',
      caseSensitive: false,
    );
    final headers = event.request?.headers;
    if (headers != null) {
      for (final key in List<String>.from(headers.keys)) {
        if (sensitive.hasMatch(key)) {
          headers[key] = '[redacted]';
        }
      }
    }
    final url = event.request?.url;
    if (url != null && sensitive.hasMatch(url)) {
      event.request?.url = '[redacted]';
    }
    return event;
  }
}
