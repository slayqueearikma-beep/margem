import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';

/// User-friendly error state for failed API loads (no dev instructions in production).
class AsyncErrorView extends StatelessWidget {
  const AsyncErrorView({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  factory AsyncErrorView.fromError(Object error, {VoidCallback? onRetry, BuildContext? context}) {
    String text;
    if (error is ApiException) {
      text = error.message;
      if (context != null) {
        text = _localizeApiMessage(context.l10n, error);
      }
    } else {
      text = AppConfig.isProduction ? '' : error.toString();
    }
    return AsyncErrorView(message: text, onRetry: onRetry);
  }

  static String _localizeApiMessage(AppStrings l10n, ApiException error) {
    final msg = error.message;
    if (msg.contains('App storage is not ready')) {
      return l10n.appStorageNotReady;
    }
    if (msg.contains('API database is unavailable')) {
      return l10n.apiUnavailable;
    }
    if (msg.startsWith('Request timed out')) {
      final match = RegExp(r'after (\d+)s').firstMatch(msg);
      final seconds = int.tryParse(match?.group(1) ?? '') ?? 30;
      return l10n.requestTimeout(seconds);
    }
    if (msg.contains('Cannot reach the server') ||
        msg.contains('Cannot reach the API')) {
      return l10n.connectionError;
    }
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.lg,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    context.l10n.somethingWentWrong,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    message.isEmpty
                        ? context.l10n.somethingWentWrong
                        : message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant(context),
                      height: 1.4,
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.tryAgain),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
