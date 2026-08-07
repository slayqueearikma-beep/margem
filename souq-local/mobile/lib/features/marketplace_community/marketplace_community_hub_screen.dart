import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/marketplace_community_models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../l10n/app_localizations.dart';

final marketplaceCommunityHubProvider = FutureProvider.autoDispose
    .family<MarketplaceCommunityHubModel, String>((ref, slug) {
  return apiServiceProvider.fetchMarketplaceCommunityHub(slug, auth: true);
});

final marketplaceCommunityChannelsProvider = FutureProvider.autoDispose
    .family<List<MarketplaceCommunityChannelModel>, String>((ref, slug) {
  return apiServiceProvider.fetchMarketplaceCommunityChannels(slug, auth: true);
});

class MarketplaceCommunityHubScreen extends ConsumerWidget {
  const MarketplaceCommunityHubScreen({super.key, required this.marketplaceSlug});

  final String marketplaceSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final hubAsync = ref.watch(marketplaceCommunityHubProvider(marketplaceSlug));
    final channelsAsync = ref.watch(marketplaceCommunityChannelsProvider(marketplaceSlug));
    final session = ref.watch(userSessionProvider);
    final isGuest = session == null || session.isGuest;

    return BuyerScreenScaffold(
      appBar: BuyerAppBar(title: l10n.marketplaceCommunityTitle),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(marketplaceCommunityHubProvider(marketplaceSlug));
          ref.invalidate(marketplaceCommunityChannelsProvider(marketplaceSlug));
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          children: [
            hubAsync.when(
              data: (hub) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hub.marketplaceName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.marketplaceCommunitySubtitle,
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _StatChip(label: l10n.communityMembers, value: '${hub.memberCount}'),
                      _StatChip(label: l10n.communityOnline, value: '${hub.onlineCount}'),
                    ],
                  ),
                  if (!hub.isMember && !isGuest) ...[
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () async {
                        await apiServiceProvider.joinMarketplaceCommunity(marketplaceSlug);
                        ref.invalidate(marketplaceCommunityHubProvider(marketplaceSlug));
                      },
                      child: Text(l10n.marketplaceCommunityJoin),
                    ),
                  ],
                  if (isGuest) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.communityGuestHint, style: TextStyle(color: context.colors.textSecondary)),
                  ],
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AsyncErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(marketplaceCommunityHubProvider(marketplaceSlug)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.marketplaceCommunityChannels,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: AppSpacing.sm),
            channelsAsync.when(
              data: (channels) => Column(
                children: channels
                    .map(
                      (channel) => Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(channel.name.isNotEmpty ? channel.name[0] : '?'),
                          ),
                          title: Text(channel.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(channel.description),
                          trailing: Text('${channel.messageCount}'),
                          onTap: () async {
                            if (isGuest) {
                              context.push('/login');
                              return;
                            }
                            final hub = hubAsync.valueOrNull;
                            if (hub != null && !hub.isMember) {
                              await apiServiceProvider.joinMarketplaceCommunity(marketplaceSlug);
                            }
                            if (!context.mounted) return;
                            context.push(
                              '/marketplace/$marketplaceSlug/community/channels/${channel.id}',
                              extra: {
                                'channelName': channel.name,
                                'defaultPostType': channel.defaultPostType,
                              },
                            );
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => AsyncErrorView(
                message: e.toString(),
                onRetry: () =>
                    ref.invalidate(marketplaceCommunityChannelsProvider(marketplaceSlug)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}
