import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/buyer/buyer_home_screen.dart';
import '../../features/messages/messages_inbox_screen.dart';
import '../../l10n/app_localizations.dart';
import '../services/app_storage.dart';
import '../theme/app_spacing.dart';
import '../theme/theme_context.dart';
import 'app_brand_logo.dart';

/// Customer navigation drawer — neutral surfaces, theme-aware.
class BuyerDrawer extends ConsumerWidget {
  const BuyerDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final isGuest = session == null || session.isGuest;
    final displayName = (session?.name.trim().isNotEmpty ?? false)
        ? session!.name.trim()
        : l10n.guestMode;
    final unread =
        ref.watch(conversationsUnreadCountProvider).valueOrNull ?? 0;

    void closeAnd(VoidCallback action) {
      Navigator.pop(context);
      action();
    }

    return Drawer(
      backgroundColor: context.colors.surfaceVariant,
      shape: RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppBrandLogo.forContext(
                    AppBrandContext.settingsBranding,
                    includeClearSpace: false,
                  ),
                  SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.colors.surface,
                          border: Border.all(color: context.colors.border, width: 1),
                        ),
                        child: Icon(
                          isGuest
                              ? Icons.person_outline_rounded
                              : Icons.person_rounded,
                          color: context.colors.primary,
                          size: 26,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: context.colors.textPrimary,
                              ),
                            ),
                            Text(
                              isGuest
                                  ? l10n.guestModeSubtitle
                                  : (session.email),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 12,
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
            Divider(height: 1, color: context.colors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                children: [
                  _DrawerTile(
                    icon: Icons.person_outline_rounded,
                    label: l10n.navProfile,
                    onTap: () => closeAnd(() => context.push('/profile')),
                  ),
                  _DrawerTile(
                    icon: Icons.favorite_border_rounded,
                    label: l10n.favorites,
                    onTap: () => closeAnd(() => context.push('/favorites')),
                  ),
                  _DrawerTile(
                    icon: Icons.map_outlined,
                    label: l10n.exploreOnMap,
                    onTap: () => closeAnd(() => context.push('/map')),
                  ),
                  _DrawerTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: l10n.navMessages,
                    badge: unread > 0 ? (unread > 99 ? '99+' : '$unread') : null,
                    onTap: () => closeAnd(() {
                      ref.read(buyerTabIndexProvider.notifier).state = 2;
                    }),
                  ),
                  _DrawerTile(
                    icon: Icons.workspace_premium_outlined,
                    label: l10n.premium,
                    onTap: () => closeAnd(() => context.push('/premium')),
                  ),
                ],
              ),
            ),
            if (isGuest)
              Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: FilledButton(
                  onPressed: () =>
                      closeAnd(() => context.push('/onboarding/account-type')),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(l10n.createAccount),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
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
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: context.colors.primary, size: 22),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
