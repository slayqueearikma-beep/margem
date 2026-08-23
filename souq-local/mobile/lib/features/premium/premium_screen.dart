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

final billingConfigProvider = FutureProvider.autoDispose<BillingConfigModel>((ref) {
  return apiServiceProvider.fetchBillingConfig();
});

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen>
    with WidgetsBindingObserver {
  String? _loadingPlanCode;
  var _interval = 'monthly';
  var _openingPortal = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAll();
    }
  }

  Future<void> _refreshAll() async {
    ref.invalidate(subscriptionPlansProvider);
    ref.invalidate(mySubscriptionProvider);
    ref.invalidate(billingConfigProvider);
  }

  Future<void> _upgrade(SubscriptionPlanModel plan, BillingConfigModel billing) async {
    final l10n = context.l10n;
    final session = ref.read(userSessionProvider);
    if (session == null || session.isGuest) {
      context.push('/login');
      return;
    }

    setState(() => _loadingPlanCode = plan.code);
    try {
      if (billing.selfServeEnabled) {
        final url = await apiServiceProvider.createCheckoutSession(
          planCode: plan.code,
          interval: _interval,
        );
        final uri = Uri.parse(url);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw ApiException('Could not open checkout');
        }
      } else if (!AppConfig.isProduction) {
        await apiServiceProvider.subscribe(plan.code);
        await _refreshAll();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.premiumActivated)));
        }
      }
    } on ApiException catch (error) {
      if (mounted) {
        await showAppErrorDialog(
          context,
          title: l10n.somethingWentWrong,
          message: error.message,
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPlanCode = null);
    }
  }

  Future<void> _openPortal() async {
    setState(() => _openingPortal = true);
    try {
      final url = await apiServiceProvider.createCustomerPortalSession();
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw ApiException('Could not open billing portal');
      }
    } on ApiException catch (error) {
      if (mounted) {
        await showAppErrorDialog(
          context,
          title: context.l10n.somethingWentWrong,
          message: error.message,
        );
      }
    } finally {
      if (mounted) setState(() => _openingPortal = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final subscriptionAsync = ref.watch(mySubscriptionProvider);
    final billingAsync = ref.watch(billingConfigProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.premium)),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(subscriptionPlansProvider),
        ),
        data: (plans) {
          if (plans.isEmpty) {
            return Center(child: Text(l10n.noPremiumPlans));
          }
          final active = subscriptionAsync.valueOrNull;
          final billing = billingAsync.valueOrNull;
          final selfServe = billing?.selfServeEnabled ?? !AppConfig.isProduction;

          return RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.workspace_premium_outlined,
                          color: AppColors.primary,
                          size: 36,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.premiumTitle,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.premiumSubtitle,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (active != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Chip(
                            avatar: const Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                            ),
                            label: Text(l10n.activePlan(active.plan.name)),
                          ),
                          if (active.cancelAtPeriodEnd)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.sm),
                              child: Text(
                                'Cancels at end of billing period',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          if (active.isStripe && billing?.stripeEnabled == true) ...[
                            const SizedBox(height: AppSpacing.sm),
                            OutlinedButton.icon(
                              onPressed: _openingPortal ? null : _openPortal,
                              icon: _openingPortal
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.receipt_long_outlined),
                              label: const Text('Manage billing & invoices'),
                            ),
                          ],
                        ] else if (session == null || session.isGuest) ...[
                          const SizedBox(height: AppSpacing.md),
                          TextButton.icon(
                            onPressed: () => context.push('/login'),
                            icon: const Icon(Icons.login),
                            label: Text(l10n.signInToSubscribe),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'monthly', label: Text('Monthly')),
                    ButtonSegment(value: 'yearly', label: Text('Yearly')),
                  ],
                  selected: {_interval},
                  onSelectionChanged: (values) {
                    setState(() => _interval = values.first);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                ...plans.map(
                  (plan) => _PlanCard(
                    plan: plan,
                    interval: _interval,
                    active: active?.plan.code == plan.code,
                    loading: _loadingPlanCode == plan.code,
                    selfServeEnabled: selfServe,
                    trialEnabled: billing?.trialEnabled ?? false,
                    onUpgrade: () {
                      if (billing != null) {
                        _upgrade(plan, billing);
                      }
                    },
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
    required this.interval,
    required this.active,
    required this.loading,
    required this.selfServeEnabled,
    required this.trialEnabled,
    required this.onUpgrade,
  });

  final SubscriptionPlanModel plan;
  final String interval;
  final bool active;
  final bool loading;
  final bool selfServeEnabled;
  final bool trialEnabled;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final yearly = interval == 'yearly';
    final price = yearly ? (plan.priceMadYearly ?? plan.priceMad * 10) : plan.priceMad;
    final periodLabel = yearly ? 'year' : '${plan.billingPeriodDays} ${l10n.days}';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (active)
                  const Icon(Icons.check_circle, color: AppColors.success),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              plan.description,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${price.toStringAsFixed(0)} MAD / $periodLabel',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (trialEnabled && plan.trialDays > 0 && !active)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  '${plan.trialDays}-day free trial',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (plan.features.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              ...plan.features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(Icons.check, color: AppColors.success, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(feature)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (!selfServeEnabled && !active)
              Text(
                l10n.premiumBillingUnavailable,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.3,
                ),
              )
            else
              FilledButton(
                onPressed: active || loading ? null : onUpgrade,
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(active ? l10n.currentPlan : 'Upgrade'),
              ),
          ],
        ),
      ),
    );
  }
}
