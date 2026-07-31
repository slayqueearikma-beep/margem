import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/auth_models.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import 'admin_models.dart';
import 'admin_providers.dart';
import 'admin_theme.dart';
import 'widgets/admin_design_system.dart';

class AdminNavItem {
  const AdminNavItem({
    required this.label,
    required this.icon,
    required this.path,
    this.permission,
  });

  final String label;
  final IconData icon;
  final String path;
  final String? permission;
}

const adminNavItems = [
  AdminNavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, path: '/admin/dashboard', permission: 'dashboard.view'),
  AdminNavItem(label: 'Users', icon: Icons.people_outline, path: '/admin/users', permission: 'users.view'),
  AdminNavItem(label: 'Businesses', icon: Icons.storefront_outlined, path: '/admin/businesses', permission: 'businesses.view'),
  AdminNavItem(label: 'Listings', icon: Icons.inventory_2_outlined, path: '/admin/listings', permission: 'listings.view'),
  AdminNavItem(label: 'Reports', icon: Icons.flag_outlined, path: '/admin/reports', permission: 'reports.view'),
  AdminNavItem(label: 'Categories', icon: Icons.category_outlined, path: '/admin/categories', permission: 'categories.view'),
  AdminNavItem(label: 'Premium', icon: Icons.workspace_premium_outlined, path: '/admin/premium', permission: 'premium.view'),
  AdminNavItem(label: 'Analytics', icon: Icons.analytics_outlined, path: '/admin/analytics', permission: 'analytics.view'),
  AdminNavItem(label: 'Notifications', icon: Icons.campaign_outlined, path: '/admin/notifications', permission: 'notifications.send'),
  AdminNavItem(label: 'Audit Logs', icon: Icons.history, path: '/admin/audit', permission: 'audit.view'),
];

const _bottomNavRoutes = [
  '/admin/dashboard',
  '/admin/users',
  '/admin/analytics',
  '/admin/reports',
];

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  static final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffMeProvider);
    final dashboardAsync = ref.watch(adminDashboardProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 900;
    final notificationCount = dashboardAsync.valueOrNull?.openReports ?? 0;
    final displayName = staffAsync.valueOrNull?.displayName ?? 'Admin';

    return Theme(
      data: AdminTheme.theme(),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AdminTheme.background,
        extendBody: isMobile,
        appBar: isMobile
            ? AdminGlassAppBar(
                title: _titleForPath(location),
                subtitle: _subtitleForPath(location),
                displayName: displayName,
                notificationCount: notificationCount,
                onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                onSearch: () => _openSearch(context),
                onNotifications: () => context.go('/admin/notifications'),
              )
            : null,
        drawer: isMobile ? _AdminDrawer(location: location, staffAsync: staffAsync, onLogout: () => _logout(ref, context)) : null,
        body: Row(
          children: [
            if (!isMobile)
              _AdminSidebar(
                location: location,
                staffAsync: staffAsync,
                onLogout: () => _logout(ref, context),
              ),
            Expanded(child: child),
          ],
        ),
        bottomNavigationBar: isMobile
            ? _AdminBottomNav(
                location: location,
                onMore: () => _openMoreSheet(context, ref, location),
              )
            : null,
      ),
    );
  }

  String _titleForPath(String path) {
    for (final item in adminNavItems) {
      if (path.startsWith(item.path)) return item.label;
    }
    return 'Administration';
  }

  String? _subtitleForPath(String path) {
    if (path.startsWith('/admin/dashboard')) {
      return 'Overview of MarGem marketplace';
    }
    return null;
  }

  Future<void> _logout(WidgetRef ref, BuildContext context) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await ref.read(authServiceProvider).logout(prefs);
    await ref.read(appStorageProvider)?.logout();
    ref.read(userSessionProvider.notifier).state = null;
    ref.read(authSessionProvider.notifier).state = null;
    if (context.mounted) context.go('/login');
  }

  Future<void> _openSearch(BuildContext context) async {
    await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AdminSearchSheet(),
    );
  }

  void _openMoreSheet(BuildContext context, WidgetRef ref, String location) {
    final permissions = ref.read(staffMeProvider).valueOrNull?.permissions ?? const <String>[];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdminMoreSheet(
        permissions: permissions,
        onNavigate: (path) {
          Navigator.pop(ctx);
          context.go(path);
        },
      ),
    );
  }
}

class _AdminBottomNav extends StatelessWidget {
  const _AdminBottomNav({required this.location, required this.onMore});

  final String location;
  final VoidCallback onMore;

  int get _selectedIndex {
    for (var i = 0; i < _bottomNavRoutes.length; i++) {
      if (location.startsWith(_bottomNavRoutes[i])) return i;
    }
    return 4; // More
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AdminTheme.radiusXl),
        boxShadow: AdminTheme.cardShadow,
        border: Border.all(color: AdminTheme.border.withValues(alpha: 0.6)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AdminTheme.radiusXl),
        child: NavigationBar(
          height: 68,
          elevation: 0,
          backgroundColor: Colors.white,
          indicatorColor: AdminTheme.primary.withValues(alpha: 0.12),
          selectedIndex: selected.clamp(0, 4),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) {
            adminHaptic();
            if (index == 4) {
              onMore();
              return;
            }
            context.go(_bottomNavRoutes[index]);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people_rounded),
              label: 'Users',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics_rounded),
              label: 'Analytics',
            ),
            NavigationDestination(
              icon: Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag_rounded),
              label: 'Reports',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_rounded),
              selectedIcon: Icon(Icons.more_horiz_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminMoreSheet extends StatelessWidget {
  const _AdminMoreSheet({required this.permissions, required this.onNavigate});

  final List<String> permissions;
  final void Function(String path) onNavigate;

  @override
  Widget build(BuildContext context) {
    final moreItems = [
      (label: 'Businesses', icon: Icons.storefront_outlined, path: '/admin/businesses', permission: 'businesses.view'),
      (label: 'Listings', icon: Icons.inventory_2_outlined, path: '/admin/listings', permission: 'listings.view'),
      (label: 'Categories', icon: Icons.category_outlined, path: '/admin/categories', permission: 'categories.view'),
      (label: 'Premium', icon: Icons.workspace_premium_outlined, path: '/admin/premium', permission: 'premium.view'),
      (label: 'Notifications', icon: Icons.campaign_outlined, path: '/admin/notifications', permission: 'notifications.send'),
      (label: 'Audit Logs', icon: Icons.history, path: '/admin/audit', permission: 'audit.view'),
    ].where((e) => permissions.contains(e.permission)).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AdminTheme.radiusXl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AdminTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('More', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: moreItems.length,
            itemBuilder: (context, index) {
              final item = moreItems[index];
              return Material(
                color: AdminTheme.background,
                borderRadius: BorderRadius.circular(AdminTheme.radiusLg),
                child: InkWell(
                  onTap: () => onNavigate(item.path),
                  borderRadius: BorderRadius.circular(AdminTheme.radiusLg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, color: AdminTheme.primary),
                      const SizedBox(height: 8),
                      Text(
                        item.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdminDrawer extends ConsumerWidget {
  const _AdminDrawer({
    required this.location,
    required this.staffAsync,
    required this.onLogout,
  });

  final String location;
  final AsyncValue<StaffMe> staffAsync;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: AdminTheme.sidebarBg,
      child: _AdminSidebar(
        location: location,
        staffAsync: staffAsync,
        onLogout: onLogout,
        inDrawer: true,
      ),
    );
  }
}

class _AdminSidebar extends ConsumerWidget {
  const _AdminSidebar({
    required this.location,
    required this.staffAsync,
    required this.onLogout,
    this.inDrawer = false,
  });

  final String location;
  final AsyncValue<StaffMe> staffAsync;
  final VoidCallback onLogout;
  final bool inDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = staffAsync.valueOrNull?.permissions ?? const <String>[];
    final items = adminNavItems
        .where((item) => item.permission == null || permissions.contains(item.permission))
        .toList();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, inDrawer ? 20 : 28, 20, 20),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AdminTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.diamond_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MarGem Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Enterprise Console',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFF2A3544), height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            children: [
              for (final item in items)
                _NavTile(
                  item: item,
                  selected: location.startsWith(item.path),
                  onTap: () {
                    if (inDrawer) Navigator.pop(context);
                    context.go(item.path);
                  },
                ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.logout_rounded, color: Colors.white70),
          title: const Text('Sign out', style: TextStyle(color: Colors.white70)),
          onTap: onLogout,
        ),
      ],
    );

    if (inDrawer) return SafeArea(child: content);

    return Container(
      width: 260,
      color: AdminTheme.sidebarBg,
      child: content,
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AdminNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? AdminTheme.sidebarActive : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: AdminTheme.sidebarHover,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: selected ? AdminTheme.gold : Colors.white70,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
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

bool isStaffUser(AuthUser? user) => user?.isStaff ?? false;

String staffHomeRoute() => '/admin/dashboard';
