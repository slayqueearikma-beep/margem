import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin_models.dart';
import '../admin_providers.dart';
import '../admin_theme.dart';
import '../widgets/admin_design_system.dart';

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
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminUsersProvider),
      color: AdminTheme.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
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
                loading: () => ListView(
                  children: const [
                    AdminSkeletonBox(width: double.infinity, height: 88, radius: AdminTheme.radiusXl),
                    SizedBox(height: 10),
                    AdminSkeletonBox(width: double.infinity, height: 88, radius: AdminTheme.radiusXl),
                  ],
                ),
                error: (e, _) => AdminEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Failed to load users',
                  subtitle: '$e',
                ),
                data: (page) => _UserCardList(page: page, onAction: _handleAction),
              ),
            ),
          ],
        ),
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

class _UserCardList extends StatelessWidget {
  const _UserCardList({required this.page, required this.onAction});

  final AdminUserPage page;
  final void Function(AdminUserSummary user, String action) onAction;

  @override
  Widget build(BuildContext context) {
    if (page.items.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.people_outline,
        title: 'No users found',
        subtitle: 'Try adjusting your search or filters.',
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: page.items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${page.total} users',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AdminTheme.textSecondary,
                  ),
            ),
          );
        }
        final u = page.items[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AdminEntityCard(
            title: u.displayName.isNotEmpty ? u.displayName : u.email,
            subtitle: u.email,
            status: u.status,
            badge: u.isPremium ? 'premium' : u.role,
            avatarLabel: u.displayName.isNotEmpty ? u.displayName[0] : u.email[0],
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded, color: AdminTheme.textTertiary),
              onSelected: (action) => onAction(u, action),
              itemBuilder: (_) => [
                if (u.status == 'active')
                  const PopupMenuItem(value: 'suspend', child: Text('Suspend')),
                if (u.status == 'suspended')
                  const PopupMenuItem(value: 'activate', child: Text('Reactivate')),
                const PopupMenuItem(value: 'reset', child: Text('Reset password')),
              ],
            ),
          ),
        );
      },
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

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminPendingSellersProvider);
        ref.invalidate(adminSellersProvider);
      },
      color: AdminTheme.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AdminTheme.card,
                borderRadius: BorderRadius.circular(AdminTheme.radiusLg),
                border: Border.all(color: AdminTheme.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SegmentTab(
                      label: 'Pending',
                      selected: _showPending,
                      onTap: () => setState(() => _showPending = true),
                    ),
                  ),
                  Expanded(
                    child: _SegmentTab(
                      label: 'All',
                      selected: !_showPending,
                      onTap: () => setState(() => _showPending = false),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: data.when(
                loading: () => ListView(
                  children: const [
                    AdminSkeletonBox(width: double.infinity, height: 88, radius: AdminTheme.radiusXl),
                  ],
                ),
                error: (e, _) => AdminEmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'Failed to load businesses',
                  subtitle: '$e',
                ),
                data: (page) => _SellerCardList(sellers: page.items, onVerify: _verify),
              ),
            ),
          ],
        ),
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

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AdminTheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(AdminTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AdminTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AdminTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SellerCardList extends StatelessWidget {
  const _SellerCardList({required this.sellers, required this.onVerify});

  final List<AdminSellerSummary> sellers;
  final void Function(AdminSellerSummary seller, bool approve) onVerify;

  @override
  Widget build(BuildContext context) {
    if (sellers.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.storefront_outlined,
        title: 'No businesses',
        subtitle: 'Pending verifications will appear here.',
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: sellers.length,
      itemBuilder: (context, index) {
        final s = sellers[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AdminEntityCard(
            title: s.businessName,
            subtitle: '${s.city} · ${s.isActive ? "Active" : "Inactive"}',
            status: s.verificationStatus,
            badge: s.isPremium ? 'premium' : null,
            avatarColor: AdminTheme.info,
            trailing: s.verificationStatus == 'pending'
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline_rounded, color: AdminTheme.success),
                        onPressed: () => onVerify(s, true),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined, color: AdminTheme.danger),
                        onPressed: () => onVerify(s, false),
                      ),
                    ],
                  )
                : const Icon(Icons.chevron_right_rounded, color: AdminTheme.textTertiary),
          ),
        );
      },
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

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminProductsProvider),
      color: AdminTheme.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          children: [
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Search listings…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onSubmitted: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: products.when(
                loading: () => ListView(
                  children: const [
                    AdminSkeletonBox(width: double.infinity, height: 88, radius: AdminTheme.radiusXl),
                  ],
                ),
                error: (e, _) => AdminEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Failed to load listings',
                  subtitle: '$e',
                ),
                data: (page) => _ProductCardList(
                  products: page.items,
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
      ),
    );
  }
}

class _ProductCardList extends StatelessWidget {
  const _ProductCardList({required this.products, required this.onModerate});

  final List<AdminProductSummary> products;
  final void Function(AdminProductSummary p, String field, bool value) onModerate;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No listings found',
        subtitle: 'Try a different search term.',
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        final status = p.isHidden
            ? 'hidden'
            : p.isPaused
                ? 'suspended'
                : p.isFeatured
                    ? 'featured'
                    : 'active';
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AdminEntityCard(
            title: p.name,
            subtitle: p.categorySlug,
            status: status,
            avatarColor: AdminTheme.success,
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded, color: AdminTheme.textTertiary),
              onSelected: (action) {
                switch (action) {
                  case 'hidden':
                    onModerate(p, 'hidden', !p.isHidden);
                  case 'featured':
                    onModerate(p, 'featured', !p.isFeatured);
                  case 'paused':
                    onModerate(p, 'paused', !p.isPaused);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'hidden',
                  child: Text(p.isHidden ? 'Unhide' : 'Hide'),
                ),
                PopupMenuItem(
                  value: 'featured',
                  child: Text(p.isFeatured ? 'Unfeature' : 'Feature'),
                ),
                PopupMenuItem(
                  value: 'paused',
                  child: Text(p.isPaused ? 'Resume' : 'Pause'),
                ),
              ],
            ),
          ),
        );
      },
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
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminReportsProvider),
      color: AdminTheme.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
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
                loading: () => ListView(
                  children: const [
                    AdminSkeletonBox(width: double.infinity, height: 88, radius: AdminTheme.radiusXl),
                  ],
                ),
                error: (e, _) => AdminEmptyState(
                  icon: Icons.flag_outlined,
                  title: 'Failed to load reports',
                  subtitle: '$e',
                ),
                data: (page) {
                  if (page.items.isEmpty) {
                    return const AdminEmptyState(
                      icon: Icons.flag_outlined,
                      title: 'No reports',
                      subtitle: 'The moderation queue is clear.',
                    );
                  }
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: page.items.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '${page.total} reports',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AdminTheme.textSecondary,
                                ),
                          ),
                        );
                      }
                      final r = page.items[i - 1];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AdminEntityCard(
                          title: r.reason,
                          subtitle: r.details,
                          status: r.status,
                          avatarColor: AdminTheme.danger,
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_horiz_rounded, color: AdminTheme.textTertiary),
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
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Categories ──────────────────────────────────────────────────────────────

class AdminCategoriesScreen extends ConsumerStatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  ConsumerState<AdminCategoriesScreen> createState() =>
      _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends ConsumerState<AdminCategoriesScreen> {
  @override
  Widget build(BuildContext context) {
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
                    await ref
                        .read(adminApiProvider)
                        .reorderCategories(reordered.map((c) => c.id).toList());
                    ref.invalidate(adminCategoriesProvider);
                  },
                  itemBuilder: (context, i) {
                    final c = items[i];
                    final color = Color(
                      int.parse(c.accentColor.substring(1), radix: 16) +
                          0xFF000000,
                    );
                    return ListTile(
                      key: ValueKey(c.id),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.drag_handle),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: color.withValues(alpha: 0.15),
                            child: Icon(Icons.category, size: 16, color: color),
                          ),
                        ],
                      ),
                      title: Text(c.nameEn),
                      subtitle: Text('${c.slug} · ${c.icon}'),
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
  String _plan = 'premium';
  int _days = 30;

  @override
  void dispose() {
    _userId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: AdminTheme.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Grant Premium', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Manually assign Basic, Premium, or Enterprise to a business.'),
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
                  DropdownMenuItem(value: 'basic', child: Text('Basic (Free)')),
                  DropdownMenuItem(value: 'premium', child: Text('Premium')),
                  DropdownMenuItem(value: 'enterprise', child: Text('Enterprise')),
                ],
                onChanged: (v) => setState(() => _plan = v ?? 'premium'),
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
      data: (data) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminAnalyticsProvider),
        color: AdminTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 168,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    AdminKpiCard(
                      label: 'DAU',
                      value: adminFormatCount(data.dailyActiveUsers),
                      icon: Icons.today_rounded,
                      iconColor: AdminTheme.info,
                      iconBg: AdminTheme.info.withValues(alpha: 0.12),
                      trendPercent: 5.2,
                    ),
                    const SizedBox(width: 12),
                    AdminKpiCard(
                      label: 'MAU',
                      value: adminFormatCount(data.monthlyActiveUsers),
                      icon: Icons.calendar_month_rounded,
                      iconColor: AdminTheme.primary,
                      iconBg: AdminTheme.primary.withValues(alpha: 0.12),
                      trendPercent: 8.1,
                    ),
                    const SizedBox(width: 12),
                    AdminKpiCard(
                      label: 'Searches (7d)',
                      value: adminFormatCount(data.searchEvents7d),
                      icon: Icons.search_rounded,
                      iconColor: AdminTheme.success,
                      iconBg: AdminTheme.success.withValues(alpha: 0.12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const AdminSectionHeader(title: 'Popular categories'),
              Container(
                decoration: AdminTheme.cardDecoration(),
                child: Column(
                  children: [
                    for (final cat in data.popularCategories)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AdminTheme.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.category_rounded, size: 18, color: AdminTheme.primary),
                        ),
                        title: Text(cat['slug']?.toString() ?? ''),
                        trailing: Text(
                          '${cat['count']}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const AdminSectionHeader(title: 'Geographic distribution'),
              Container(
                decoration: AdminTheme.cardDecoration(),
                child: Column(
                  children: [
                    for (final geo in data.geographicDistribution)
                      ListTile(
                        leading: const Icon(Icons.location_on_outlined, color: AdminTheme.textSecondary),
                        title: Text(geo['city']?.toString() ?? ''),
                        trailing: Text(
                          '${geo['count']}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: AdminTheme.cardDecoration(),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: logs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (page) => ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: page.items.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${page.total} audit entries',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AdminTheme.textSecondary,
                      ),
                ),
              );
            }
            final log = page.items[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AdminEntityCard(
                title: log.action.replaceAll('_', ' '),
                subtitle: '${log.targetType}:${log.targetId}',
                status: log.success ? 'active' : 'suspended',
                avatarColor: log.success ? AdminTheme.success : AdminTheme.danger,
                trailing: Text(
                  log.createdAt.length > 16 ? log.createdAt.substring(0, 16) : log.createdAt,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            );
          },
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

Future<bool> _confirm(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminTheme.radiusXl)),
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
