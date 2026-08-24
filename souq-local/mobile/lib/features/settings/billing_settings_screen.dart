import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers/subscription_providers.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/utils/friendly_errors.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../core/widgets/marketplace_actions.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/strings/app_strings.dart';

class BillingSettingsScreen extends ConsumerStatefulWidget {
  const BillingSettingsScreen({super.key});

  @override
  ConsumerState<BillingSettingsScreen> createState() =>
      _BillingSettingsScreenState();
}

class _BillingSettingsScreenState extends ConsumerState<BillingSettingsScreen> {
  var _cancelling = false;

  Future<void> _cancelSubscription() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelSubscriptionTitle),
        content: Text(l10n.cancelSubscriptionBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await apiServiceProvider.cancelSubscription();
      invalidateSubscriptionProviders(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cancelSubscriptionScheduled)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e, l10n))),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subscriptionAsync = ref.watch(mySubscriptionProvider);
    final paymentsAsync = ref.watch(myPlatformPaymentsProvider);
    final billingAsync = ref.watch(billingStatusProvider);

    return BuyerScreenScaffold(
      appBar: BuyerAppBar(title: l10n.billingSettingsTitle),
      body: RefreshIndicator(
        onRefresh: () async => invalidateSubscriptionProviders(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          children: [
            Text(
              l10n.billingSettingsSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            subscriptionAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => AsyncErrorView.fromError(
                error,
                onRetry: () => ref.invalidate(mySubscriptionProvider),
              ),
              data: (subscription) => _SubscriptionSection(
                subscription: subscription,
                cancelling: _cancelling,
                onCancel: subscription != null &&
                        !subscription.cancelAtPeriodEnd
                    ? _cancelSubscription
                    : null,
                onViewPlans: () => context.push('/premium'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            billingAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (billing) {
                if (billing.provider == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    '${l10n.billingProviderLabel}: ${billing.provider}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.colors.textTertiary,
                        ),
                  ),
                );
              },
            ),
            paymentsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => AsyncErrorView.fromError(
                error,
                onRetry: () => ref.invalidate(myPlatformPaymentsProvider),
              ),
              data: (payments) => _PaymentHistorySection(payments: payments),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionSection extends StatelessWidget {
  const _SubscriptionSection({
    required this.subscription,
    required this.cancelling,
    required this.onCancel,
    required this.onViewPlans,
  });

  final SubscriptionModel? subscription;
  final bool cancelling;
  final VoidCallback? onCancel;
  final VoidCallback onViewPlans;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    return MarketSectionCard(
      title: l10n.subscriptionManagementTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subscription == null) ...[
            Text(
              l10n.noActiveSubscription,
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onViewPlans,
              icon: const Icon(Icons.workspace_premium_outlined),
              label: Text(l10n.viewPremiumPlans),
            ),
          ] else ...[
            Text(
              '${subscription!.plan.displayName} · ${subscription!.status}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${l10n.subscriptionRenewsUntil}: ${_formatApiDate(subscription!.currentPeriodEnd)}',
              style: TextStyle(color: colors.textSecondary),
            ),
            if (subscription!.cancelAtPeriodEnd) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.cancelSubscriptionScheduled,
                style: TextStyle(color: colors.textSecondary),
              ),
            ] else if (onCancel != null) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: cancelling ? null : onCancel,
                child: cancelling
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                        ),
                      )
                    : Text(l10n.cancelSubscriptionTitle),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              onPressed: onViewPlans,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: Text(l10n.viewPremiumPlans),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentHistorySection extends StatelessWidget {
  const _PaymentHistorySection({required this.payments});

  final List<PlatformPaymentModel> payments;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    return MarketSectionCard(
      title: l10n.paymentHistoryTitle,
      child: payments.isEmpty
          ? Text(
              l10n.noPaymentHistory,
              style: TextStyle(color: colors.textSecondary),
            )
          : Column(
              children: payments.map((payment) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _paymentStatusIcon(payment.status),
                      color: _paymentStatusColor(colors, payment.status),
                    ),
                    title: Text(
                      '${payment.serviceCode} · ${payment.amountMad.toStringAsFixed(0)} ${payment.currency}',
                      style: TextStyle(color: colors.textPrimary),
                    ),
                    subtitle: Text(
                      '${_formatPaymentStatus(l10n, payment.status)} · ${_formatApiDate(payment.paidAt ?? payment.createdAt)}',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    trailing: Text(
                      payment.provider,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.textTertiary,
                          ),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

String _formatApiDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

IconData _paymentStatusIcon(String status) {
  return switch (status.toLowerCase()) {
    'success' => Icons.check_circle_outline,
    'failed' => Icons.error_outline,
    'cancelled' => Icons.cancel_outlined,
    _ => Icons.schedule_outlined,
  };
}

Color _paymentStatusColor(AppSemanticColors colors, String status) {
  return switch (status.toLowerCase()) {
    'success' => colors.success,
    'failed' => colors.error,
    'cancelled' => colors.textTertiary,
    _ => colors.warning,
  };
}

String _formatPaymentStatus(AppStrings l10n, String status) {
  return switch (status.toLowerCase()) {
    'success' => l10n.paymentStatusSuccess,
    'failed' => l10n.paymentStatusFailed,
    'cancelled' => l10n.paymentStatusCancelled,
    'pending' => l10n.paymentStatusPending,
    _ => status,
  };
}
