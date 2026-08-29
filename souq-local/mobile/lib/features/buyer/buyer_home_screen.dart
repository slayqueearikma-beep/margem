import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/ads/full_page_ad_gate.dart';
import '../../core/config/app_config.dart';
import '../../core/data/city_coordinates.dart';
import '../../core/models/models.dart';
import '../../core/navigation/app_back_handler.dart';
import '../../core/providers/city_providers.dart';
import '../../core/providers/subscription_providers.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/theme_mode_provider.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/utils/directional_ui.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/buyer_drawer.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../core/widgets/content_widgets.dart';
import '../../core/widgets/error_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../messages/messages_inbox_screen.dart';
import '../../core/providers/subscription_providers.dart';
import '../search/search_screen.dart';
import '../settings/language_settings_tile.dart';

final buyerMarketplacesProvider =
    FutureProvider.autoDispose<List<MarketplaceVenueModel>>(
        (ref) => apiServiceProvider.fetchMarketplaces(city: ref.watch(buyerCityProvider)));

final buyerMarketplaceSlugProvider = StateProvider<String?>((ref) {
  return ref.read(appStorageProvider)?.getMarketplaceSlug();
});

String? validatedMarketplaceSlug(
  String? slug,
  List<MarketplaceVenueModel> marketplaces,
) {
  if (slug == null || slug.isEmpty) return null;
  return marketplaces.any((market) => market.slug == slug) ? slug : null;
}

final buyerCategorySlugProvider = StateProvider<String?>((ref) => null);

final buyerTabIndexProvider = StateProvider<int>((ref) => 0);

final buyerSellersProvider =
    FutureProvider.autoDispose<List<SellerModel>>((ref) async {
  final city = ref.watch(buyerCityProvider);
  final marketplaces = await ref.watch(buyerMarketplacesProvider.future);
  final slug = ref.watch(buyerMarketplaceSlugProvider);
  final marketplace = validatedMarketplaceSlug(slug, marketplaces);
  return apiServiceProvider.fetchSellers(
    city: city,
    marketplace: marketplace,
  );
});

final buyerCategoriesProvider =
    FutureProvider.autoDispose<List<CategoryModel>>((ref) async {
  final marketplaces = ref.watch(buyerMarketplacesProvider).valueOrNull ?? const [];
  final slug = validatedMarketplaceSlug(
    ref.watch(buyerMarketplaceSlugProvider),
    marketplaces,
  );
  if (slug != null && slug.isNotEmpty) {
    return apiServiceProvider.fetchMarketplaceCategories(slug);
  }
  return apiServiceProvider.fetchCategories();
});

final buyerFavoriteSellerIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final session = ref.watch(userSessionProvider);
  if (session == null || session.isGuest) {
    final local =
        ref.read(appStorageProvider)?.getGuestFavoriteItems() ?? const [];
    return local
        .where((item) => item.sellerId.isNotEmpty && item.productId.isEmpty)
        .map((item) => item.sellerId)
        .toSet();
  }
  try {
    final favorites = await apiServiceProvider.fetchFavorites();
    return favorites
        .where((item) => item.sellerId.isNotEmpty && item.productId.isEmpty)
        .map((item) => item.sellerId)
        .toSet();
  } catch (error) {
    // Surface as provider error instead of looking like an empty favorites list.
    rethrow;
  }
});

class BuyerHomeShell extends ConsumerWidget {
  const BuyerHomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final index = ref.watch(buyerTabIndexProvider).clamp(0, 2);

    return RootBackScope(
      child: FullPageAdGate(
        child: BuyerScreenScaffold(
          drawer: const BuyerDrawer(),
          body: IndexedStack(
            index: index,
            children: [
              const BuyerHomeScreen(),
              SearchScreen(autofocusSearch: index == 1),
              const MessagesInboxScreen(),
            ],
          ),
          bottomNavigationBar: Consumer(
            builder: (context, ref, _) {
              final unread =
                  ref.watch(conversationsUnreadCountProvider).valueOrNull ?? 0;
              return BuyerBottomNavBar(
                selectedIndex: index,
                onSelected: (i) =>
                    ref.read(buyerTabIndexProvider.notifier).state = i,
                badges: {2: unread},
                items: [
                  BuyerNavItem(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home_rounded,
                    label: l10n.navHome,
                  ),
                  BuyerNavItem(
                    icon: Icons.explore_outlined,
                    selectedIcon: Icons.explore_rounded,
                    label: l10n.navSearch,
                  ),
                  BuyerNavItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    selectedIcon: Icons.chat_bubble_rounded,
                    label: l10n.navMessages,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class BuyerHomeScreen extends ConsumerWidget {
  const BuyerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final city = ref.watch(buyerCityProvider);
    final sellersAsync = ref.watch(buyerSellersProvider);
    final categoriesAsync = ref.watch(buyerCategoriesProvider);
    final marketplacesAsync = ref.watch(buyerMarketplacesProvider);
    final selectedMarketplace = ref.watch(buyerMarketplaceSlugProvider);
    final favoriteIds = ref.watch(buyerFavoriteSellerIdsProvider).valueOrNull ??
        const <String>{};
    final searchOrigin = ref.watch(buyerSearchLocationProvider).valueOrNull ??
        CityCoordinates.centerFor(city);
    final isGuest = session == null || session.isGuest;
    final hasPremium = ref.watch(authSessionProvider)?.user.showPlusBadge ??
        hasPlusPlusEntitlement(ref.watch(myEntitlementsProvider).valueOrNull);

    final firstName = session?.name.split(' ').first ?? l10n.guestMode;

    void openMenu() {
      Scaffold.of(context).openDrawer();
    }

    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BuyerShellHeader(
                  onMenu: openMenu,
                  onNotifications: () {
                    if (isGuest) {
                      context.push('/login');
                      return;
                    }
                    if (session.accountType == AccountType.seller) {
                      context.push('/seller/notifications');
                      return;
                    }
                    ref.read(buyerTabIndexProvider.notifier).state = 2;
                  },
                  onProfile: () => context.push('/profile'),
                  showPremiumBadge: hasPremium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  child: BuyerLocationRow(city: city, onTap: null),
                ),
                marketplacesAsync.when(
                  data: (marketplaces) {
                    if (marketplaces.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final activeSlug = selectedMarketplace != null &&
                            marketplaces.any((m) => m.slug == selectedMarketplace)
                        ? selectedMarketplace
                        : marketplaces.first.slug;
                    if (activeSlug != selectedMarketplace) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ref.read(buyerMarketplaceSlugProvider.notifier).state =
                            activeSlug;
                        ref.read(appStorageProvider)?.setMarketplaceSlug(activeSlug);
                      });
                    }
                    return Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.md,
                        left: AppSpacing.screenHorizontal,
                      ),
                      child: SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: marketplaces.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: AppSpacing.sm),
                          itemBuilder: (_, index) {
                            final venue = marketplaces[index];
                            final isSelected = venue.slug == activeSlug;
                            return ChoiceChip(
                              label: Text(venue.displayName),
                              selected: isSelected,
                              onSelected: (_) {
                                ref
                                    .read(buyerMarketplaceSlugProvider.notifier)
                                    .state = venue.slug;
                                ref
                                    .read(appStorageProvider)
                                    ?.setMarketplaceSlug(venue.slug);
                                ref.invalidate(buyerCategoriesProvider);
                                ref.invalidate(buyerSellersProvider);
                              },
                            );
                          },
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox(height: AppSpacing.md),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                if (selectedMarketplace != null && selectedMarketplace!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.sm,
                      left: AppSpacing.screenHorizontal,
                      right: AppSpacing.screenHorizontal,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => context.push(
                          '/marketplace/$selectedMarketplace/community',
                        ),
                        icon: const Icon(Icons.forum_outlined),
                        label: Text(l10n.marketplaceCommunityTitle),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  child: BuyerGreetingBlock(
                    greeting: l10n.buyerHello(firstName),
                    subtitle: l10n.marketDiscoveryHomeSubtitle,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  child: BuyerSearchBar(
                    hint: l10n.marketDiscoverySearchHint,
                    onTap: () =>
                        ref.read(buyerTabIndexProvider.notifier).state = 1,
                    onFilter: () =>
                        ref.read(buyerTabIndexProvider.notifier).state = 1,
                  ),
                ),
                marketplacesAsync.when(
                  data: (marketplaces) {
                    if (marketplaces.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenHorizontal,
                        AppSpacing.lg,
                        AppSpacing.screenHorizontal,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.popularMarketsTitle,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ...marketplaces.take(6).map(
                            (venue) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () {
                                    ref
                                        .read(buyerMarketplaceSlugProvider.notifier)
                                        .state = venue.slug;
                                    ref
                                        .read(appStorageProvider)
                                        ?.setMarketplaceSlug(venue.slug);
                                    ref.invalidate(buyerCategoriesProvider);
                                    ref.invalidate(buyerSellersProvider);
                                    context.push('/marketplace/${venue.slug}');
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(AppSpacing.md),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: context.colors.primaryMuted,
                                          child: Icon(
                                            Icons.store_mall_directory_outlined,
                                            color: context.colors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                venue.displayName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (venue.knownFor.isNotEmpty)
                                                Text(
                                                  venue.knownFor,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: context.colors.textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              Text(
                                                l10n.marketSellerCount(venue.sellerCount),
                                                style: TextStyle(
                                                  color: context.colors.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: l10n.marketplaceCommunityTitle,
                                          onPressed: () => context.push(
                                            '/marketplace/${venue.slug}/community',
                                          ),
                                          icon: Icon(
                                            Icons.forum_outlined,
                                            color: context.colors.primary,
                                          ),
                                        ),
                                        Icon(
                                          DirectionalUi.forwardChevron(context),
                                          color: context.colors.textSecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox(height: AppSpacing.md),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                if (isGuest) ...[
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                    ),
                    child: _GuestModeBanner(
                      title: l10n.guestMode,
                      subtitle: l10n.guestModeSubtitle,
                      loginLabel: l10n.createAccount,
                      onLogin: () => context.push('/onboarding/account-type'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          categoriesAsync.when(
            data: (categories) {
              final quick = categories.take(4).toList();
              return SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenHorizontal,
                        ),
                        scrollDirection: Axis.horizontal,
                        itemCount: quick.length + 1,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (_, i) {
                          if (i == quick.length) {
                            return BuyerQuickCategoryTile(
                              label: l10n.seeAll,
                              icon: Icons.grid_view_rounded,
                              onTap: () => ref
                                  .read(buyerTabIndexProvider.notifier)
                                  .state = 1,
                            );
                          }
                          final cat = quick[i];
                          return BuyerQuickCategoryTile(
                            label: cat.localizedName(
                              Localizations.localeOf(context).languageCode,
                            ),
                            icon: _categoryIcon(cat.icon),
                            tint: i.isEven
                                ? context.colors.surfaceVariant
                                : context.colors.surface,
                            onTap: () {
                              ref
                                  .read(buyerCategorySlugProvider.notifier)
                                  .state = cat.slug;
                              ref.read(buyerTabIndexProvider.notifier).state = 1;
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox(height: 8)),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          sellersAsync.when(
            data: (sellers) {
              if (sellers.isEmpty) {
                final hasMarketScope =
                    selectedMarketplace != null && selectedMarketplace!.isNotEmpty;
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                      child: Text(
                        hasMarketScope
                            ? '${l10n.noSellersInMarket}\n${l10n.noSellersInMarketSubtitle}'
                            : l10n.noBusinessesInCity,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }

              final featured = sellers.take(8).toList();

              return SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: AppSpacing.lg),
                  BuyerSectionHeader(
                    title: l10n.nearbyBusinesses,
                    actionLabel: l10n.seeAll,
                    onAction: () =>
                        ref.read(buyerTabIndexProvider.notifier).state = 1,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 268,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenHorizontal,
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: featured.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.md),
                      itemBuilder: (_, i) {
                        final seller = featured[i];
                        final category = seller.categories.isNotEmpty
                            ? seller.categories.first.localizedName(
                                Localizations.localeOf(context).languageCode,
                              )
                            : l10n.localBusiness;
                        return BuyerNearYouCard(
                          title: seller.businessName,
                          subtitle: category,
                          priceLabel: '',
                          distanceLabel: _distanceLabel(
                            searchOrigin,
                            LatLng(seller.latitude, seller.longitude),
                          ),
                          locationLabel: seller.city,
                          rating: seller.averageRating,
                          imageUrl: seller.coverImageUrl.isNotEmpty
                              ? seller.coverImageUrl
                              : seller.logoImageUrl,
                          sellerAvatarUrl: seller.logoImageUrl,
                          isFavorite: favoriteIds.contains(seller.id),
                          onTap: () => context.push('/seller/${seller.id}'),
                          onFavorite: () =>
                              _toggleFavoriteSeller(context, ref, seller),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  BuyerSectionHeader(title: l10n.popularCategories),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                    ),
                    child: categoriesAsync.maybeWhen(
                      data: (categories) {
                        final popular = categories.take(6).toList();
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: AppSpacing.sm,
                            crossAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 0.92,
                          ),
                          itemCount: popular.length,
                          itemBuilder: (_, i) {
                            final cat = popular[i];
                            return BuyerPopularCategoryCard(
                              label: cat.localizedName(
                                Localizations.localeOf(context).languageCode,
                              ),
                              icon: _categoryIcon(cat.icon),
                              tint: i.isEven
                                  ? context.colors.surfaceVariant
                                  : context.colors.surface,
                              onTap: () {
                                ref
                                    .read(buyerCategorySlugProvider.notifier)
                                    .state = cat.slug;
                                ref.read(buyerTabIndexProvider.notifier).state =
                                    1;
                              },
                            );
                          },
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  BuyerSectionHeader(title: l10n.featuredBusinesses),
                  const SizedBox(height: AppSpacing.sm),
                  ...sellers.take(4).map(
                        (s) => SellerCard(
                          businessName: s.businessName,
                          description: s.description,
                          rating: s.averageRating,
                          reviewCount: s.reviewCount,
                          city: s.city,
                          imageUrl: s.coverImageUrl,
                          achievementStars: s.achievementStars,
                          goldenCrowns: s.goldenCrowns,
                          onTap: () => context.push('/seller/${s.id}'),
                        ),
                      ),
                  const SizedBox(height: AppSpacing.xxl),
                ]),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: true,
              child: AsyncErrorView.fromError(
                e,
                onRetry: () => ref.invalidate(buyerSellersProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _categoryIcon(String icon) {
    return switch (icon) {
      'beauty' || 'spa' => Icons.spa_outlined,
      'clothing' || 'fashion' => Icons.checkroom_outlined,
      'electronics' => Icons.smartphone_outlined,
      'food' || 'restaurant' => Icons.restaurant_outlined,
      'services' => Icons.handyman_outlined,
      _ => Icons.storefront_outlined,
    };
  }

  static String _distanceLabel(LatLng from, LatLng to) {
    const earthKm = 6371.0;
    final dLat = _rad(to.latitude - from.latitude);
    final dLng = _rad(to.longitude - from.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(from.latitude)) *
            math.cos(_rad(to.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final km = earthKm * c;
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  static double _rad(double deg) => deg * math.pi / 180;

  Future<void> _toggleFavoriteSeller(
    BuildContext context,
    WidgetRef ref,
    SellerModel seller,
  ) async {
    final l10n = context.l10n;
    final session = ref.read(userSessionProvider);
    final storage = ref.read(appStorageProvider);
    final ids = ref.read(buyerFavoriteSellerIdsProvider).valueOrNull ?? {};
    final isFav = ids.contains(seller.id);

    try {
      if (session == null || session.isGuest) {
        if (storage == null) return;
        if (isFav) {
          await storage.removeGuestFavoriteSeller(seller.id);
        } else {
          await storage.addGuestFavoriteItem(
            GuestFavoriteItem(
              productId: '',
              sellerId: seller.id,
              name: seller.businessName,
              price: 0,
              imageUrl: seller.logoImageUrl.isNotEmpty
                  ? seller.logoImageUrl
                  : seller.coverImageUrl,
              sellerName: seller.businessName,
            ),
          );
        }
      } else if (isFav) {
        await apiServiceProvider.removeFavoriteSeller(seller.id);
      } else {
        await apiServiceProvider.addFavoriteSeller(seller.id);
      }
      ref.invalidate(buyerFavoriteSellerIdsProvider);
    } catch (e) {
      if (context.mounted) {
        await showAppErrorDialog(
          context,
          title: l10n.somethingWentWrong,
          message: e.toString(),
        );
      }
    }
  }
}

class _GuestModeBanner extends StatelessWidget {
  const _GuestModeBanner({
    required this.title,
    required this.subtitle,
    required this.loginLabel,
    required this.onLogin,
  });

  final String title;
  final String subtitle;
  final String loginLabel;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surfaceVariant,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadiusLg),
      child: InkWell(
        onTap: onLogin,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadiusLg),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadiusLg),
            boxShadow: AppShadows.soft(context, blur: 16, y: 4),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  color: context.colors.primary,
                  size: 22,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  loginLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Calm, centered profile identity — Apple / Airbnb / Notion inspired.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.subtitle,
    required this.isGuest,
    this.profilePhotoUrl = '',
    this.membershipLabel,
  });

  final String displayName;
  final String subtitle;
  final bool isGuest;
  final String profilePhotoUrl;
  final String? membershipLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initial = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : '?';
    final photoUrl = profilePhotoUrl.trim();

    return Column(
      children: [
        SizedBox(height: AppSpacing.lg),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? context.colors.surface
                    : context.colors.primary.withValues(alpha: 0.08),
                border: Border.all(
                  color: context.colors.border,
                  width: 1,
                ),
                image: photoUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(photoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: photoUrl.isEmpty
                  ? Text(
                      initial,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : context.colors.primary,
                      ),
                    )
                  : null,
            ),
            if (!isGuest)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: context.colors.success,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: AppSpacing.md + 4),
        Text(
          displayName,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                height: 1.15,
              ),
        ),
        if (subtitle.isNotEmpty) ...[
          SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.colors.textSecondary,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
          ),
        ],
        if (membershipLabel != null && membershipLabel!.isNotEmpty) ...[
          SizedBox(height: AppSpacing.sm + 2),
          Text(
            membershipLabel!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.colors.textTertiary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
          ),
        ],
        SizedBox(height: AppSpacing.lg),
        Divider(
          height: 1,
          thickness: 1,
          color: context.colors.border,
        ),
      ],
    );
  }
}

/// Full-screen profile accessed from the home avatar.
class BuyerProfileScreen extends ConsumerWidget {
  const BuyerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(userSessionProvider);
    final authSession = ref.watch(authSessionProvider);
    final isGuest = session == null || session.isGuest;
    final hasSellerProfile = session?.hasSellerProfile ?? false;
    final displayName = (session?.name.trim().isNotEmpty ?? false)
        ? session!.name.trim()
        : l10n.buyerLabel;
    final email = session?.email ?? '';
    final subtitle = isGuest ? l10n.guestMode : email;

    return BuyerScreenScaffold(
      appBar: BuyerAppBar(title: l10n.navProfile),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          children: [
            _ProfileHeader(
              displayName: displayName,
              subtitle: subtitle,
              isGuest: isGuest,
              profilePhotoUrl: authSession?.user.profilePhotoUrl ?? '',
              membershipLabel: isGuest ? null : l10n.margemMember,
            ),
            const SizedBox(height: AppSpacing.lg),
            BuyerMenuTile(
              icon: Icons.favorite_border_rounded,
              title: l10n.favorites,
              onTap: () => context.push('/favorites'),
            ),
            const SizedBox(height: AppSpacing.sm),
            BuyerMenuTile(
              icon: Icons.workspace_premium_outlined,
              title: l10n.premium,
              onTap: () => context.push('/premium'),
            ),
            const SizedBox(height: AppSpacing.sm),
            BuyerMenuTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: l10n.navMessages,
              onTap: () {
                context.pop();
                ref.read(buyerTabIndexProvider.notifier).state = 2;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            BuyerMenuTile(
              icon: Icons.location_city_outlined,
              title: l10n.city,
              subtitle: session?.city ?? '—',
            ),
            const SizedBox(height: AppSpacing.sm),
            const LanguageSettingsTile(),
            if (!isGuest) ...[
              const SizedBox(height: AppSpacing.sm),
              BuyerMenuTile(
                icon: Icons.mark_email_unread_outlined,
                title: l10n.verifyEmailTitle,
                onTap: () => context.push('/verify-email'),
              ),
            ],
            if (!isGuest) ...[
              const SizedBox(height: AppSpacing.sm),
              BuyerMenuTile(
                icon: Icons.lock_outline_rounded,
                title: l10n.changePassword,
                onTap: () => _changePasswordDialog(context),
              ),
              SizedBox(height: AppSpacing.sm),
              BuyerMenuTile(
                icon: Icons.verified_user_outlined,
                title: l10n.mfaSettingsTitle,
                subtitle: ref.watch(authSessionProvider)?.user.mfaEnabled == true
                    ? l10n.mfaEnabled
                    : l10n.enableMfa,
                onTap: () => context.push('/settings/mfa'),
              ),
            ],
            if (!isGuest && hasSellerProfile) ...[
              const SizedBox(height: AppSpacing.sm),
              BuyerMenuTile(
                icon: Icons.storefront_outlined,
                title: l10n.switchToSellerMode,
                subtitle: l10n.switchToSellerModeSub,
                onTap: () async {
                  final storage = ref.read(appStorageProvider);
                  await storage?.saveAppMode(AppMode.seller);
                  if (context.mounted) context.go('/seller/dashboard');
                },
              ),
            ],
            if (!isGuest && !hasSellerProfile) ...[
              SizedBox(height: AppSpacing.sm),
              BuyerMenuTile(
                icon: Icons.add_business_outlined,
                title: l10n.becomeSeller,
                subtitle: l10n.becomeSellerSubtitle,
                onTap: () => context.push('/onboarding/become-seller'),
              ),
            ],
            SizedBox(height: AppSpacing.sm),
            BuyerMenuTile(
              icon: Icons.settings_outlined,
              title: l10n.settingsTitle,
              onTap: () => context.push('/settings'),
            ),
            if (!isGuest) ...[
              SizedBox(height: AppSpacing.sm),
              BuyerMenuTile(
                icon: Icons.policy_outlined,
                title: l10n.privacyAndLegal,
                onTap: () => context.push('/settings/privacy-legal'),
              ),
            ],
            SizedBox(height: AppSpacing.xl),
            if (isGuest) ...[
              FilledButton(
                onPressed: () => context.push('/onboarding/account-type'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  minimumSize: Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(l10n.createAccount),
              ),
              SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => context.push('/login'),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  side: BorderSide(color: context.colors.primary),
                  foregroundColor: context.colors.primary,
                ),
                child: Text(l10n.logIn),
              ),
            ] else
              OutlinedButton(
                onPressed: () async {
                  final prefs =
                      await ref.read(sharedPreferencesProvider.future);
                  await ref.read(authServiceProvider).logout(prefs);
                  await ref.read(appStorageProvider)?.logout();
                  invalidateSubscriptionProviders(ref);
                  ref.read(userSessionProvider.notifier).state = null;
                  ref.read(authSessionProvider.notifier).state = null;
                  if (context.mounted) context.go('/login');
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  side: BorderSide(color: context.colors.error),
                  foregroundColor: context.colors.error,
                ),
                child: Text(l10n.logOut),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePasswordDialog(BuildContext context) async {
    final l10n = context.l10n;
    try {
      final passwords = await showDialog<_PasswordChangeValues>(
        context: context,
        builder: (_) => const _ChangePasswordDialog(),
      );
      if (passwords == null || !context.mounted) return;
      if (passwords.currentPassword.isEmpty ||
          passwords.newPassword.length < 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.completeRequiredStep)),
        );
        return;
      }
      await apiServiceProvider.changePassword(
        currentPassword: passwords.currentPassword,
        newPassword: passwords.newPassword,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.passwordChanged)),
        );
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        await showAppErrorDialog(
          context,
          title: l10n.somethingWentWrong,
          message: error.message,
        );
      }
    }
  }
}

class _PasswordChangeValues {
  const _PasswordChangeValues({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.changePassword),
      content: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _current,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.currentPassword),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _next,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(labelText: l10n.newPassword),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.saveChanges)),
      ],
    );
  }

  void _submit() {
    TextInput.finishAutofillContext();
    Navigator.pop(
      context,
      _PasswordChangeValues(
        currentPassword: _current.text,
        newPassword: _next.text,
      ),
    );
  }
}
