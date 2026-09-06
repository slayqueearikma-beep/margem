import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import 'marketplace_community_providers.dart';

/// Join / open marketplace community actions shown on marketplace discovery pages.
class MarketplaceCommunityActions extends ConsumerWidget {
  const MarketplaceCommunityActions({
    super.key,
    required this.marketplaceSlug,
    this.fullWidth = true,
  });

  final String marketplaceSlug;
  final bool fullWidth;

  Future<void> _openHub(BuildContext context) {
    return context.push('/marketplace/$marketplaceSlug/community');
  }

  Future<void> _joinAndOpen(BuildContext context, WidgetRef ref) async {
    await apiServiceProvider.joinMarketplaceCommunity(marketplaceSlug);
    ref.invalidate(marketplaceCommunityHubProvider(marketplaceSlug));
    if (!context.mounted) return;
    await _openHub(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final isGuest = session == null || session.isGuest;

    if (isGuest) {
      return _wrap(
        FilledButton.icon(
          onPressed: () => context.push('/login'),
          icon: const Icon(Icons.group_add_outlined),
          label: Text(l10n.marketplaceCommunityJoin),
        ),
      );
    }

    final hubAsync = ref.watch(marketplaceCommunityHubProvider(marketplaceSlug));
    return hubAsync.when(
      loading: () => _wrap(
        const SizedBox(
          height: 48,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (_, __) => _wrap(
        FilledButton.icon(
          onPressed: () => _openHub(context),
          icon: const Icon(Icons.group_add_outlined),
          label: Text(l10n.marketplaceCommunityJoin),
        ),
      ),
      data: (hub) {
        if (hub.isMember) {
          return _wrap(
            OutlinedButton.icon(
              onPressed: () => _openHub(context),
              icon: const Icon(Icons.forum_outlined),
              label: Text(l10n.marketplaceCommunityTitle),
            ),
          );
        }
        return _wrap(
          FilledButton.icon(
            onPressed: () => _joinAndOpen(context, ref),
            icon: const Icon(Icons.group_add_outlined),
            label: Text(l10n.marketplaceCommunityJoin),
          ),
        );
      },
    );
  }

  Widget _wrap(Widget child) {
    if (!fullWidth) return child;
    return SizedBox(width: double.infinity, child: child);
  }
}

/// Compact join/open control for marketplace list rows.
class MarketplaceCommunityIconAction extends ConsumerWidget {
  const MarketplaceCommunityIconAction({
    super.key,
    required this.marketplaceSlug,
  });

  final String marketplaceSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final isGuest = session == null || session.isGuest;

    Future<void> open() => context.push('/marketplace/$marketplaceSlug/community');

    Future<void> joinAndOpen() async {
      if (isGuest) {
        await context.push('/login');
        return;
      }
      final hub = ref.read(marketplaceCommunityHubProvider(marketplaceSlug)).valueOrNull;
      if (hub != null && !hub.isMember) {
        await apiServiceProvider.joinMarketplaceCommunity(marketplaceSlug);
        ref.invalidate(marketplaceCommunityHubProvider(marketplaceSlug));
      }
      if (!context.mounted) return;
      await open();
    }

    return IconButton(
      tooltip: l10n.marketplaceCommunityJoin,
      onPressed: joinAndOpen,
      icon: Icon(Icons.group_add_outlined, color: Theme.of(context).colorScheme.primary),
    );
  }
}

/// Text link variant for inline placement under marketplace chips.
class MarketplaceCommunityJoinLink extends ConsumerWidget {
  const MarketplaceCommunityJoinLink({super.key, required this.marketplaceSlug});

  final String marketplaceSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: MarketplaceCommunityActions(
        marketplaceSlug: marketplaceSlug,
        fullWidth: false,
      ),
    );
  }
}
