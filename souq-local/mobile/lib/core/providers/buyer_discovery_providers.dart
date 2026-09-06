import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/app_storage.dart';
import 'city_providers.dart';
import 'provider_cache.dart';

/// Updates marketplace scope and refreshes dependent discovery providers.
Future<void> selectBuyerMarketplace(WidgetRef ref, String? slug) async {
  await ref.read(buyerMarketplaceSlugProvider.notifier).setSlug(slug);
  ref.invalidate(buyerCategoriesProvider);
  ref.invalidate(buyerSellersProvider);
}

String? validatedMarketplaceSlug(
  String? slug,
  List<MarketplaceVenueModel> marketplaces,
) {
  if (slug == null || slug.isEmpty) return null;
  return marketplaces.any((market) => market.slug == slug) ? slug : null;
}

class BuyerMarketplaceSlugNotifier extends StateNotifier<String?> {
  BuyerMarketplaceSlugNotifier(this._ref) : super(null) {
    _syncFromStorage();
    _ref.listen<AsyncValue<SharedPreferences>>(
      sharedPreferencesProvider,
      (_, next) => next.whenData((_) => _syncFromStorage()),
    );
  }

  final Ref _ref;

  void _syncFromStorage() {
    final slug = _ref.read(appStorageProvider)?.getMarketplaceSlug();
    if (slug == null || slug.isEmpty) {
      if (state != null) state = null;
      return;
    }
    if (state != slug) state = slug;
  }

  Future<void> setSlug(String? slug) async {
    final storage = _ref.read(appStorageProvider);
    if (slug == null || slug.isEmpty) {
      state = null;
      await storage?.clearMarketplaceSlug();
      return;
    }
    state = slug;
    await storage?.setMarketplaceSlug(slug);
  }
}

final buyerMarketplaceSlugProvider =
    StateNotifierProvider<BuyerMarketplaceSlugNotifier, String?>((ref) {
  return BuyerMarketplaceSlugNotifier(ref);
});

final buyerMarketplacesProvider =
    FutureProvider.autoDispose<List<MarketplaceVenueModel>>((ref) async {
  retainProviderCache(ref);
  return apiServiceProvider.fetchMarketplaces(city: ref.watch(buyerCityProvider));
});

final buyerSellersProvider =
    FutureProvider.autoDispose<List<SellerModel>>((ref) async {
  retainProviderCache(ref);
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
  retainProviderCache(ref);
  final marketplaces =
      ref.watch(buyerMarketplacesProvider).valueOrNull ?? const [];
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
  retainProviderCache(ref);
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
