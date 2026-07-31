import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin_models.dart';
import '../admin_providers.dart';
import '../admin_theme.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(adminDashboardProvider);
    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load dashboard: $e')),
      data: (data) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(label: 'Total Users', value: '${data.totalUsers}', icon: Icons.people),
                _StatCard(label: 'Active Users', value: '${data.activeUsers}', icon: Icons.person_outline),
                _StatCard(label: 'New (7d)', value: '${data.newUsers7d}', icon: Icons.person_add_alt),
                _StatCard(label: 'Businesses', value: '${data.totalBusinesses}', icon: Icons.store),
                _StatCard(label: 'Verified', value: '${data.verifiedBusinesses}', icon: Icons.verified),
                _StatCard(label: 'Listings', value: '${data.totalListings}', icon: Icons.inventory_2),
                _StatCard(label: 'Open Reports', value: '${data.openReports}', icon: Icons.flag, accent: AdminTheme.danger),
                _StatCard(label: 'Premium', value: '${data.premiumSubscribers}', icon: Icons.workspace_premium),
              ],
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 900;
                return Flex(
                  direction: wide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: wide ? 1 : 0,
                      child: _GrowthChart(title: 'User Growth (30d)', points: data.userGrowth30d),
                    ),
                    SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 16),
                    Expanded(
                      flex: wide ? 1 : 0,
                      child: _GrowthChart(title: 'Listing Growth (30d)', points: data.listingGrowth30d),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Recent Activity', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          for (final item in data.recentActivity.take(8))
                            ListTile(
                              dense: true,
                              leading: Icon(_iconForActivity(item.type)),
                              title: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${item.type} · ${_shortDate(item.at)}'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('System Status', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          for (final entry in data.systemStatus.entries)
                            _StatusRow(label: entry.key, status: entry.value),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForActivity(String type) => switch (type) {
        'report' => Icons.flag_outlined,
        'listing' => Icons.inventory_2_outlined,
        'audit' => Icons.history,
        _ => Icons.notifications_outlined,
      };

  String _shortDate(String iso) {
    if (iso.length >= 16) return iso.substring(0, 16).replaceFirst('T', ' ');
    return iso;
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent ?? AdminTheme.accentMuted),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              Text(label, style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrowthChart extends StatelessWidget {
  const _GrowthChart({required this.title, required this.points});

  final String title;
  final List<GrowthPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxVal = points.fold<int>(1, (m, p) => p.count > m ? p.count : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final point in points)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Tooltip(
                          message: '${point.date}: ${point.count}',
                          child: Container(
                            height: 120 * (point.count / maxVal),
                            decoration: BoxDecoration(
                              color: AdminTheme.accentMuted.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.status});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final ok = status == 'ok';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.error, color: ok ? AdminTheme.success : AdminTheme.danger, size: 18),
          const SizedBox(width: 8),
          Text(label.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(status, style: TextStyle(color: ok ? AdminTheme.success : AdminTheme.danger)),
        ],
      ),
    );
  }
}
