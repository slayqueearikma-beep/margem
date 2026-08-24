import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/content_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../settings/language_settings_tile.dart';
import 'seller_account_provider.dart';

class SellerMoreTab extends ConsumerWidget {
  const SellerMoreTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final isGuest = session == null || session.isGuest;
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
            title: l10n.navBoost,
            subtitle: l10n.boostSubtitle,
            icon: Icons.rocket_launch_outlined,
            onTap: () => context.push('/seller/boost'),
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
          if (!isGuest) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final prefs = await ref.read(sharedPreferencesProvider.future);
                await ref.read(authServiceProvider).logout(prefs);
                await ref.read(appStorageProvider)?.logout();
                ref.invalidate(sellerAccountProvider);
                ref.read(userSessionProvider.notifier).state = null;
                ref.read(authSessionProvider.notifier).state = null;
                if (context.mounted) context.go('/login');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.error,
                side: BorderSide(color: context.colors.error),
              ),
              child: Text(l10n.logOut),
            ),
          ],
        ],
      );
  }
}
