import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin_models.dart';
import '../admin_providers.dart';
import '../admin_theme.dart';

// ── Users ───────────────────────────────────────────────────────────────────

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _search = TextEditingController();
  String? _status;
  AdminUserQuery _query = const AdminUserQuery();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _applySearch() {
    setState(() {
      _query = AdminUserQuery(search: _search.text.trim(), status: _status);
    });
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider(_query));
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterBar(
            searchController: _search,
            onSearch: _applySearch,
            statusValue: _status,
            statusOptions: const ['active', 'suspended', 'deleted'],
            onStatusChanged: (v) {
              setState(() => _status = v);
              _applySearch();
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: users.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (page) => _UserTable(page: page, onAction: _handleAction),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(AdminUserSummary user, String action) async {
    final api = ref.read(adminApiProvider);
    try {
      if (action == 'suspend') {
        final ok = await _confirm(context, 'Suspend ${user.email}?');
        if (!ok) return;
        await api.setUserStatus(user.id, 'suspended');
      } else if (action == 'activate') {
        await api.setUserStatus(user.id, 'active');
      } else if (action == 'reset') {
        await api.triggerPasswordReset(user.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password reset email sent')),
          );
        }
      }
      ref.invalidate(adminUsersProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _UserTable extends ConsumerWidget {
  const _UserTable({required this.page, required this.onAction});

  final AdminUserPage page;
  final void Function(AdminUserSummary user, String action) onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text('${page.total} users', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Role')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Premium')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final u in page.items)
                    DataRow(cells: [
                      DataCell(Text(u.email)),
                      DataCell(Text(u.displayName)),
                      DataCell(Text(u.role)),
                      DataCell(_StatusChip(status: u.status)),
                      DataCell(Icon(u.isPremium ? Icons.star : Icons.star_border, size: 18)),
                      DataCell(Row(
                        children: [
                          if (u.status == 'active')
                            IconButton(
                              tooltip: 'Suspend',
                              icon: const Icon(Icons.block, size: 18),
                              onPressed: () => onAction(u, 'suspend'),
                            ),
                          if (u.status == 'suspended')
                            IconButton(
                              tooltip: 'Reactivate',
                              icon: const Icon(Icons.check, size: 18),
                              onPressed: () => onAction(u, 'activate'),
                            ),
                          IconButton(
                            tooltip: 'Reset password',
                            icon: const Icon(Icons.lock_reset, size: 18),
                            onPressed: () => onAction(u, 'reset'),
                          ),
                        ],
                      )),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Businesses ──────────────────────────────────────────────────────────────

class AdminBusinessesScreen extends ConsumerStatefulWidget {
  const AdminBusinessesScreen({super.key});

  @override
  ConsumerState<AdminBusinessesScreen> createState() => _AdminBusinessesScreenState();
}

class _AdminBusinessesScreenState extends ConsumerState<AdminBusinessesScreen> {
  var _showPending = true;

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(adminPendingSellersProvider);
    final all = ref.watch(adminSellersProvider(null));
    final data = _showPending ? pending : all;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Pending')),
              ButtonSegment(value: false, label: Text('All')),
            ],
            selected: {_showPending},
            onSelectionChanged: (s) => setState(() => _showPending = s.first),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (sellers) => _SellerTable(sellers: sellers, onVerify: _verify),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verify(AdminSellerSummary seller, bool approve) async {
    final api = ref.read(adminApiProvider);
    await api.verifySeller(seller.id, approve: approve);
    ref.invalidate(adminPendingSellersProvider);
    ref.invalidate(adminSellersProvider);
  }
}

class _SellerTable extends StatelessWidget {
  const _SellerTable({required this.sellers, required this.onVerify});

  final List<AdminSellerSummary> sellers;
  final void Function(AdminSellerSummary seller, bool approve) onVerify;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Business')),
            DataColumn(label: Text('City')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Active')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final s in sellers)
              DataRow(cells: [
                DataCell(Text(s.businessName)),
                DataCell(Text(s.city)),
                DataCell(_StatusChip(status: s.verificationStatus)),
                DataCell(Icon(s.isActive ? Icons.check : Icons.close, size: 18)),
                DataCell(Row(
                  children: [
                    if (s.verificationStatus == 'pending') ...[
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: AdminTheme.success),
                        onPressed: () => onVerify(s, true),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined, color: AdminTheme.danger),
                        onPressed: () => onVerify(s, false),
                      ),
                    ],
                  ],
                )),
              ]),
          ],
        ),
      ),
    );
  }
}

// ── Listings ────────────────────────────────────────────────────────────────

class AdminListingsScreen extends ConsumerStatefulWidget {
  const AdminListingsScreen({super.key});

  @override
  ConsumerState<AdminListingsScreen> createState() => _AdminListingsScreenState();
}

class _AdminListingsScreenState extends ConsumerState<AdminListingsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().isEmpty ? null : _search.text.trim();
    final products = ref.watch(adminProductsProvider(query));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              hintText: 'Search listings…',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: products.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (items) => _ProductTable(
                products: items,
                onModerate: (p, field, value) async {
                  await ref.read(adminApiProvider).moderateProduct(
                        p.id,
                        isHidden: field == 'hidden' ? value : null,
                        isFeatured: field == 'featured' ? value : null,
                        isPaused: field == 'paused' ? value : null,
                      );
                  ref.invalidate(adminProductsProvider);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTable extends StatelessWidget {
  const _ProductTable({required this.products, required this.onModerate});

  final List<AdminProductSummary> products;
  final void Function(AdminProductSummary p, String field, bool value) onModerate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('Hidden')),
            DataColumn(label: Text('Featured')),
            DataColumn(label: Text('Paused')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final p in products)
              DataRow(cells: [
                DataCell(Text(p.name)),
                DataCell(Text(p.categorySlug)),
                DataCell(Icon(p.isHidden ? Icons.visibility_off : Icons.visibility, size: 18)),
                DataCell(Icon(p.isFeatured ? Icons.star : Icons.star_border, size: 18)),
                DataCell(Icon(p.isPaused ? Icons.pause : Icons.play_arrow, size: 18)),
                DataCell(Row(
                  children: [
                    IconButton(
                      tooltip: 'Toggle hidden',
                      icon: const Icon(Icons.visibility_off, size: 18),
                      onPressed: () => onModerate(p, 'hidden', !p.isHidden),
                    ),
                    IconButton(
                      tooltip: 'Toggle featured',
                      icon: const Icon(Icons.star, size: 18),
                      onPressed: () => onModerate(p, 'featured', !p.isFeatured),
                    ),
                    IconButton(
                      tooltip: 'Toggle paused',
                      icon: const Icon(Icons.pause, size: 18),
                      onPressed: () => onModerate(p, 'paused', !p.isPaused),
                    ),
                  ],
                )),
              ]),
          ],
        ),
      ),
    );
  }
}

// ── Reports ─────────────────────────────────────────────────────────────────

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  String _status = 'open';

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(adminReportsProvider(_status));
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Status filter'),
            items: const [
              DropdownMenuItem(value: 'open', child: Text('Open')),
              DropdownMenuItem(value: 'reviewing', child: Text('Reviewing')),
              DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
              DropdownMenuItem(value: 'dismissed', child: Text('Dismissed')),
              DropdownMenuItem(value: 'all', child: Text('All')),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'open'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: reports.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (items) => Card(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = items[i];
                    return ListTile(
                      title: Text(r.reason),
                      subtitle: Text(r.details, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) async {
                          await ref.read(adminApiProvider).updateReport(r.id, action);
                          ref.invalidate(adminReportsProvider);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'resolved', child: Text('Resolve')),
                          PopupMenuItem(value: 'dismissed', child: Text('Dismiss')),
                          PopupMenuItem(value: 'reviewing', child: Text('Mark reviewing')),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Categories ──────────────────────────────────────────────────────────────

class AdminCategoriesScreen extends ConsumerWidget {
  const AdminCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(adminCategoriesProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) => Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _showCreateDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('New category'),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: ReorderableListView.builder(
                  itemCount: items.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex--;
                    final reordered = [...items];
                    final item = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, item);
                    // Reorder API would go here; refresh for now
                    ref.invalidate(adminCategoriesProvider);
                  },
                  itemBuilder: (context, i) {
                    final c = items[i];
                    return ListTile(
                      key: ValueKey(c.id),
                      leading: const Icon(Icons.drag_handle),
                      title: Text(c.nameEn),
                      subtitle: Text(c.slug),
                      trailing: Text('Order ${c.sortOrder}'),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final slug = TextEditingController();
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: slug, decoration: const InputDecoration(labelText: 'Slug')),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name (EN)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok == true && slug.text.isNotEmpty && name.text.isNotEmpty) {
      await ref.read(adminApiProvider).createCategory(slug: slug.text.trim(), nameEn: name.text.trim());
      ref.invalidate(adminCategoriesProvider);
    }
    slug.dispose();
    name.dispose();
  }
}

// ── Premium ─────────────────────────────────────────────────────────────────

class AdminPremiumScreen extends ConsumerStatefulWidget {
  const AdminPremiumScreen({super.key});

  @override
  ConsumerState<AdminPremiumScreen> createState() => _AdminPremiumScreenState();
}

class _AdminPremiumScreenState extends ConsumerState<AdminPremiumScreen> {
  final _userId = TextEditingController();
  String _plan = 'buyer_premium';
  int _days = 30;

  @override
  void dispose() {
    _userId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Grant Premium', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Manually grant VIP, Premium, or Enterprise visibility to a user.'),
              const SizedBox(height: 24),
              TextField(
                controller: _userId,
                decoration: const InputDecoration(labelText: 'User ID (UUID)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _plan,
                decoration: const InputDecoration(labelText: 'Plan'),
                items: const [
                  DropdownMenuItem(value: 'buyer_premium', child: Text('MarGem Plus (VIP)')),
                  DropdownMenuItem(value: 'seller_pro', child: Text('Seller Pro (Premium)')),
                ],
                onChanged: (v) => setState(() => _plan = v ?? 'buyer_premium'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: '30',
                decoration: const InputDecoration(labelText: 'Days'),
                keyboardType: TextInputType.number,
                onChanged: (v) => _days = int.tryParse(v) ?? 30,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  if (_userId.text.trim().isEmpty) return;
                  await ref.read(adminApiProvider).grantPremium(_userId.text.trim(), _plan, _days);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Premium granted')),
                    );
                  }
                },
                child: const Text('Grant subscription'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Analytics ───────────────────────────────────────────────────────────────

class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(adminAnalyticsProvider);
    return analytics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (data) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(label: 'DAU', value: '${data.dailyActiveUsers}', icon: Icons.today),
                _StatCard(label: 'MAU', value: '${data.monthlyActiveUsers}', icon: Icons.calendar_month),
                _StatCard(label: 'Searches (7d)', value: '${data.searchEvents7d}', icon: Icons.search),
              ],
            ),
            const SizedBox(height: 24),
            Text('Popular Categories', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final cat in data.popularCategories)
                    ListTile(
                      title: Text(cat['slug']?.toString() ?? ''),
                      trailing: Text('${cat['count']}'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Geographic Distribution', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final geo in data.geographicDistribution)
                    ListTile(
                      title: Text(geo['city']?.toString() ?? ''),
                      trailing: Text('${geo['count']}'),
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

// ── Notifications ───────────────────────────────────────────────────────────

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends ConsumerState<AdminNotificationsScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _audience = 'all';

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Platform Announcement', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Queue a broadcast. Push and email delivery run asynchronously in production.'),
              const SizedBox(height: 24),
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _audience,
                decoration: const InputDecoration(labelText: 'Audience'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All users')),
                  DropdownMenuItem(value: 'buyers', child: Text('Buyers')),
                  DropdownMenuItem(value: 'sellers', child: Text('Businesses')),
                  DropdownMenuItem(value: 'premium', child: Text('Premium subscribers')),
                ],
                onChanged: (v) => setState(() => _audience = v ?? 'all'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  await ref.read(adminApiProvider).sendAnnouncement(
                        title: _title.text.trim(),
                        body: _body.text.trim(),
                        audience: _audience,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Announcement queued')),
                    );
                  }
                },
                child: const Text('Send announcement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Audit ───────────────────────────────────────────────────────────────────

class AdminAuditScreen extends ConsumerWidget {
  const AdminAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(adminAuditProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: logs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) => Card(
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Time')),
                DataColumn(label: Text('Action')),
                DataColumn(label: Text('Target')),
                DataColumn(label: Text('IP')),
                DataColumn(label: Text('OK')),
              ],
              rows: [
                for (final log in items)
                  DataRow(cells: [
                    DataCell(Text(log.createdAt.length > 19 ? log.createdAt.substring(0, 19) : log.createdAt)),
                    DataCell(Text(log.action)),
                    DataCell(Text('${log.targetType}:${log.targetId}')),
                    DataCell(Text(log.ipAddress)),
                    DataCell(Icon(
                      log.success ? Icons.check : Icons.close,
                      size: 18,
                      color: log.success ? AdminTheme.success : AdminTheme.danger,
                    )),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared widgets ──────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchController,
    required this.onSearch,
    required this.statusValue,
    required this.statusOptions,
    required this.onStatusChanged,
  });

  final TextEditingController searchController;
  final VoidCallback onSearch;
  final String? statusValue;
  final List<String> statusOptions;
  final ValueChanged<String?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: onSearch),
            ),
            onSubmitted: (_) => onSearch(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String?>(
            value: statusValue,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All')),
              for (final s in statusOptions)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: onStatusChanged,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' || 'verified' || 'resolved' => AdminTheme.success,
      'suspended' || 'rejected' || 'open' => AdminTheme.warning,
      'deleted' => AdminTheme.danger,
      _ => AdminTheme.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

Future<bool> _confirm(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirm'),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
      ],
    ),
  );
  return result ?? false;
}

// Re-export stat card for analytics screen
class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

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
              Icon(icon, color: AdminTheme.accentMuted),
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
