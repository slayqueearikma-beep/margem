import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/app_back_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'seller_bookings_tab.dart';
import 'seller_catalog_tab.dart';
import 'seller_dashboard_tab.dart';
import 'seller_drawer.dart';
import 'seller_more_tab.dart';
import 'seller_navigation.dart';

class SellerShell extends ConsumerWidget {
  const SellerShell({super.key});

  void _showAddSheet(BuildContext context) {
    final l10n = context.l10n;
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final index = ref.watch(sellerTabIndexProvider).clamp(0, 3);

    return RootBackScope(
      child: Scaffold(
        drawer: const SellerDrawer(),
        appBar: AppBar(
          title: Text(_titleForTab(l10n, index)),
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
          onPressed: () => _showAddSheet(context),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          child: const Icon(Icons.add_rounded, size: 30),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index < 2 ? index : index + 1,
          height: 68,
          onDestinationSelected: (i) {
            if (i == 2) return;
            ref.read(sellerTabIndexProvider.notifier).state = i < 2 ? i : i - 1;
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard_rounded),
              label: l10n.navDashboard,
            ),
            NavigationDestination(
              icon: const Icon(Icons.handyman_outlined),
              selectedIcon: const Icon(Icons.handyman_rounded),
              label: l10n.navServices,
            ),
            const NavigationDestination(
              icon: SizedBox(width: 56),
              label: '',
            ),
            NavigationDestination(
              icon: const Icon(Icons.event_note_outlined),
              selectedIcon: const Icon(Icons.event_note_rounded),
              label: l10n.navBookings,
            ),
            NavigationDestination(
              icon: const Icon(Icons.menu_rounded),
              selectedIcon: const Icon(Icons.menu_rounded),
              label: l10n.navMore,
            ),
          ],
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
