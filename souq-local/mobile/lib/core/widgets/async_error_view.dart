import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../utils/friendly_errors.dart';
import '../theme/theme_context.dart';
import '../../l10n/app_localizations.dart';

/// User-friendly error state for failed API loads (no dev instructions in production).
class AsyncErrorView extends StatelessWidget {
  const AsyncErrorView({
    super.key,
    required this.message,
    this.onRetry,
  }) : error = null;

  const AsyncErrorView._fromError({
    super.key,
    required this.error,
    this.onRetry,
  }) : message = null;

  final String? message;
  final Object? error;
  final VoidCallback? onRetry;

  factory AsyncErrorView.fromError(Object error, {VoidCallback? onRetry}) {
    return AsyncErrorView._fromError(error: error, onRetry: onRetry);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayMessage = error != null
        ? friendlyErrorMessage(error!, context.l10n)
        : (message?.isNotEmpty == true
            ? message!
            : context.l10n.somethingWentWrong);
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
                    displayMessage,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.colors.textSecondary,
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
