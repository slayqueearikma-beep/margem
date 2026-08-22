import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_storage.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/content_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../settings/language_settings_tile.dart';
import 'seller_account_provider.dart';

class SellerMoreTab extends ConsumerWidget {
  const SellerMoreTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final account = ref.watch(sellerAccountProvider).valueOrNull;
    final stats = account?.stats;
    final recentBadge =
        stats != null && stats.recentReviewCount > 0 ? '${stats.recentReviewCount}' : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        8,
        AppSpacing.screenHorizontal,
        100,
      ),
      children: [
          DashboardMenuTile(
            title: l10n.analytics,
            subtitle: l10n.analyticsSub,
            icon: Icons.query_stats_outlined,
            onTap: () => context.push('/seller/analytics'),
          ),
          DashboardMenuTile(
            title: l10n.productManagement,
            subtitle: l10n.productManagementSub,
            icon: Icons.inventory_2_outlined,
            onTap: () => context.push('/seller/products'),
          ),
          DashboardMenuTile(
            title: l10n.profileManagement,
            subtitle: l10n.profileManagementSub,
            icon: Icons.business_outlined,
            onTap: () => context.push('/seller/profile'),
          ),
          DashboardMenuTile(
            title: l10n.reviews,
            subtitle: l10n.reviewsSub,
            icon: Icons.rate_review_outlined,
            badge: recentBadge,
            onTap: () => context.push('/seller/reviews'),
          ),
          DashboardMenuTile(
            title: l10n.messages,
            subtitle: l10n.messagesSub,
            icon: Icons.chat_bubble_outline,
            onTap: () => context.push('/seller/messages'),
          ),
          DashboardMenuTile(
            title: l10n.previewStorefront,
            subtitle: l10n.previewStorefrontSub,
            icon: Icons.visibility_outlined,
            onTap: () {
              final id = account?.profile.id;
              if (id != null) context.push('/seller/$id');
            },
          ),
          DashboardMenuTile(
            title: l10n.premium,
            subtitle: l10n.premiumUpgradeSub,
            icon: Icons.workspace_premium_outlined,
            onTap: () => context.push('/premium'),
          ),
          DashboardMenuTile(
            title: l10n.accountSecurity,
            subtitle: l10n.accountSecuritySub,
            icon: Icons.security_outlined,
            onTap: () => context.push('/seller/settings'),
          ),
          const LanguageSettingsTile(),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              final storage = ref.read(appStorageProvider);
              await storage?.saveAppMode(AppMode.buyer);
              if (context.mounted) context.go('/buyer/home');
            },
            child: Text(l10n.switchToBuyerMode),
          ),
        ],
      );
  }
}
