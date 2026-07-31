import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin_providers.dart';
import '../admin_theme.dart';
import '../widgets/admin_design_system.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final _chartPage = PageController();
  int _chartIndex = 0;
  int _mgmtTab = 0;

  @override
  void dispose() {
    _chartPage.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(staffMeProvider);
    ref.invalidate(adminPendingSellersProvider);
    ref.invalidate(adminUsersProvider);
    await ref.read(adminDashboardProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(adminDashboardProvider);
    final staff = ref.watch(staffMeProvider);

    return dashboard.when(
      loading: () => const _DashboardSkeleton(),
      error: (e, _) => Center(
        child: AdminEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load dashboard',
          subtitle: '$e',
          actionLabel: 'Retry',
          onAction: _refresh,
        ),
      ),
      data: (data) {
        final userTrend = adminTrendPercent(data.userGrowth30d);
        final listingTrend = adminTrendPercent(data.listingGrowth30d);
        final name = staff.valueOrNull?.displayName ?? 'Admin';

        return RefreshIndicator(
          onRefresh: _refresh,
          color: AdminTheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: AdminWelcomeCard(
                    greeting: adminGreeting(),
                    name: name,
                    dateLabel: adminDateLabel(),
                    syncLabel: 'Synced just now',
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(top: 20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: AdminSectionHeader(title: 'Key metrics'),
                      ),
                      SizedBox(
                        height: 168,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          physics: const BouncingScrollPhysics(),
                          children: [
                            AdminKpiCard(
                              label: 'Total Users',
                              value: adminFormatCount(data.totalUsers),
                              icon: Icons.people_rounded,
                              iconColor: const Color(0xFF8B5CF6),
                              iconBg: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                              trendPercent: userTrend,
                              sparkline: adminSparkline(data.userGrowth30d),
                            ),
                            const SizedBox(width: 12),
                            AdminKpiCard(
                              label: 'Active Sellers',
                              value: adminFormatCount(data.totalBusinesses),
                              icon: Icons.storefront_rounded,
                              iconColor: const Color(0xFF3B82F6),
                              iconBg: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                              trendPercent: listingTrend * 0.6,
                              sparkline: adminSparkline(data.listingGrowth30d),
                            ),
                            const SizedBox(width: 12),
                            AdminKpiCard(
                              label: 'Products',
                              value: adminFormatCount(data.totalListings),
                              icon: Icons.inventory_2_rounded,
                              iconColor: const Color(0xFF10B981),
                              iconBg: const Color(0xFF10B981).withValues(alpha: 0.12),
                              trendPercent: listingTrend,
                              sparkline: adminSparkline(data.listingGrowth30d),
                            ),
                            const SizedBox(width: 12),
                            AdminKpiCard(
                              label: 'Subscriptions',
                              value: adminFormatCount(data.premiumSubscribers),
                              icon: Icons.workspace_premium_rounded,
                              iconColor: AdminTheme.gold,
                              iconBg: AdminTheme.gold.withValues(alpha: 0.15),
                              trendPercent: 12.4,
                            ),
                            const SizedBox(width: 12),
                            AdminKpiCard(
                              label: 'Pending Reports',
                              value: '${data.openReports}',
                              icon: Icons.flag_rounded,
                              iconColor: AdminTheme.danger,
                              iconBg: AdminTheme.danger.withValues(alpha: 0.12),
                              trendPercent: data.openReports > 0 ? -8.2 : 0,
                              onTap: () => context.go('/admin/reports'),
                            ),
                            const SizedBox(width: 12),
                            AdminKpiCard(
                              label: 'Verified Stores',
                              value: adminFormatCount(data.verifiedBusinesses),
                              icon: Icons.verified_rounded,
                              iconColor: AdminTheme.success,
                              iconBg: AdminTheme.success.withValues(alpha: 0.12),
                              trendPercent: 6.8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AdminSectionHeader(
                        title: 'Analytics',
                        actionLabel: 'View all',
                        onAction: () => context.go('/admin/analytics'),
                      ),
                      SizedBox(
                        height: 320,
                        child: PageView(
                          controller: _chartPage,
                          onPageChanged: (i) => setState(() => _chartIndex = i),
                          children: [
                            AdminLineChartCard(
                              title: 'User Growth',
                              subtitle: 'New registrations over 30 days',
                              points: data.userGrowth30d,
                              totalLabel: adminFormatCount(data.newUsers7d),
                              trendPercent: userTrend,
                            ),
                            AdminLineChartCard(
                              title: 'Listing Growth',
                              subtitle: 'New products over 30 days',
                              points: data.listingGrowth30d,
                              totalLabel: adminFormatCount(data.totalListings),
                              trendPercent: listingTrend,
                              accentColor: const Color(0xFF3B82F6),
                            ),
                            AdminLineChartCard(
                              title: 'Platform Activity',
                              subtitle: 'Reviews & engagement',
                              points: data.userGrowth30d,
                              totalLabel: adminFormatCount(data.totalReviews),
                              trendPercent: 4.2,
                              accentColor: AdminTheme.gold,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          3,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _chartIndex == i ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _chartIndex == i
                                  ? AdminTheme.primary
                                  : AdminTheme.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AdminSectionHeader(title: 'Quick actions'),
                      AdminQuickActionsGrid(actions: _quickActions(context)),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AdminSectionHeader(
                              title: 'Recent activity',
                              actionLabel: 'View all',
                              onAction: () => context.go('/admin/audit'),
                            ),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: AdminTheme.cardDecoration(),
                              child: AdminActivityTimeline(
                                items: data.recentActivity.take(6).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AdminSectionHeader(title: 'Management'),
                      _ManagementTabs(
                        selected: _mgmtTab,
                        onChanged: (i) => setState(() => _mgmtTab = i),
                      ),
                      const SizedBox(height: 14),
                      _ManagementPreview(tab: _mgmtTab),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AdminSectionHeader(title: 'System health'),
                      _SystemHealthCard(status: data.systemStatus),
                    ],
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),
        );
      },
    );
  }

  List<AdminQuickAction> _quickActions(BuildContext context) {
    return [
      AdminQuickAction(
        label: 'Approve Sellers',
        icon: Icons.how_to_reg_rounded,
        color: AdminTheme.success,
        onTap: () => context.go('/admin/businesses'),
      ),
      AdminQuickAction(
        label: 'Verify Stores',
        icon: Icons.verified_rounded,
        color: AdminTheme.info,
        onTap: () => context.go('/admin/businesses'),
      ),
      AdminQuickAction(
        label: 'Suspend User',
        icon: Icons.block_rounded,
        color: AdminTheme.danger,
        onTap: () => context.go('/admin/users'),
      ),
      AdminQuickAction(
        label: 'Send Notification',
        icon: Icons.campaign_rounded,
        color: AdminTheme.primary,
        onTap: () => context.go('/admin/notifications'),
      ),
      AdminQuickAction(
        label: 'Feature Listing',
        icon: Icons.star_rounded,
        color: AdminTheme.gold,
        onTap: () => context.go('/admin/listings'),
      ),
      AdminQuickAction(
        label: 'Add Category',
        icon: Icons.category_rounded,
        color: const Color(0xFF8B5CF6),
        onTap: () => context.go('/admin/categories'),
      ),
      AdminQuickAction(
        label: 'Manage Reports',
        icon: Icons.flag_rounded,
        color: AdminTheme.warning,
        onTap: () => context.go('/admin/reports'),
      ),
      AdminQuickAction(
        label: 'Manage Payments',
        icon: Icons.payments_rounded,
        color: const Color(0xFF10B981),
        onTap: () => context.go('/admin/premium'),
      ),
    ];
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        AdminSkeletonBox(width: double.infinity, height: 140, radius: AdminTheme.radiusXl),
        SizedBox(height: 20),
        AdminSkeletonBox(width: double.infinity, height: 24, radius: 8),
        SizedBox(height: 12),
        Row(
          children: [
            AdminSkeletonBox(width: 168, height: 150, radius: AdminTheme.radiusXl),
            SizedBox(width: 12),
            AdminSkeletonBox(width: 168, height: 150, radius: AdminTheme.radiusXl),
          ],
        ),
        SizedBox(height: 24),
        AdminSkeletonBox(width: double.infinity, height: 280, radius: AdminTheme.radiusXl),
      ],
    );
  }
}

class _ManagementTabs extends StatelessWidget {
  const _ManagementTabs({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  static const _labels = ['Users', 'Sellers', 'Products', 'Reports'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_labels[i]),
                selected: selected == i,
                onSelected: (_) => onChanged(i),
                selectedColor: AdminTheme.primary.withValues(alpha: 0.12),
                checkmarkColor: AdminTheme.primary,
                labelStyle: TextStyle(
                  fontWeight: selected == i ? FontWeight.w700 : FontWeight.w500,
                  color: selected == i ? AdminTheme.primary : AdminTheme.textSecondary,
                ),
                side: BorderSide(
                  color: selected == i ? AdminTheme.primary : AdminTheme.border,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ManagementPreview extends ConsumerWidget {
  const _ManagementPreview({required this.tab});

  final int tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (tab) {
      0 => _UsersPreview(),
      1 => _SellersPreview(),
      2 => _ProductsPreview(),
      _ => _ReportsPreview(),
    };
  }
}

class _UsersPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider(const AdminUserQuery(limit: 5)));
    return users.when(
      loading: () => const AdminSkeletonBox(width: double.infinity, height: 80),
      error: (_, __) => const SizedBox.shrink(),
      data: (page) => Column(
        children: [
          for (final u in page.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AdminEntityCard(
                title: u.displayName.isNotEmpty ? u.displayName : u.email,
                subtitle: u.email,
                status: u.status,
                badge: u.role,
                avatarLabel: u.displayName.isNotEmpty ? u.displayName[0] : u.email[0],
                onTap: () => context.go('/admin/users'),
              ),
            ),
        ],
      ),
    );
  }
}

class _SellersPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellers = ref.watch(adminPendingSellersProvider);
    return sellers.when(
      loading: () => const AdminSkeletonBox(width: double.infinity, height: 80),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) {
          return const AdminEmptyState(
            icon: Icons.storefront_outlined,
            title: 'No pending sellers',
            subtitle: 'All businesses are reviewed.',
          );
        }
        return Column(
          children: [
            for (final s in items.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AdminEntityCard(
                  title: s.businessName,
                  subtitle: s.city,
                  status: s.verificationStatus,
                  avatarColor: AdminTheme.info,
                  onTap: () => context.go('/admin/businesses'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProductsPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(adminProductsProvider(null));
    return products.when(
      loading: () => const AdminSkeletonBox(width: double.infinity, height: 80),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) => Column(
        children: [
          for (final p in items.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AdminEntityCard(
                title: p.name,
                subtitle: p.categorySlug,
                status: p.isHidden ? 'hidden' : (p.isFeatured ? 'featured' : 'active'),
                avatarColor: AdminTheme.success,
                onTap: () => context.go('/admin/listings'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportsPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(adminReportsProvider('open'));
    return reports.when(
      loading: () => const AdminSkeletonBox(width: double.infinity, height: 80),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) {
          return const AdminEmptyState(
            icon: Icons.flag_outlined,
            title: 'No open reports',
            subtitle: 'The moderation queue is clear.',
          );
        }
        return Column(
          children: [
            for (final r in items.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AdminEntityCard(
                  title: r.reason,
                  subtitle: r.details,
                  status: r.status,
                  avatarColor: AdminTheme.danger,
                  onTap: () => context.go('/admin/reports'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SystemHealthCard extends StatelessWidget {
  const _SystemHealthCard({required this.status});

  final Map<String, String> status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        children: [
          for (final entry in status.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    entry.value == 'ok' ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: entry.value == 'ok' ? AdminTheme.success : AdminTheme.danger,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    entry.key.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const Spacer(),
                  AdminStatusBadge(status: entry.value == 'ok' ? 'active' : 'suspended'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
