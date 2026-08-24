import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../core/widgets/content_widgets.dart';
import '../../core/widgets/network_image_view.dart';
import '../../core/widgets/seller_trust_indicators.dart';
import '../../features/buyer/buyer_home_screen.dart';
import '../../l10n/app_localizations.dart';

final marketplaceDetailProvider =
    FutureProvider.autoDispose.family<MarketplaceVenueModel, String>((ref, slug) {
  return apiServiceProvider.fetchMarketplace(slug);
});

final marketplaceCategoriesProvider =
    FutureProvider.autoDispose.family<List<CategoryModel>, String>((ref, slug) {
  return apiServiceProvider.fetchMarketplaceCategories(slug);
});

final marketplaceFeaturedProvider =
    FutureProvider.autoDispose.family<List<SellerModel>, String>((ref, slug) {
  return apiServiceProvider.fetchMarketplaceFeatured(slug);
});

final marketplaceSellersProvider =
    FutureProvider.autoDispose.family<List<SellerModel>, String>((ref, slug) {
  return apiServiceProvider.fetchMarketplaceSellers(slug);
});

class MarketplaceDetailScreen extends ConsumerWidget {
  const MarketplaceDetailScreen({super.key, required this.slug});

  final String slug;

  void _searchInMarket(BuildContext context, WidgetRef ref, {String? category}) {
    ref.read(buyerMarketplaceSlugProvider.notifier).state = slug;
    ref.read(appStorageProvider)?.setMarketplaceSlug(slug);
    if (category != null) {
      ref.read(buyerCategorySlugProvider.notifier).state = category;
    }
    ref.read(buyerTabIndexProvider.notifier).state = 1;
    context.go('/buyer/home');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final venueAsync = ref.watch(marketplaceDetailProvider(slug));

    return BuyerScreenScaffold(
      appBar: BuyerAppBar(
        title: venueAsync.valueOrNull?.displayName ?? l10n.marketDiscoveryTitle,
      ),
      body: venueAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colors.primary),
        ),
        error: (error, _) => AsyncErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(marketplaceDetailProvider(slug)),
        ),
        data: (venue) {
          final categoriesAsync = ref.watch(marketplaceCategoriesProvider(slug));
          final featuredAsync = ref.watch(marketplaceFeaturedProvider(slug));
          final sellersAsync = ref.watch(marketplaceSellersProvider(slug));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(marketplaceDetailProvider(slug));
              ref.invalidate(marketplaceCategoriesProvider(slug));
              ref.invalidate(marketplaceFeaturedProvider(slug));
              ref.invalidate(marketplaceSellersProvider(slug));
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              children: [
                Text(
                  venue.displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (venue.district.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${venue.district}, ${venue.city}',
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(venue.description, style: Theme.of(context).textTheme.bodyMedium),
                if (venue.knownFor.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  BuyerSurfaceCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.marketKnownFor,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(venue.knownFor),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                BuyerSearchBar(
                  hint: l10n.searchThisMarketHint(venue.displayName),
                  onTap: () => _searchInMarket(context, ref),
                  onFilter: () => _searchInMarket(context, ref),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.read(buyerMarketplaceSlugProvider.notifier).state = slug;
                        context.push('/map');
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: Text(l10n.openMarketMap),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/marketplace/$slug/community'),
                      icon: const Icon(Icons.forum_outlined),
                      label: Text(l10n.marketplaceCommunityTitle),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.marketCategoriesTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                categoriesAsync.when(
                  data: (categories) {
                    if (categories.isEmpty) {
                      return Text(l10n.noSellersInMarketSubtitle);
                    }
                    return Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: categories.map((cat) {
                        return ActionChip(
                          label: Text(cat.localizedName(
                            Localizations.localeOf(context).languageCode,
                          )),
                          onPressed: () => _searchInMarket(context, ref, category: cat.slug),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => Text(l10n.somethingWentWrong),
                ),
                const SizedBox(height: AppSpacing.lg),
                featuredAsync.when(
                  data: (featured) {
                    if (featured.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.featuredSellersTitle,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            Text(
                              l10n.sponsoredLabel,
                              style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ...featured.map(
                          (seller) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _MarketSellerTile(seller: seller),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                Text(
                  l10n.marketShopsTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                sellersAsync.when(
                  data: (sellers) {
                    if (sellers.isEmpty) {
                      return BuyerEmptyState(
                        icon: Icons.storefront_outlined,
                        title: l10n.noSellersInMarket,
                        subtitle: l10n.noSellersInMarketSubtitle,
                      );
                    }
                    return Column(
                      children: sellers
                          .map(
                            (seller) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _MarketSellerTile(seller: seller),
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => AsyncErrorView.fromError(
                    error,
                    onRetry: () => ref.invalidate(marketplaceSellersProvider(slug)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MarketSellerTile extends StatelessWidget {
  const _MarketSellerTile({required this.seller});

  final SellerModel seller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push('/seller/${seller.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: context.colors.surfaceVariant,
                child: seller.logoImageUrl.isNotEmpty
                    ? ClipOval(
                        child: NetworkImageView(url: seller.logoImageUrl),
                      )
                    : Icon(Icons.storefront, color: context.colors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seller.businessName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (seller.isPremium)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          context.l10n.sponsoredLabel,
                          style: TextStyle(
                            color: context.colors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    SellerTrustIndicators(seller: seller, compact: true),
                    if (seller.stallLocationSummary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        seller.stallLocationSummary,
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
