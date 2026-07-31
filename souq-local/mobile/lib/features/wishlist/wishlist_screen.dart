import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/content_widgets.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/margem_components.dart';
import '../../l10n/app_localizations.dart';

final favoritesProvider =
    FutureProvider.autoDispose<List<FavoriteItemModel>>((ref) {
  final session = ref.watch(userSessionProvider);
  if (session == null || session.isGuest) {
    final storage = ref.watch(appStorageProvider);
    return Future.value(
      storage
              ?.getGuestFavoriteItems()
              .map(
                (item) => FavoriteItemModel(
                  id: item.productId,
                  productId: item.productId,
                  productName: item.name,
                  imageUrl: item.imageUrl,
                  priceMad: item.price == 0 ? null : item.price,
                  sellerId: item.sellerId,
                  sellerName: item.sellerName,
                ),
              )
              .toList() ??
          const [],
    );
  }
  return apiServiceProvider.fetchFavorites();
});

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  var _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.favorites),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              0,
            ),
            child: MarGemUnderlineTabs(
              tabs: [l10n.products, l10n.seller],
              selectedIndex: _tabIndex,
              onSelected: (i) => setState(() => _tabIndex = i),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: favoritesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => AsyncErrorView.fromError(error,
                  onRetry: () => ref.invalidate(favoritesProvider)),
              data: (items) {
                final filtered = _tabIndex == 0
                    ? items
                        .where((item) => item.productId.isNotEmpty)
                        .toList()
                    : items
                        .where((item) => item.productId.isEmpty)
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(AppSpacing.screenHorizontal),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 56,
                            color: AppColors.primary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            l10n.emptyFavorites,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            l10n.emptyFavoritesSubtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton(
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/buyer/home');
                              }
                            },
                            child: Text(l10n.browseProducts),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(favoritesProvider),
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.productGridGap,
                      crossAxisSpacing: AppSpacing.productGridGap,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _FavoriteGridCard(item: filtered[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteGridCard extends ConsumerWidget {
  const _FavoriteGridCard({required this.item});

  final FavoriteItemModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ProductGridCard(
      name: item.productName,
      priceLabel: item.priceMad == null
          ? l10n.priceOnRequest
          : '${item.priceMad!.toStringAsFixed(0)} MAD',
      imageUrl: item.imageUrl,
      locationLabel:
          item.sellerName.isNotEmpty ? item.sellerName : null,
      isFavorite: true,
      onFavorite: () => _remove(context, ref),
      onTap: () {
        if (item.productId.isNotEmpty) {
          context.push('/product/${item.sellerId}/${item.productId}');
        } else {
          context.push('/seller/${item.sellerId}');
        }
      },
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      final session = ref.read(userSessionProvider);
      if (session == null || session.isGuest) {
        final storage = ref.read(appStorageProvider);
        if (item.productId.isEmpty) {
          await storage?.removeGuestFavoriteSeller(item.sellerId);
        } else {
          await storage?.removeGuestFavoriteItem(item.productId);
        }
      } else if (item.productId.isEmpty) {
        await apiServiceProvider.removeFavoriteSeller(item.sellerId);
      } else {
        await apiServiceProvider.removeFavoriteProduct(item.productId);
      }
      ref.invalidate(favoritesProvider);
    } on ApiException catch (error) {
      if (context.mounted) {
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: error.message);
      }
    }
  }
}
