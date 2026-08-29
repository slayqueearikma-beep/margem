import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/subscription_providers.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/network_image_view.dart';
import '../../l10n/app_localizations.dart';
import 'seller_account_provider.dart';

class SellerDrawer extends ConsumerWidget {
  const SellerDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final isGuest = session == null || session.isGuest;
    final account = ref.watch(sellerAccountProvider).valueOrNull;
    final stats = account?.stats;
    final profile = account?.profile;
    return Drawer(
      backgroundColor: context.colors.surfaceVariant,
      shape: RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: profile != null
                  ? Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: context.colors.surface,
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
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.colors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              if (stats != null)
                                Text(
                                  l10n.reviewsCount(stats.reviewCount),
                                  style: TextStyle(
                                    color: context.colors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            Divider(color: context.colors.border, height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerItem(
                    icon: Icons.rate_review_outlined,
                    label: l10n.reviews,
                    onTap: () => _push(context, '/seller/reviews'),
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
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: context.colors.primary,
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
                  if (!isGuest) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _logout(context, ref),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.error,
                        side: BorderSide(color: context.colors.error),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(l10n.logOut),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, String route) {
    Navigator.pop(context);
    context.push(route);
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    Navigator.pop(context);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await ref.read(authServiceProvider).logout(prefs);
    await ref.read(appStorageProvider)?.logout();
    ref.invalidate(sellerAccountProvider);
    invalidateEntitlementProviders(ref);
    ref.read(userSessionProvider.notifier).state = null;
    ref.read(authSessionProvider.notifier).state = null;
    if (context.mounted) context.go('/login');
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.colors.primary),
      title: Text(
        label,
        style: TextStyle(
          color: context.colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: badge != null
          ? CircleAvatar(
              radius: 12,
              backgroundColor: context.colors.error,
              child: Text(
                badge!,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
