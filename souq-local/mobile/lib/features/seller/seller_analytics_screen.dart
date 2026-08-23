import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import '../../l10n/app_localizations.dart';
import 'seller_account_provider.dart';
import 'seller_widgets.dart';

class SellerAnalyticsScreen extends ConsumerWidget {
  const SellerAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final accountAsync = ref.watch(sellerAccountProvider);
    final analyticsAsync = ref.watch(sellerAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.analytics)),
      body: accountAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AsyncErrorView(
          message:
              error is ApiException ? error.message : l10n.somethingWentWrong,
          onRetry: () => ref.invalidate(sellerAccountProvider),
        ),
        data: (account) {
          final stats = account.stats;
          final analytics = analyticsAsync.valueOrNull;
          final profileViews =
              analytics?.profileViewCount ?? stats.profileViewCount;
          final inquiryCount = analytics?.inquiryCount ?? stats.inquiryCount;
          final favoriteCount =
              analytics?.favoriteCount ?? stats.favoriteCount;
          final contactClicks =
              analytics?.contactClickCount ?? stats.contactClickCount;
          final followers = analytics?.followerEstimate ?? 0;
          final reviewCount = analytics?.reviewCount ?? stats.reviewCount;
          final avgResponse =
              analytics?.avgResponseMinutes ?? stats.avgResponseMinutes;
          final verification =
              analytics?.verificationStatus ?? stats.verificationStatus;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(sellerAccountProvider);
              ref.invalidate(sellerAnalyticsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              children: [
                SellerHeroMetricCard(
                  title: l10n.profileViews,
                  value: '$profileViews',
                  deltaLabel: profileViews > 0 ? '+18%' : '—',
                  positive: profileViews > 0,
                  child: SellerMiniSparkline(
                    values: List<double>.generate(
                      7,
                      (i) => (profileViews / 7) * (0.8 + i * 0.05),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    SellerMetricTile(
                      label: l10n.inquiries,
                      value: '$inquiryCount',
                      icon: Icons.chat_bubble_outline,
                    ),
                    SellerMetricTile(
                      label: l10n.favorites,
                      value: '$favoriteCount',
                      icon: Icons.favorite_border,
                    ),
                    SellerMetricTile(
                      label: l10n.contactClicksLabel,
                      value: '$contactClicks',
                      icon: Icons.touch_app_outlined,
                    ),
                    SellerMetricTile(
                      label: l10n.followers,
                      value: '$followers',
                      icon: Icons.people_outline,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _AnalyticsRow(label: l10n.reviews, value: '$reviewCount'),
                _AnalyticsRow(
                  label: l10n.averageResponse,
                  value: l10n.avgResponseMinutes(avgResponse),
                ),
                _AnalyticsRow(label: l10n.verification, value: verification),
                _AnalyticsRow(
                  label: l10n.products,
                  value: '${stats.productCount}',
                ),
                _AnalyticsRow(
                  label: l10n.services,
                  value: '${stats.serviceCount}',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AnalyticsRow extends StatelessWidget {
  const _AnalyticsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
