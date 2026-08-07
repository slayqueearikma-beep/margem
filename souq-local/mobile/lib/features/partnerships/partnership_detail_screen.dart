import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import 'partnership_models.dart';
import 'partnership_widgets.dart';

final partnershipDetailProvider =
    FutureProvider.autoDispose.family<PartnershipModel, String>((ref, id) {
  return apiServiceProvider.fetchPartnership(id);
});

final partnershipAnalyticsProvider =
    FutureProvider.autoDispose.family<PartnershipAnalyticsModel, String>((ref, id) {
  return apiServiceProvider.fetchPartnershipAnalytics(id);
});

class PartnershipDetailScreen extends ConsumerStatefulWidget {
  const PartnershipDetailScreen({super.key, required this.partnershipId});

  final String partnershipId;

  @override
  ConsumerState<PartnershipDetailScreen> createState() =>
      _PartnershipDetailScreenState();
}

class _PartnershipDetailScreenState extends ConsumerState<PartnershipDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partnershipAsync = ref.watch(partnershipDetailProvider(widget.partnershipId));

    return partnershipAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: AsyncErrorView(
          message: error is ApiException ? error.message : 'Failed to load',
          onRetry: () =>
              ref.invalidate(partnershipDetailProvider(widget.partnershipId)),
        ),
      ),
      data: (partnership) => Scaffold(
        appBar: AppBar(
          title: Text(partnership.name),
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Team'),
              Tab(text: 'Products'),
              Tab(text: 'Inventory'),
              Tab(text: 'Orders'),
              Tab(text: 'Analytics'),
              Tab(text: 'Chat'),
              Tab(text: 'Settings'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            _OverviewTab(partnership: partnership),
            _TeamTab(partnership: partnership),
            _PlaceholderTab(
              title: 'Shared products',
              icon: Icons.inventory_2_outlined,
              message: 'Create shared listings from the seller dashboard products.',
            ),
            _PlaceholderTab(
              title: 'Shared inventory',
              icon: Icons.warehouse_outlined,
              message: 'Track stock sharing, reservations, and transfers.',
            ),
            _PlaceholderTab(
              title: 'Shared orders',
              icon: Icons.assignment_outlined,
              message: 'Collaborate on customer inquiries and fulfillment.',
            ),
            _AnalyticsTab(partnershipId: widget.partnershipId),
            _ChatTab(partnershipId: widget.partnershipId, controller: _chatController),
            _SettingsTab(partnership: partnership),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.partnership});

  final PartnershipModel partnership;

  @override
  Widget build(BuildContext context) {
    final trust = partnership.trust;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                partnership.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            PartnershipStatusChip(status: partnership.status),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (partnership.isVerified)
          const Row(
            children: [
              Icon(Icons.verified, color: AppColors.primary, size: 18),
              SizedBox(width: 6),
              Text('Verified Partnership', style: TextStyle(color: AppColors.primary)),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        Text(partnership.description.isNotEmpty
            ? partnership.description
            : 'No description yet.'),
        const SizedBox(height: AppSpacing.lg),
        if (trust != null) ...[
          _StatRow(label: 'Joint trust score', value: '${trust.jointTrustScore}★'),
          _StatRow(
              label: 'Successful collaborations',
              value: '${trust.successfulCollaborations}'),
          _StatRow(label: 'Partnership duration', value: '${trust.durationDays} days'),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('Participating businesses',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        ...partnership.members.map(
          (m) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text(m.businessName.isNotEmpty ? m.businessName[0] : '?')),
            title: Text(m.businessName),
            subtitle: Text('${m.role} · ${m.averageRating.toStringAsFixed(1)}★'),
            trailing: m.verificationStatus == 'verified'
                ? const Icon(Icons.verified, color: AppColors.primary, size: 18)
                : null,
            onTap: () => context.push('/seller/${m.sellerId}'),
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TeamTab extends StatelessWidget {
  const _TeamTab({required this.partnership});

  final PartnershipModel partnership;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      children: [
        Text('Roles & permissions',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        ...partnership.members.map(
          (m) => Card(
            child: ListTile(
              title: Text(m.businessName),
              subtitle: Text(
                '${m.role.replaceAll('_', ' ')} · Trust ${m.trustScore.toStringAsFixed(1)}',
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnalyticsTab extends ConsumerWidget {
  const _AnalyticsTab({required this.partnershipId});

  final String partnershipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(partnershipAnalyticsProvider(partnershipId));
    return analyticsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Analytics unavailable')),
      data: (a) => ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          _StatRow(label: 'Shared listings', value: '${a.activeListings}/${a.totalListings}'),
          _StatRow(label: 'Collaborations', value: '${a.fulfilledCollaborations}/${a.totalCollaborations}'),
          _StatRow(label: 'Shared stock', value: '${a.totalSharedStock} (${a.reservedStock} reserved)'),
          _StatRow(label: 'Revenue records', value: '${a.revenueRecordsCount}'),
          _StatRow(label: 'Total revenue', value: '${a.totalRevenueMad.toStringAsFixed(0)} MAD'),
          _StatRow(label: 'Chat messages', value: '${a.chatMessagesCount}'),
        ],
      ),
    );
  }
}

class _ChatTab extends ConsumerStatefulWidget {
  const _ChatTab({required this.partnershipId, required this.controller});

  final String partnershipId;
  final TextEditingController controller;

  @override
  ConsumerState<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<_ChatTab> {
  List<PartnershipChatMessageModel> _messages = [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final messages =
        await apiServiceProvider.fetchPartnershipChat(widget.partnershipId);
    if (mounted) {
      setState(() {
        _messages = messages;
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final body = widget.controller.text.trim();
    if (body.isEmpty) return;
    widget.controller.clear();
    await apiServiceProvider.sendPartnershipChat(widget.partnershipId, body);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            itemCount: _messages.length,
            itemBuilder: (_, i) {
              final m = _messages[i];
              return Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardUnselected,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(m.body),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    decoration: const InputDecoration(
                      hintText: 'Message partners…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.partnership});

  final PartnershipModel partnership;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      children: [
        ListTile(
          title: const Text('Partnership type'),
          subtitle: Text(partnership.partnershipType.replaceAll('_', ' ')),
        ),
        ListTile(
          title: const Text('Marketplace'),
          subtitle: Text(partnership.marketplaceSlug.isEmpty
              ? 'Any'
              : partnership.marketplaceSlug),
        ),
        ListTile(
          title: const Text('Categories'),
          subtitle: Text(partnership.categorySlugs.isEmpty
              ? 'None'
              : partnership.categorySlugs.join(', ')),
        ),
        ListTile(
          title: const Text('Your role'),
          subtitle: Text(partnership.myRole ?? '—'),
        ),
      ],
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
