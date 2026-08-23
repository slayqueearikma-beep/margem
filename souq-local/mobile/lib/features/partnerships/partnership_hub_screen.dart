import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import 'partnership_models.dart';
import 'partnership_widgets.dart';

final partnershipsProvider = FutureProvider.autoDispose<List<PartnershipModel>>((ref) {
  return apiServiceProvider.fetchPartnerships();
});

final partnershipInvitationsProvider =
    FutureProvider.autoDispose<List<PartnershipInvitationModel>>((ref) {
  return apiServiceProvider.fetchPartnershipInvitations();
});

class PartnershipHubScreen extends ConsumerWidget {
  const PartnershipHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnershipsAsync = ref.watch(partnershipsProvider);
    final invitationsAsync = ref.watch(partnershipInvitationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partnerships'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(partnershipsProvider);
          ref.invalidate(partnershipInvitationsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          children: [
            invitationsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (invites) {
                if (invites.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending invitations',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...invites.map((inv) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.mail_outline,
                                color: AppColors.primary),
                            title: Text(inv.partnershipName),
                            subtitle: Text('From ${inv.inviterName}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: AppColors.danger),
                                  onPressed: () async {
                                    await apiServiceProvider
                                        .declinePartnershipInvitation(inv.id);
                                    ref.invalidate(partnershipInvitationsProvider);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check,
                                      color: AppColors.success),
                                  onPressed: () async {
                                    await apiServiceProvider
                                        .acceptPartnershipInvitation(inv.id);
                                    ref.invalidate(partnershipInvitationsProvider);
                                    ref.invalidate(partnershipsProvider);
                                  },
                                ),
                              ],
                            ),
                          ),
                        )),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                );
              },
            ),
            partnershipsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => AsyncErrorView(
                message: error is ApiException
                    ? error.message
                    : 'Could not load partnerships',
                onRetry: () => ref.invalidate(partnershipsProvider),
              ),
              data: (partnerships) {
                if (partnerships.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Column(
                      children: [
                        Icon(Icons.handshake_outlined,
                            size: 64, color: AppColors.textSecondary),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No partnerships yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Collaborate with other sellers, share listings, and serve customers together.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your partnerships',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...partnerships.map(
                      (p) => Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.cardSelected,
                            child: Icon(Icons.handshake,
                                color: AppColors.primary),
                          ),
                          title: Text(p.name),
                          subtitle: Text(
                            '${p.members.length} members · ${p.partnershipType.replaceAll('_', ' ')}',
                          ),
                          trailing: PartnershipStatusChip(status: p.status),
                          onTap: () =>
                              context.push('/seller/partnerships/${p.id}'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    var selectedType = 'long_term';
    var marketplace = '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New partnership'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Partnership name'),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'temporary', child: Text('Temporary')),
                  DropdownMenuItem(value: 'long_term', child: Text('Long-term')),
                  DropdownMenuItem(
                      value: 'supplier_retailer', child: Text('Supplier & Retailer')),
                  DropdownMenuItem(
                      value: 'service_provider', child: Text('Service Provider')),
                  DropdownMenuItem(value: 'wholesale', child: Text('Wholesale')),
                  DropdownMenuItem(value: 'multi_shop', child: Text('Multi-shop')),
                ],
                onChanged: (v) => selectedType = v ?? selectedType,
              ),
              DropdownButtonFormField<String>(
                value: marketplace.isEmpty ? null : marketplace,
                decoration: const InputDecoration(labelText: 'Marketplace (optional)'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Any')),
                  DropdownMenuItem(value: 'derb-ghallef', child: Text('Derb Ghallef')),
                  DropdownMenuItem(value: 'derb-omar', child: Text('Derb Omar')),
                  DropdownMenuItem(value: '9ri3a', child: Text('9ri3a')),
                ],
                onChanged: (v) => marketplace = v ?? '',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await apiServiceProvider.createPartnership(
                name: nameController.text.trim(),
                description: descController.text.trim(),
                partnershipType: selectedType,
                marketplaceSlug: marketplace,
              );
              if (context.mounted) Navigator.pop(ctx);
              ref.invalidate(partnershipsProvider);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
