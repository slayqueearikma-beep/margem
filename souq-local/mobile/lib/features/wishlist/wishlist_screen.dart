import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/buyer_discovery_providers.dart';
import '../../core/providers/provider_cache.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/network_image_view.dart';
import '../buyer/buyer_home_screen.dart';
import '../../l10n/app_localizations.dart';

final favoritesProvider =
    FutureProvider.autoDispose<List<FavoriteItemModel>>((ref) {
  retainProviderCache(ref);
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

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final favoritesAsync = ref.watch(favoritesProvider);

    return BuyerScreenScaffold(
      appBar: BuyerAppBar(title: l10n.favorites),
      body: favoritesAsync.when(
        skipLoadingOnReload: true,
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colors.primary),
        ),
        error: (error, _) => AsyncErrorView.fromError(error,
            onRetry: () => ref.invalidate(favoritesProvider)),
        data: (items) {
          if (items.isEmpty) {
            return BuyerEmptyState(
              icon: Icons.favorite_border_rounded,
              title: l10n.emptyFavorites,
              subtitle: l10n.emptyFavoritesSubtitle,
              actionLabel: l10n.browseProducts,
              onAction: () {
                ref.read(buyerTabIndexProvider.notifier).state = 1;
                context.go('/buyer/home');
              },
            );
          }
          return RefreshIndicator(
            color: context.colors.primary,
            onRefresh: () async => ref.invalidate(favoritesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  _FavoriteTile(item: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _FavoriteTile extends ConsumerWidget {
  const _FavoriteTile({required this.item});

  final FavoriteItemModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return BuyerSurfaceCard(
      onTap: () {
        if (item.productId.isNotEmpty) {
          context.push('/product/${item.sellerId}/${item.productId}');
        } else {
          context.push('/seller/${item.sellerId}');
        }
      },
      child: ListTile(
        contentPadding: EdgeInsets.all(AppSpacing.sm),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 64,
            height: 64,
            child: NetworkImageView(
              url: item.imageUrl,
              placeholderIcon: Icons.shopping_bag_outlined,
            ),
          ),
        ),
        title: Text(
          item.productName.isNotEmpty ? item.productName : item.sellerName,
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.sellerName.isNotEmpty) Text(item.sellerName),
            Text(
              item.priceMad == null
                  ? l10n.priceOnRequest
                  : '${item.priceMad!.toStringAsFixed(2)} MAD',
              style: TextStyle(
                color: context.colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          tooltip: l10n.remove,
          icon: Icon(Icons.favorite_rounded, color: context.colors.primary),
          onPressed: () => _remove(context, ref),
        ),
      ),
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
      ref.invalidate(buyerFavoriteSellerIdsProvider);
    } on ApiException catch (error) {
      if (context.mounted) {
        await showAppErrorDialog(context,
            title: l10n.somethingWentWrong, message: error.message);
      }
    }
  }
}
