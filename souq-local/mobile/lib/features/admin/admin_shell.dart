import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/auth_models.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import 'admin_models.dart';
import 'admin_providers.dart';
import 'admin_theme.dart';

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

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffMeProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 900;

    return Theme(
      data: AdminTheme.theme(),
      child: Scaffold(
        body: Row(
          children: [
            if (!isCompact)
              _AdminSidebar(
                location: location,
                staffAsync: staffAsync,
                onLogout: () => _logout(ref, context),
              ),
            Expanded(
              child: Column(
                children: [
                  _AdminTopBar(
                    title: _titleForPath(location),
                    staffAsync: staffAsync,
                    isCompact: isCompact,
                    onMenu: () => _openDrawer(context, ref, location),
                    onLogout: () => _logout(ref, context),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _titleForPath(String path) {
    for (final item in adminNavItems) {
      if (path.startsWith(item.path)) return item.label;
    }
    return 'Administration';
  }

  Future<void> _logout(WidgetRef ref, BuildContext context) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await ref.read(authServiceProvider).logout(prefs);
    await ref.read(appStorageProvider)?.logout();
    ref.read(userSessionProvider.notifier).state = null;
    ref.read(authSessionProvider.notifier).state = null;
    if (context.mounted) context.go('/login');
  }

  void _openDrawer(BuildContext context, WidgetRef ref, String location) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AdminTheme.sidebarBg,
      builder: (ctx) => SafeArea(
        child: _AdminSidebar(
          location: location,
          staffAsync: ref.read(staffMeProvider),
          onLogout: () {
            Navigator.pop(ctx);
            _logout(ref, context);
          },
        ),
      ),
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.title,
    required this.staffAsync,
    required this.isCompact,
    required this.onMenu,
    required this.onLogout,
  });

  final String title;
  final AsyncValue<StaffMe> staffAsync;
  final bool isCompact;
  final VoidCallback onMenu;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AdminTheme.card,
        border: Border(bottom: BorderSide(color: AdminTheme.border)),
      ),
      child: Row(
        children: [
          if (isCompact)
            IconButton(onPressed: onMenu, icon: const Icon(Icons.menu)),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          staffAsync.when(
            data: (staff) => Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(staff.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(staff.roleLabel,
                        style: const TextStyle(
                            fontSize: 12, color: AdminTheme.textSecondary)),
                  ],
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  backgroundColor: AdminTheme.accentMuted,
                  child: Text(
                    staff.displayName.isNotEmpty
                        ? staff.displayName[0].toUpperCase()
                        : 'A',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            loading: () => const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => const Icon(Icons.shield_outlined),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
    );
  }
}

class _AdminSidebar extends ConsumerWidget {
  const _AdminSidebar({
    required this.location,
    required this.staffAsync,
    required this.onLogout,
  });

  final String location;
  final AsyncValue<StaffMe> staffAsync;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = staffAsync.valueOrNull?.permissions ?? const <String>[];
    final items = adminNavItems
        .where((item) =>
            item.permission == null || permissions.contains(item.permission))
        .toList();

    return Container(
      width: 260,
      color: AdminTheme.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings, color: AdminTheme.accent),
                SizedBox(width: 10),
                Text(
                  'MarGem Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A3544), height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final item in items)
                  _NavTile(
                    item: item,
                    selected: location.startsWith(item.path),
                    onTap: () => context.go(item.path),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white70),
            title: const Text('Sign out', style: TextStyle(color: Colors.white70)),
            onTap: onLogout,
          ),
        ],
      ),
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
    return Material(
      color: selected ? AdminTheme.sidebarActive : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: AdminTheme.sidebarHover,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            dense: true,
            leading: Icon(
              item.icon,
              color: selected ? AdminTheme.accent : Colors.white70,
            ),
            title: Text(
              item.label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }
}

bool isStaffUser(AuthUser? user) => user?.isStaff ?? false;

String staffHomeRoute() => '/admin/dashboard';
