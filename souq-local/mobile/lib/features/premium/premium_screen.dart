import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../core/widgets/error_dialog.dart';
import '../../l10n/app_localizations.dart';

final subscriptionPlansProvider =
    FutureProvider.autoDispose<List<SubscriptionPlanModel>>((ref) {
  return apiServiceProvider.fetchSubscriptionPlans();
});

final mySubscriptionProvider =
    FutureProvider.autoDispose<SubscriptionModel?>((ref) {
  final session = ref.watch(userSessionProvider);
  if (session == null || session.isGuest) return Future.value(null);
  return apiServiceProvider.fetchMySubscription();
});

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  String? _subscribingCode;

  Future<void> _subscribe(SubscriptionPlanModel plan) async {
    final l10n = context.l10n;
    final session = ref.read(userSessionProvider);
    if (session == null || session.isGuest) {
      context.push('/login');
      return;
    }
    setState(() => _subscribingCode = plan.code);
    try {
      await apiServiceProvider.subscribe(plan.code);
      ref.invalidate(mySubscriptionProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.premiumActivated)));
      }
    } on ApiException catch (error) {
      if (mounted) {
        final message = error.statusCode == 503
            ? l10n.premiumBillingUnavailable
            : error.message;
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: message);
      }
    } finally {
      if (mounted) setState(() => _subscribingCode = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final subscriptionAsync = ref.watch(mySubscriptionProvider);

    return BuyerScreenScaffold(
      appBar: BuyerAppBar(title: l10n.premium),
      body: plansAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.lavender),
        ),
        error: (error, _) => AsyncErrorView.fromError(error,
            onRetry: () => ref.invalidate(subscriptionPlansProvider)),
        data: (plans) {
          if (plans.isEmpty) {
            return BuyerEmptyState(
              icon: Icons.workspace_premium_outlined,
              title: l10n.noPremiumPlans,
            );
          }
          final active = subscriptionAsync.valueOrNull;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(subscriptionPlansProvider);
              ref.invalidate(mySubscriptionProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              children: [
                BuyerSurfaceCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.accentMuted(context),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            color: AppColors.lavender,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.premiumTitle,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.premiumSubtitle,
                          style: TextStyle(color: AppColors.onSurfaceVariant(context)),
                        ),
                        if (active != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.successMuted,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.success,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(l10n.activePlan(active.plan.name)),
                              ],
                            ),
                          ),
                        ] else if (session == null || session.isGuest) ...[
                          const SizedBox(height: AppSpacing.md),
                          TextButton.icon(
                            onPressed: () => context.push('/login'),
                            icon: const Icon(Icons.login_rounded),
                            label: Text(l10n.signInToSubscribe),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ...plans.map(
                  (plan) => _PlanCard(
                    plan: plan,
                    active: active?.plan.code == plan.code,
                    loading: _subscribingCode == plan.code,
                    selfServeEnabled: !AppConfig.isProduction,
                    onSubscribe: () => _subscribe(plan),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.active,
    required this.loading,
    required this.selfServeEnabled,
    required this.onSubscribe,
  });

  final SubscriptionPlanModel plan;
  final bool active;
  final bool loading;
  final bool selfServeEnabled;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: BuyerSurfaceCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (active)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                plan.description,
                style: TextStyle(color: AppColors.onSurfaceVariant(context)),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${plan.priceMad.toStringAsFixed(0)} MAD / ${plan.billingPeriodDays} ${l10n.days}',
                style: const TextStyle(
                  color: AppColors.lavender,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (plan.features.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              ...plan.features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(Icons.check,
                          color: AppColors.success, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(feature)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (!selfServeEnabled && !active) ...[
              Text(
                l10n.premiumBillingUnavailable,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () async {
                  final uri = Uri(
                    scheme: 'mailto',
                    path: 'support@margem.ma',
                    queryParameters: {
                      'subject': 'MarGem Premium',
                    },
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                child: Text(l10n.premiumContactSupport),
              ),
            ] else
              FilledButton(
                onPressed: active || loading ? null : onSubscribe,
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(active ? l10n.currentPlan : l10n.subscribe),
              ),
          ],
        ),
      ),
    ),
    );
  }
}
