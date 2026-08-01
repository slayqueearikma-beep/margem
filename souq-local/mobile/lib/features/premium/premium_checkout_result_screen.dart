import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/error_dialog.dart';
import '../../l10n/app_localizations.dart';
import 'premium_screen.dart';

class PremiumCheckoutResultScreen extends ConsumerStatefulWidget {
  const PremiumCheckoutResultScreen({
    super.key,
    required this.success,
    this.sessionId,
  });

  final bool success;
  final String? sessionId;

  @override
  ConsumerState<PremiumCheckoutResultScreen> createState() =>
      _PremiumCheckoutResultScreenState();
}

class _PremiumCheckoutResultScreenState
    extends ConsumerState<PremiumCheckoutResultScreen> {
  var _syncing = false;
  var _synced = false;

  @override
  void initState() {
    super.initState();
    if (widget.success) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncSubscription());
    }
  }

  Future<void> _syncSubscription() async {
    if (_syncing || _synced) return;
    setState(() => _syncing = true);
    try {
      await apiServiceProvider.syncBillingSubscription(
        checkoutSessionId: widget.sessionId,
      );
      ref.invalidate(mySubscriptionProvider);
      ref.invalidate(billingConfigProvider);
      if (mounted) setState(() => _synced = true);
    } on ApiException catch (error) {
      if (mounted) {
        await showAppErrorDialog(
          context,
          title: context.l10n.somethingWentWrong,
          message: error.message,
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.premium)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.success ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 72,
              color: widget.success
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              widget.success
                  ? l10n.premiumActivated
                  : 'Checkout was canceled',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.success && _syncing) ...[
              const SizedBox(height: AppSpacing.lg),
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.sm),
              const Text('Activating your subscription...'),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () => context.go('/premium'),
              child: Text(widget.success ? 'View my plan' : 'Back to plans'),
            ),
          ],
        ),
      ),
    );
  }
}
