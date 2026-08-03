import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/app_back_handler.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_brand_logo.dart';
import '../../core/widgets/network_image_view.dart';
import '../../l10n/app_localizations.dart';
import '../settings/language_settings_tile.dart';
import 'seller_account_provider.dart';
import 'seller_navigation.dart';

class SellerDrawer extends ConsumerWidget {
  const SellerDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final account = ref.watch(sellerAccountProvider).valueOrNull;
    final stats = account?.stats;
    final profile = account?.profile;

    return Drawer(
      backgroundColor: AppColors.beigeLight,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppBrandLogo.forContext(
                    AppBrandContext.compactBranding,
                    size: AppBrandSizes.drawerHeader,
                  ),
                  const SizedBox(height: 16),
                  if (profile != null)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.cream,
                          child: ClipOval(
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: NetworkImageView(
                                url: profile.logoImageUrl.isNotEmpty
                                    ? profile.logoImageUrl
                                    : profile.coverImageUrl,
                                placeholderIcon: Icons.storefront_rounded,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              if (stats != null)
                                Text(
                                  l10n.reviewsCount(stats.reviewCount),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerItem(
                    icon: Icons.dashboard_outlined,
                    label: l10n.navDashboard,
                    onTap: () => _goTab(context, ref, 0),
                  ),
                  _DrawerItem(
                    icon: Icons.handyman_outlined,
                    label: l10n.navServices,
                    onTap: () => _goTab(context, ref, 1),
                  ),
                  _DrawerItem(
                    icon: Icons.event_note_outlined,
                    label: l10n.navBookings,
                    onTap: () => _goTab(context, ref, 2),
                  ),
                  _DrawerItem(
                    icon: Icons.chat_bubble_outline,
                    label: l10n.messages,
                    badge: stats != null && stats.inquiryCount > 0
                        ? '${stats.inquiryCount}'
                        : null,
                    onTap: () => _push(context, '/seller/messages'),
                  ),
                  _DrawerItem(
                    icon: Icons.rate_review_outlined,
                    label: l10n.reviews,
                    onTap: () => _push(context, '/seller/reviews'),
                  ),
                  _DrawerItem(
                    icon: Icons.payments_outlined,
                    label: l10n.earnings,
                    comingSoon: true,
                    onTap: () {},
                  ),
                  _DrawerItem(
                    icon: Icons.query_stats_outlined,
                    label: l10n.analytics,
                    onTap: () => _push(context, '/seller/analytics'),
                  ),
                  _DrawerItem(
                    icon: Icons.photo_library_outlined,
                    label: l10n.gallery,
                    onTap: () => _push(context, '/seller/products'),
                  ),
                  _DrawerItem(
                    icon: Icons.business_outlined,
                    label: l10n.businessInfo,
                    onTap: () => _push(context, '/seller/profile'),
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: l10n.settings,
                    onTap: () => _push(context, '/seller/settings'),
                  ),
                  _DrawerItem(
                    icon: Icons.help_outline,
                    label: l10n.helpSupport,
                    onTap: () => _push(context, '/seller/settings'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  final storage = ref.read(appStorageProvider);
                  await storage?.saveAppMode(AppMode.buyer);
                  if (context.mounted) context.go('/buyer/home');
                },
                child: Text(l10n.switchToBuyerMode),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _goTab(BuildContext context, WidgetRef ref, int index) {
    Navigator.pop(context);
    ref.read(sellerTabIndexProvider.notifier).state = index;
    final path = GoRouterState.of(context).matchedLocation;
    if (path != '/seller/dashboard') {
      context.go('/seller/dashboard');
    }
  }

  void _push(BuildContext context, String route) {
    Navigator.pop(context);
    context.push(route);
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.comingSoon = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.lavender),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: comingSoon
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.lavenderMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                context.l10n.comingSoon,
                style: const TextStyle(
                  color: AppColors.lavender,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : badge != null
              ? CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.danger,
                  child: Text(
                    badge!,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                )
              : null,
      onTap: comingSoon ? null : onTap,
    );
  }
}
