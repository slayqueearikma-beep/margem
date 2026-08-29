import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/providers/subscription_providers.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/utils/friendly_errors.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/discovery_platform_notice.dart';
import '../../core/widgets/margem_app_bar.dart';
import '../../l10n/app_localizations.dart';

final advertisingPackagesProvider =
    FutureProvider.autoDispose<List<AdvertisingPackageModel>>((ref) {
  return apiServiceProvider.fetchAdvertisingPackages();
});

class SellerBoostScreen extends ConsumerStatefulWidget {
  const SellerBoostScreen({super.key, this.checkoutNotice});

  final String? checkoutNotice;

  @override
  ConsumerState<SellerBoostScreen> createState() => _SellerBoostScreenState();
}

class _SellerBoostScreenState extends ConsumerState<SellerBoostScreen> {
  String? _purchasingCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleCheckoutNotice());
  }

  void _handleCheckoutNotice() {
    final notice = widget.checkoutNotice;
    if (notice == null || !mounted) return;
    final l10n = context.l10n;
    final message = switch (notice) {
      'success' => l10n.boostActivated,
      'cancelled' => l10n.boostCheckoutFailed,
      _ => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _purchase(AdvertisingPackageModel package) async {
    final l10n = context.l10n;
    final monetization = ref.read(monetizationStatusProvider).valueOrNull;
    if (monetization != null && !monetization.billingSelfServeEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.premiumBillingUnavailable)),
      );
      return;
    }

    setState(() => _purchasingCode = package.code);
    try {
      final result = await apiServiceProvider.checkoutAdvertising(package.code);
      if (!mounted) return;

      if (result.activated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.boostActivated)),
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
              SnackBar(content: Text(l10n.boostCheckoutOpened)),
            );
          }
          if (result.paymentId != null) {
            await _pollPaymentConfirmation(result.paymentId!);
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.boostCheckoutFailed)),
          );
        }
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(error, l10n))),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasingCode = null);
    }
  }

  Future<void> _pollPaymentConfirmation(String paymentId) async {
    final l10n = context.l10n;
    for (var attempt = 0; attempt < 12; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      try {
        final payment = await apiServiceProvider.fetchPlatformPayment(paymentId);
        if (payment.status == 'success') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.boostActivated)),
            );
          }
          return;
        }
        if (payment.status == 'failed' || payment.status == 'cancelled') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.boostCheckoutFailed)),
            );
          }
          return;
        }
      } on ApiException {
        // Keep polling while payment is pending.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final packagesAsync = ref.watch(advertisingPackagesProvider);

    return Scaffold(
      appBar: MarGemAppBar(semanticLabel: l10n.navBoost),
      body: packagesAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colors.primary),
        ),
        error: (error, _) => AsyncErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(advertisingPackagesProvider),
        ),
        data: (packages) {
          if (packages.isEmpty) {
            return Center(child: Text(l10n.noBoostPackages));
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(advertisingPackagesProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              children: [
                Text(
                  l10n.boostTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.boostSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                DiscoveryPlatformNotice(message: l10n.dribexServicePaymentNotice),
                const SizedBox(height: AppSpacing.md),
                ...packages.map(
                  (package) => Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            package.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(package.description),
                          const SizedBox(height: 8),
                          Text(
                            l10n.boostDurationDays(package.durationDays),
                            style: TextStyle(color: context.colors.textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Text(
                                '${package.priceMad.toStringAsFixed(0)} MAD',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: context.colors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const Spacer(),
                              FilledButton(
                                onPressed: _purchasingCode == package.code
                                    ? null
                                    : () => _purchase(package),
                                child: _purchasingCode == package.code
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: context.colors.onPrimary,
                                        ),
                                      )
                                    : Text(l10n.purchaseBoost),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
