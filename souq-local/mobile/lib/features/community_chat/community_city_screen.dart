import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/community_models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/directional_ui.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/design_system_components.dart';
import '../../core/widgets/margem_background.dart';
import '../../l10n/app_localizations.dart';
import 'community_providers.dart';

class CommunityCityScreen extends ConsumerWidget {
  const CommunityCityScreen({super.key, this.citySlug});

  final String? citySlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final String slug = citySlug ?? ref.watch(communityCitySlugProvider);
    final cityAsync = ref.watch(communityCitiesProvider);
    final channelsAsync = ref.watch(communityChannelsProvider(slug));
    final session = ref.watch(userSessionProvider);
    final isGuest = session == null || session.isGuest;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MargemBackground(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.transparent,
              title: Text(l10n.communityChatTitle),
              actions: [
                IconButton(
                  icon: const Icon(Icons.explore_outlined),
                  onPressed: () => _showDiscoverSheet(context, ref),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: cityAsync.when(
                data: (cities) {
                  final city = cities.firstWhere(
                    (c) => c.slug == slug,
                    orElse: () => cities.isNotEmpty
                        ? cities.first
                        : CommunityCityModel(
                            id: '',
                            slug: slug,
                            name: slug,
                          ),
                  );
                  return _CityBanner(city: city, isGuest: isGuest);
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => AsyncErrorView.fromError(
                  e,
                  onRetry: () => ref.invalidate(communityCitiesProvider),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.md,
                  AppSpacing.screenHorizontal,
                  AppSpacing.sm,
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: l10n.communitySearchHint,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  ),
                  onChanged: (value) =>
                      ref.read(communitySearchQueryProvider.notifier).state =
                          value,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      AppChip(
                        label: l10n.communityFilterAll,
                        selected:
                            ref.watch(communitySelectedCategoryProvider) ==
                                null,
                        onTap: () => ref
                            .read(communitySelectedCategoryProvider.notifier)
                            .state = null,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppChip(
                        label: l10n.communityFilterVerified,
                        selected: ref.watch(communityVerifiedFilterProvider),
                        onTap: () => ref
                            .read(communityVerifiedFilterProvider.notifier)
                            .state = !ref.read(communityVerifiedFilterProvider),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppChip(
                        label: l10n.communityFilterTrusted,
                        selected: ref.watch(communityTrustedFilterProvider),
                        onTap: () => ref
                            .read(communityTrustedFilterProvider.notifier)
                            .state = !ref.read(communityTrustedFilterProvider),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            channelsAsync.when(
              data: (channels) {
                final selected =
                    ref.watch(communitySelectedCategoryProvider);
                final query = ref.watch(communitySearchQueryProvider).toLowerCase();
                final filtered = channels.where((ch) {
                  if (selected != null && ch.category != selected) return false;
                  if (query.isNotEmpty &&
                      !ch.name.toLowerCase().contains(query) &&
                      !ch.description.toLowerCase().contains(query)) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    child: AppEmptyState(
                      title: l10n.communityNoChannels,
                      subtitle: l10n.communityNoChannelsSubtitle,
                      icon: Icons.forum_outlined,
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, index) {
                      final channel = filtered[index];
                      return _ChannelTile(
                        channel: channel,
                        onTap: () async {
                          if (isGuest) {
                            context.push('/login');
                            return;
                          }
                          final cities = ref.read(communityCitiesProvider).valueOrNull;
                          final city = cities?.firstWhere(
                            (c) => c.slug == slug,
                            orElse: () => CommunityCityModel(
                              id: '',
                              slug: slug,
                              name: slug,
                            ),
                          );
                          if (city != null && !city.isMember) {
                            await apiServiceProvider.joinCommunityCity(
                              slug,
                              isHomeCity: true,
                            );
                            ref.invalidate(communityCitiesProvider);
                          }
                          if (context.mounted) {
                            context.push(
                              '/community/channels/${channel.id}',
                              extra: {
                                'channelName': channel.name,
                                'citySlug': slug,
                              },
                            );
                          }
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: AsyncErrorView.fromError(
                  e,
                  onRetry: () =>
                      ref.invalidate(communityChannelsProvider(slug)),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isGuest
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                final channels = channelsAsync.valueOrNull;
                if (channels == null || channels.isEmpty) return;
                final general = channels.firstWhere(
                  (c) => c.category == 'general',
                  orElse: () => channels.first,
                );
                context.push(
                  '/community/channels/${general.id}',
                  extra: {
                    'channelName': general.name,
                    'citySlug': slug,
                  },
                );
              },
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.communityNewMessage),
            ),
    );
  }

  void _showDiscoverSheet(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final discover = ref.watch(communityDiscoverProvider);
          return discover.when(
            data: (data) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.communityDiscoverTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...data.trending.map(
                      (city) => ListTile(
                        leading: const Icon(Icons.trending_up_rounded),
                        title: Text(city.name),
                        subtitle: Text(
                          '${city.memberCount} ${l10n.communityMembers} · ${city.onlineCount} ${l10n.communityOnline}',
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          context.push('/community/${city.slug}');
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(e.toString()),
            ),
          );
        },
      ),
    );
  }
}

class _CityBanner extends StatelessWidget {
  const _CityBanner({required this.city, required this.isGuest});

  final CommunityCityModel city;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.all(AppSpacing.screenHorizontal),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.lavender.withValues(alpha: 0.18),
            AppColors.peach.withValues(alpha: 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadiusLg),
        border: Border.all(color: AppColors.outlineSubtle(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            city.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            city.description.isNotEmpty
                ? city.description
                : l10n.communityCitySubtitle(city.name),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _StatChip(
                icon: Icons.people_outline,
                label: '${city.memberCount} ${l10n.communityMembers}',
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatChip(
                icon: Icons.circle,
                iconColor: AppColors.success,
                label: '${city.onlineCount} ${l10n.communityOnline}',
              ),
            ],
          ),
          if (isGuest) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.communityGuestHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor ?? AppColors.lavender),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.channel, required this.onTap});

  final CommunityChannelModel channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accentMuted(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _iconForCategory(channel.category),
            color: AppColors.lavender,
          ),
        ),
        title: Text(channel.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          channel.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: channel.messageCount > 0
            ? AppBadge(label: '${channel.messageCount}', small: true)
            : Icon(DirectionalUi.forwardChevron(context)),
      ),
    );
  }

  IconData _iconForCategory(String category) {
    return switch (category) {
      'marketplace' => Icons.storefront_outlined,
      'recommendations' => Icons.thumb_up_outlined,
      'questions' => Icons.help_outline_rounded,
      'events' => Icons.event_outlined,
      'jobs' => Icons.work_outline_rounded,
      'housing' => Icons.home_outlined,
      'services' => Icons.handyman_outlined,
      'food' => Icons.restaurant_outlined,
      'transportation' => Icons.directions_bus_outlined,
      'emergency_alerts' => Icons.warning_amber_rounded,
      'announcements' => Icons.campaign_outlined,
      _ => Icons.chat_bubble_outline_rounded,
    };
  }
}
