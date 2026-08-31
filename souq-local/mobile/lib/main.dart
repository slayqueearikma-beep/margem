import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/services/crash_reporting.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Config-only base URL — never render it in the UI.
  if (kDebugMode) {
    debugPrint('Dribex API_BASE_URL=${AppConfig.apiBaseUrl}');
  }

  // Release/production builds validate API_BASE_URL during AppConfig initialization.
  // Keep a defense-in-depth guard for profile/release where asserts are stripped.
  if (AppConfig.isProduction || kReleaseMode) {
    AppConfig.validateReleaseApiBaseUrl(
      AppConfig.apiBaseUrl,
      productionFlag: AppConfig.isProduction,
    );
  }

  await CrashReporting.ensureInitialized();

  FlutterError.onError = (details) {
    CrashReporting.recordFlutterError(details);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    CrashReporting.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(const ProviderScope(child: MarGemApp()));
}
