import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/utils/friendly_errors.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../l10n/app_localizations.dart';
import '../legal/legal_config.dart';
import '../legal/legal_documents.dart';
import '../legal/legal_document_screen.dart';

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

final billingStatusProvider = FutureProvider.autoDispose<BillingStatusModel>((ref) {
  return apiServiceProvider.fetchBillingStatus();
});

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  String? _subscribingCode;
  bool _subscriptionTermsAccepted = false;

  Future<void> _subscribe(SubscriptionPlanModel plan) async {
    final l10n = context.l10n;
    final session = ref.read(userSessionProvider);
    if (session == null || session.isGuest) {
      context.push('/login');
      return;
    }
    if (!_subscriptionTermsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.completeRequiredStep)),
      );
      return;
    }

    final billing = ref.read(billingStatusProvider).valueOrNull;
    if (billing != null && !billing.selfServeEnabled) {
      await _contactSupport();
      return;
    }

    setState(() => _subscribingCode = plan.code);
    try {
      final locale = Localizations.localeOf(context).languageCode;
      final result = await apiServiceProvider.checkoutSubscription(
        plan.code,
        subscriptionTermsAccepted: true,
        acceptanceLanguage: locale,
      );
      if (!mounted) return;

      if (result.activated) {
        ref.invalidate(mySubscriptionProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.premiumActivated)),
        );
        return;
      }

      final checkoutUrl = result.checkoutUrl;
      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.premiumCheckoutOpened)),
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.premiumCheckoutFailed)),
          );
        }
      }
    } on ApiException catch (error) {
      if (mounted) {
        final message = error.statusCode == 503
            ? l10n.premiumBillingUnavailable
            : friendlyErrorMessage(error, l10n);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _subscribingCode = null);
    }
  }

  Future<void> _contactSupport() async {
    final uri = LegalConfig.supportMailto(subject: 'Dribex Premium');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final subscriptionAsync = ref.watch(mySubscriptionProvider);
    final billingAsync = ref.watch(billingStatusProvider);

    return BuyerScreenScaffold(
      appBar: BuyerAppBar(title: l10n.premium),
      body: plansAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colors.primary),
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
          final billing = billingAsync.valueOrNull;
          final selfServeEnabled = billing?.selfServeEnabled ?? true;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(subscriptionPlansProvider);
              ref.invalidate(mySubscriptionProvider);
              ref.invalidate(billingStatusProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              children: [
                _HeroCard(
                  activePlanName: active?.plan.displayName,
                  isGuest: session == null || session.isGuest,
                ),
                if (session != null && !session.isGuest) ...[
                  const SizedBox(height: AppSpacing.md),
                  CheckboxListTile(
                    value: _subscriptionTermsAccepted,
                    onChanged: (value) =>
                        setState(() => _subscriptionTermsAccepted = value ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('${l10n.signupTermsPrefix} '),
                        InkWell(
                          onTap: () => openLegalDocument(
                            context,
                            LegalDocumentId.subscriptionTerms,
                          ),
                          child: Text(
                            l10n.subscriptionTerms,
                            style: TextStyle(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        Text(l10n.signupTermsSuffix),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                ...plans.map(
                  (plan) => _PlanCard(
                    plan: plan,
                    active: active?.plan.code == plan.code,
                    loading: _subscribingCode == plan.code,
                    selfServeEnabled: selfServeEnabled,
                    onSubscribe: () => _subscribe(plan),
                    onContactSupport: _contactSupport,
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.isGuest,
    this.activePlanName,
  });

  final bool isGuest;
  final String? activePlanName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colors.primary.withValues(alpha: 0.14),
            context.colors.secondary.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadiusLg),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.colors.primaryMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: context.colors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.premiumTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.premiumSubtitle,
            style: TextStyle(
              color: context.colors.textSecondary,
              height: 1.35,
            ),
          ),
          if (activePlanName != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.colors.successMuted,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: context.colors.success,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.activePlan(activePlanName!),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ] else if (isGuest) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              onPressed: () => context.push('/login'),
              icon: const Icon(Icons.login_rounded),
              label: Text(l10n.signInToSubscribe),
            ),
          ],
        ],
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
    required this.onContactSupport,
  });

  final SubscriptionPlanModel plan;
  final bool active;
  final bool loading;
  final bool selfServeEnabled;
  final VoidCallback onSubscribe;
  final VoidCallback onContactSupport;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final borderColor = active ? context.colors.primary : context.colors.border;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadiusLg),
          border: Border.all(color: borderColor, width: active ? 2 : 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.displayName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  if (active)
                    Icon(
                      Icons.verified_rounded,
                      color: context.colors.success,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                plan.description,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${plan.priceMad.toStringAsFixed(0)} MAD',
                style: TextStyle(
                  color: context.colors.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              Text(
                '/ ${plan.billingPeriodDays} ${l10n.days}',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (plan.features.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                ...plan.features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: context.colors.success,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (!selfServeEnabled && !active)
                OutlinedButton(
                  onPressed: onContactSupport,
                  child: Text(l10n.premiumContactSupport),
                )
              else
                FilledButton(
                  onPressed: active || loading ? null : onSubscribe,
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(active ? l10n.currentPlan : l10n.subscribe),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
