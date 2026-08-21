import 'package:flutter/material.dart';
import '../../core/theme/theme_context.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/app_back_handler.dart';
import '../../core/widgets/margem_app_bar.dart';
import '../../core/widgets/premium_ribbon_badge.dart';
import '../../l10n/app_localizations.dart';
import 'seller_account_provider.dart';
import 'seller_bookings_tab.dart';
import 'seller_catalog_tab.dart';
import 'seller_dashboard_tab.dart';
import 'seller_drawer.dart';
import 'seller_more_tab.dart';
import 'seller_navigation.dart';

class SellerShell extends ConsumerWidget {
  const SellerShell({super.key});

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final account = ref.read(sellerAccountProvider).valueOrNull;
    final isPremium = account != null &&
        (account.stats.isPremium || account.profile.isPremium);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.handyman_outlined),
                title: Text(l10n.addService),
                subtitle: Text(l10n.serviceManagementSub),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/seller/services/new');
                },
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(l10n.addProduct),
                subtitle: Text(l10n.productManagementSub),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/seller/products/new');
                },
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ListTile(
                    leading: const Icon(Icons.videocam_outlined),
                    title: Text(l10n.addVideo),
                    subtitle: Text(l10n.addVideoSub),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (!isPremium) {
                        _showPremiumRequiredDialog(context);
                        return;
                      }
                      context.push('/seller/videos/new');
                    },
                  ),
                  const Positioned(
                    top: 4,
                    right: 4,
                    child: PremiumRibbonBadge(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPremiumRequiredDialog(BuildContext context) {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.premiumRequiredTitle),
        content: Text(l10n.premiumRequiredForVideo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/premium');
            },
            child: Text(l10n.upgradeToPremium),
          ),
        ],
      ),
    );
  }

  void _selectTab(WidgetRef ref, int tabIndex) {
    ref.read(sellerTabIndexProvider.notifier).state = tabIndex;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final index = ref.watch(sellerTabIndexProvider).clamp(0, 3);

    return RootBackScope(
      child: Scaffold(
        drawer: const SellerDrawer(),
        appBar: MarGemAppBar(
          automaticallyImplyLeading: false,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          actions: _actionsForTab(context, ref, index),
        ),
        body: IndexedStack(
          index: index,
          children: const [
            SellerDashboardTab(),
            SellerCatalogTab(),
            SellerBookingsTab(),
            SellerMoreTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddSheet(context, ref),
          child: const Icon(Icons.add_rounded, size: 30),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              _SellerNavItem(
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard_rounded,
                label: l10n.navDashboard,
                selected: index == 0,
                onTap: () => _selectTab(ref, 0),
              ),
              _SellerNavItem(
                icon: Icons.handyman_outlined,
                selectedIcon: Icons.handyman_rounded,
                label: l10n.navServices,
                selected: index == 1,
                onTap: () => _selectTab(ref, 1),
              ),
              const SizedBox(width: 56),
              _SellerNavItem(
                icon: Icons.event_note_outlined,
                selectedIcon: Icons.event_note_rounded,
                label: l10n.navBookings,
                selected: index == 2,
                onTap: () => _selectTab(ref, 2),
              ),
              _SellerNavItem(
                icon: Icons.menu_rounded,
                selectedIcon: Icons.menu_rounded,
                label: l10n.navMore,
                selected: index == 3,
                onTap: () => _selectTab(ref, 3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _titleForTab(AppStrings l10n, int index) {
    switch (index) {
      case 0:
        return l10n.navDashboard;
      case 1:
        return l10n.navServices;
      case 2:
        return l10n.navBookings;
      default:
        return l10n.navMore;
    }
  }

  List<Widget>? _actionsForTab(
    BuildContext context,
    WidgetRef ref,
    int index,
  ) {
    if (index == 0) {
      return [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () => context.push('/seller/notifications'),
        ),
      ];
    }
    return null;
  }
}

class _SellerNavItem extends StatelessWidget {
  const _SellerNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.colors.primary : context.colors.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? selectedIcon : icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
