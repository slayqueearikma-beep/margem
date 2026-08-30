import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers/buyer_discovery_providers.dart';
import '../../core/providers/city_providers.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/utils/directional_ui.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../core/widgets/network_image_view.dart';
import '../../core/widgets/seller_trust_indicators.dart';
import '../../l10n/app_localizations.dart';
import '../buyer/buyer_home_screen.dart';
import 'search_category_resolver.dart';
import 'search_filters.dart';
import 'search_mode_cache.dart';
import 'search_navigation_intent.dart';
import 'search_price_input.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.autofocusSearch = false});

  final bool autofocusSearch;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _pageSize = 20;

  final _queryController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _timer;
  final _focusNode = FocusNode();

  var _debounced = '';
  var _searchFocused = false;
  var _mode = 'products';
  var _sort = 'relevance';
  var _suppressCategoryListener = false;
  final _queryByMode = <String, String>{
    'products': '',
    'services': '',
    'providers': '',
  };
  final _filtersByMode = <String, SearchFilters>{
    'products': const SearchFilters(),
    'services': const SearchFilters(),
    'providers': const SearchFilters(),
  };
  var _loading = true;
  var _loadingMore = false;
  Object? _error;

  final _modeCache = SearchModeCache();
  final _products = <SearchProductModel>[];
  final _services = <SearchServiceModel>[];
  final _sellers = <SellerModel>[];
  var _fetchGeneration = 0;
  double? _distanceSortLat;
  double? _distanceSortLng;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onSearchFocusChanged);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _clearInvalidMarketplaceSelection();
      _seedHomeCategoryForCurrentMode();
      _restoreOrFetch(mode: _mode, sort: _sort);
    });
  }

  SearchFilters _filtersFor(String mode) =>
      _filtersByMode[mode] ?? const SearchFilters();

  void _seedHomeCategoryForCurrentMode() {
    final homeCategory = ref.read(buyerCategorySlugProvider);
    if (homeCategory == null || homeCategory.isEmpty) return;
    final current = _filtersFor(_mode);
    if (current.category != null && current.category!.isNotEmpty) return;
    _filtersByMode[_mode] = current.copyWith(
      category: resolveSearchCategorySlug(homeCategory),
    );
  }

  String _queryFor(String mode) => _queryByMode[mode] ?? '';

  String _debouncedFor(String mode) => _queryFor(mode).trim();

  void _applySearchIntent(SearchNavigationIntent intent) {
    final application = applySearchNavigationIntent(
      intent: intent,
      currentMode: _mode,
      filtersByMode: _filtersByMode,
    );
    if (intent.marketplaceSlug != null) {
      ref
          .read(buyerMarketplaceSlugProvider.notifier)
          .setSlug(intent.marketplaceSlug);
    }
    if (_mode != application.mode) {
      _persistModeQuery();
      _persistCurrentSnapshot();
    }
    setState(() {
      for (final entry in application.filtersByMode.entries) {
        _filtersByMode[entry.key] = entry.value;
      }
      _mode = application.mode;
    });
    _restoreModeQuery(application.mode);
    _syncCategoryProvider(application.resolvedCategory);
    _reload();
  }

  void _syncCategoryProvider(String? category) {
    if (ref.read(buyerCategorySlugProvider) == category) return;
    _suppressCategoryListener = true;
    ref.read(buyerCategorySlugProvider.notifier).state = category;
    _suppressCategoryListener = false;
  }

  void _persistModeQuery() {
    _queryByMode[_mode] = _queryController.text;
    _debounced = _debouncedFor(_mode);
  }

  void _restoreModeQuery(String mode) {
    final query = _queryFor(mode);
    if (_queryController.text != query) {
      _queryController.text = query;
    }
    _debounced = _debouncedFor(mode);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _queryController.dispose();
    _scrollController.dispose();
    _focusNode.removeListener(_onSearchFocusChanged);
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_modeCache.hasMoreFor(_currentScopeKey) || _loading || _loadingMore) {
      return;
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  void _onSearchFocusChanged() {
    final focused = _focusNode.hasFocus;
    if (focused != _searchFocused && mounted) {
      setState(() => _searchFocused = focused);
    }
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autofocusSearch && !oldWidget.autofocusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.autofocusSearch) return;
        if (_focusNode.canRequestFocus) {
          _focusNode.requestFocus();
        }
      });
    } else if (!widget.autofocusSearch && oldWidget.autofocusSearch) {
      if (_focusNode.hasFocus) {
        _focusNode.unfocus();
      }
    }
  }

  String? _activeCategoryFor(String mode) {
    final category = _filtersFor(mode).category;
    return category?.isEmpty == true ? null : category;
  }

  String? _activeMarketplace() {
    final slug = ref.read(buyerMarketplaceSlugProvider);
    if (slug == null || slug.isEmpty) return null;
    final marketplaces =
        ref.read(buyerMarketplacesProvider).valueOrNull ?? const [];
    return validatedMarketplaceSlug(slug, marketplaces);
  }

  void _clearInvalidMarketplaceSelection() {
    final slug = ref.read(buyerMarketplaceSlugProvider);
    if (slug == null || slug.isEmpty) return;
    final marketplaces =
        ref.read(buyerMarketplacesProvider).valueOrNull ?? const [];
    if (marketplaces.isEmpty) return;
    if (validatedMarketplaceSlug(slug, marketplaces) != null) return;
    ref.read(buyerMarketplaceSlugProvider.notifier).setSlug(null);
  }

  String _scopeKeyFor(String mode, String sort) {
    final filters = _filtersFor(mode);
    return SearchModeCache.scopeKey(
      mode: mode,
      sort: sort,
      query: _debouncedFor(mode),
      city: ref.read(buyerCityProvider),
      marketplace: _activeMarketplace(),
      category: _resolvedCategoryFor(mode),
      minPrice: filters.minPrice,
      maxPrice: filters.maxPrice,
      minRating: filters.minRating,
      deliveryAvailable: filters.deliveryAvailable,
      pickupOnly: filters.pickupOnly,
      lat: sort == 'distance' ? _distanceSortLat : null,
      lng: sort == 'distance' ? _distanceSortLng : null,
    );
  }

  String get _currentScopeKey => _scopeKeyFor(_mode, _sort);

  String? _resolvedCategoryFor(String mode) =>
      resolveSearchCategorySlug(_activeCategoryFor(mode));

  void _scrollResultsToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<MarketplaceSearchPage> _fetchPage({
    required int offset,
    required String mode,
    required String sort,
  }) async {
    final filters = _filtersFor(mode);
    double? lat;
    double? lng;
    if (sort == 'distance') {
      final origin = await ref.read(buyerSearchLocationProvider.future);
      lat = origin.latitude;
      lng = origin.longitude;
      _distanceSortLat = lat;
      _distanceSortLng = lng;
    }
    return apiServiceProvider.searchMarketplace(
      query: _debouncedFor(mode),
      mode: mode,
      category: _resolvedCategoryFor(mode),
      marketplace: _activeMarketplace(),
      city: ref.read(buyerCityProvider),
      minPrice: filters.minPrice,
      maxPrice: filters.maxPrice,
      minRating: filters.minRating,
      deliveryAvailable:
          mode == 'products' && filters.deliveryAvailable ? true : null,
      pickupOnly: mode == 'products' && filters.pickupOnly ? true : null,
      sort: sort,
      offset: offset,
      limit: _pageSize,
      lat: lat,
      lng: lng,
    );
  }

  void _persistCurrentSnapshot() {
    final scopeKey = _currentScopeKey;
    if (_itemCountForMode(_mode) == 0 && !_modeCache.isLoaded(scopeKey)) {
      return;
    }
    _modeCache.save(
      scopeKey,
      SearchResultsSnapshot.forMode(
        mode: _mode,
        products: _products,
        services: _services,
        sellers: _sellers,
        offset: _modeCache.offsetFor(scopeKey),
        hasMore: _modeCache.hasMoreFor(scopeKey),
      ),
    );
  }

  void _restoreSnapshot(String scopeKey, String mode) {
    final snapshot = _modeCache.snapshot(scopeKey);
    if (snapshot == null) return;
    switch (mode) {
      case 'services':
        _services
          ..clear()
          ..addAll(snapshot.services);
      case 'providers':
        _sellers
          ..clear()
          ..addAll(snapshot.sellers);
      default:
        _products
          ..clear()
          ..addAll(snapshot.products);
    }
  }

  int _itemCountForMode(String mode) => switch (mode) {
        'services' => _services.length,
        'providers' => _sellers.length,
        _ => _products.length,
      };

  int _pageItemCount(MarketplaceSearchPage page, String mode) => switch (mode) {
        'services' => page.services.length,
        'providers' => page.sellers.length,
        _ => page.products.length,
      };

  void _applyPage({
    required String scopeKey,
    required String mode,
    required MarketplaceSearchPage page,
    required bool append,
  }) {
    switch (mode) {
      case 'services':
        if (!append) _services.clear();
        _services.addAll(page.services);
      case 'providers':
        if (!append) _sellers.clear();
        _sellers.addAll(page.sellers);
      default:
        if (!append) _products.clear();
        _products.addAll(page.products);
    }

    final itemCount = _pageItemCount(page, mode);
    final offset = (append ? _modeCache.offsetFor(scopeKey) : 0) + itemCount;
    _modeCache.save(
      scopeKey,
      SearchResultsSnapshot.forMode(
        mode: mode,
        products: _products,
        services: _services,
        sellers: _sellers,
        offset: offset,
        hasMore: page.hasMore,
      ),
    );
  }

  Future<void> _fetchMode(
    String mode, {
    required String sort,
    required String scopeKey,
    required int offset,
    required bool append,
    required int generation,
    bool showLoading = true,
  }) async {
    if (showLoading && !append) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _error = null;
      });
    } else if (append) {
      setState(() => _loadingMore = true);
    } else if (!append && mode == _mode && sort == _sort) {
      setState(() {
        _error = null;
        _loading = true;
        _loadingMore = false;
      });
    }

    try {
      final page = await _fetchPage(offset: offset, mode: mode, sort: sort);
      if (!mounted || generation != _fetchGeneration) return;
      if (scopeKey != _scopeKeyFor(mode, sort)) return;
      setState(() {
        _applyPage(
          scopeKey: scopeKey,
          mode: mode,
          page: page,
          append: append,
        );
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _fetchGeneration) return;
      if (scopeKey != _scopeKeyFor(mode, sort)) return;
      setState(() {
        if (mode == _mode && sort == _sort) {
          _error = error;
        }
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _beginFetch({required bool showLoading}) {
    final generation = ++_fetchGeneration;
    _modeCache.invalidateMode(_mode);
    final scopeKey = _scopeKeyFor(_mode, _sort);
    _fetchMode(
      _mode,
      sort: _sort,
      scopeKey: scopeKey,
      offset: 0,
      append: false,
      generation: generation,
      showLoading: showLoading,
    );
  }

  Future<void> _reload() async {
    final generation = ++_fetchGeneration;
    _timer?.cancel();
    _persistModeQuery();
    _scrollResultsToTop();
    setState(() {
      _modeCache.invalidateMode(_mode);
      _error = null;
      _loading = true;
      _loadingMore = false;
    });
    await _fetchMode(
      _mode,
      sort: _sort,
      scopeKey: _scopeKeyFor(_mode, _sort),
      offset: 0,
      append: false,
      generation: generation,
      showLoading: false,
    );
  }

  void _restoreOrFetch({required String mode, required String sort}) {
    final scopeKey = _scopeKeyFor(mode, sort);
    if (sort != 'distance' && _modeCache.isLoaded(scopeKey)) {
      _restoreSnapshot(scopeKey, mode);
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
      _scrollResultsToTop();
      return;
    }
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    _beginFetch(showLoading: false);
  }

  void _switchMode(String value) {
    if (_mode == value) return;
    _timer?.cancel();
    _persistModeQuery();
    _persistCurrentSnapshot();
    setState(() => _mode = value);
    _restoreModeQuery(value);
    _syncCategoryProvider(_activeCategoryFor(value));
    _restoreOrFetch(mode: value, sort: _sort);
  }

  void _setSort(String value) {
    if (_sort == value) return;
    _persistCurrentSnapshot();
    setState(() => _sort = value);
    _scrollResultsToTop();
    _restoreOrFetch(mode: _mode, sort: value);
  }

  Future<void> _loadMore() async {
    final scopeKey = _currentScopeKey;
    if (_loadingMore || !_modeCache.hasMoreFor(scopeKey) || _loading) {
      return;
    }
    setState(() => _loadingMore = true);
    await _fetchMode(
      _mode,
      sort: _sort,
      scopeKey: scopeKey,
      offset: _modeCache.offsetFor(scopeKey),
      append: true,
      generation: _fetchGeneration,
      showLoading: false,
    );
  }

  void _onQueryChanged(String value) {
    _timer?.cancel();
    final mode = _mode;
    _queryByMode[mode] = value;
    _timer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || _mode != mode) return;
      _debounced = value.trim();
      _reload();
    });
  }

  String _priceLabel(AppStrings l10n, {required bool isOffer, double? priceMad}) {
    if (isOffer) return l10n.pricingOffer;
    if (priceMad == null) return '—';
    return '${priceMad.toStringAsFixed(0)} MAD';
  }

  Future<void> _saveCurrentSearch(AppStrings l10n) async {
    final session = ref.read(userSessionProvider);
    if (session == null || session.isGuest) {
      if (!mounted) return;
      context.push('/login');
      return;
    }

    try {
      await apiServiceProvider.createSavedSearch(
        query: _debounced,
        city: ref.read(buyerCityProvider),
        category: _activeCategoryFor(_mode) ?? '',
        marketplaceSlug: _activeMarketplace() ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saveCurrentSearch)),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _openSavedSearches(AppStrings l10n) async {
    final session = ref.read(userSessionProvider);
    if (session == null || session.isGuest) {
      if (!mounted) return;
      context.push('/login');
      return;
    }

    List<SavedSearchModel> saved = const [];
    try {
      saved = await apiServiceProvider.fetchSavedSearches();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.md,
              AppSpacing.screenHorizontal,
              MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.savedSearchesTitle,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.md),
                if (saved.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Text(l10n.noBusinessesFound),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: saved.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = saved[index];
                        final label = [
                          if (item.query.isNotEmpty) item.query,
                          if (item.category.isNotEmpty) item.category,
                          if (item.marketplaceSlug.isNotEmpty) item.marketplaceSlug,
                        ].join(' · ');
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(label.isEmpty ? l10n.allCategories : label),
                          subtitle: item.city.isNotEmpty ? Text(item.city) : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              try {
                                await apiServiceProvider.deleteSavedSearch(item.id);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(l10n.savedSearchDeleted)),
                                  );
                                  _openSavedSearches(l10n);
                                }
                              } on ApiException catch (error) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.message)),
                                );
                              }
                            },
                          ),
                          onTap: () {
                            _queryController.text = item.query;
                            _debounced = item.query.trim();
                            _queryByMode[_mode] = item.query;
                            _queryController.text = item.query;
                            final category = item.category.isEmpty
                                ? null
                                : resolveSearchCategorySlug(item.category);
                            _filtersByMode[_mode] = SearchFilters(category: category);
                            _syncCategoryProvider(category);
                            ref
                                .read(buyerMarketplaceSlugProvider.notifier)
                                .setSlug(
                                  item.marketplaceSlug.isEmpty
                                      ? null
                                      : item.marketplaceSlug,
                                );
                            Navigator.pop(context);
                            _reload();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.savedSearchApplied)),
                            );
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _saveCurrentSearch(l10n);
                    },
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(l10n.saveCurrentSearch),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openFilters(AppStrings l10n) async {
    final categories = await ref.read(buyerCategoriesProvider.future);
    if (!mounted) return;

    final result = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SearchFiltersSheet(
        l10n: l10n,
        categories: categories,
        initialFilters: _filtersFor(_mode),
        showDeliveryFilters: _mode == 'products',
      ),
    );

    if (!mounted || result == null) return;
    _applyFilters(result);
  }

  void _applyFilters(SearchFilters result) {
    final normalized = SearchFilters(
      category: resolveSearchCategorySlug(result.category),
      minPrice: result.minPrice,
      maxPrice: result.maxPrice,
      minRating: result.minRating,
      deliveryAvailable: result.deliveryAvailable,
      pickupOnly: result.pickupOnly,
    );
    setState(() => _filtersByMode[_mode] = normalized);
    _syncCategoryProvider(normalized.category);
    _reload();
  }

  int get _itemCount => switch (_mode) {
        'services' => _services.length,
        'providers' => _sellers.length,
        _ => _products.length,
      };

  Widget _buildResults(AppStrings l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return AsyncErrorView.fromError(
        _error!,
        onRetry: _reload,
      );
    }
    if (_itemCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.noBusinessesFound,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.searchEmptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
      itemCount: _itemCount + (_modeCache.hasMoreFor(_currentScopeKey) ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, index) {
        if (index >= _itemCount) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: _loadingMore
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      onPressed: _loadMore,
                      child: Text(l10n.loadMoreResults),
                    ),
            ),
          );
        }

        if (_mode == 'services') {
          final service = _services[index];
          return ListTile(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            tileColor: Theme.of(context).cardTheme.color,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: 52,
                child: NetworkImageView(
                  url: service.imageUrl,
                  placeholderIcon: Icons.handyman_outlined,
                ),
              ),
            ),
            title: Text(service.name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${service.sellerName} · ${service.sellerCity}'),
            trailing: Text(
              _priceLabel(
                l10n,
                isOffer: service.isOffer,
                priceMad: service.priceMad,
              ),
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w800),
            ),
            onTap: () => context.push('/seller/${service.sellerId}'),
          );
        }

        if (_mode == 'providers') {
          final seller = _sellers[index];
          return ListTile(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            tileColor: Theme.of(context).cardTheme.color,
            leading: ClipOval(
              child: SizedBox(
                width: 44,
                height: 44,
                child: NetworkImageView(
                  url: seller.coverImageUrl,
                  placeholderIcon: Icons.storefront_rounded,
                ),
              ),
            ),
            title: Text(seller.businessName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${seller.city} · ${seller.averageRating} ★'),
                const SizedBox(height: 4),
                SellerTrustIndicators(seller: seller, compact: true),
              ],
            ),
            trailing: Icon(
              DirectionalUi.forwardChevron(context),
              color: AppColors.textSecondary,
            ),
            onTap: () => context.push('/seller/${seller.id}'),
          );
        }

        final product = _products[index];
        return ListTile(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          tileColor: Theme.of(context).cardTheme.color,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: NetworkImageView(
                url: product.imageUrl,
                placeholderIcon: Icons.inventory_2_outlined,
              ),
            ),
          ),
          title: Text(product.name,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${product.sellerName} · ${product.sellerCity}'),
          trailing: Text(
            _priceLabel(
              l10n,
              isOffer: product.isOffer,
              priceMad: product.priceMad,
            ),
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w800),
          ),
          onTap: () =>
              context.push('/product/${product.sellerId}/${product.id}'),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen(buyerSearchIntentProvider, (previous, next) {
      if (next == null) return;
      _applySearchIntent(next);
      ref.read(buyerSearchIntentProvider.notifier).state = null;
    });
    ref.listen(buyerCategorySlugProvider, (previous, next) {
      if (_suppressCategoryListener || previous == next) return;
      final resolved = resolveSearchCategorySlug(next);
      final current = _filtersFor(_mode);
      if (current.category == resolved) return;
      setState(() {
        _filtersByMode[_mode] = current.copyWith(
          category: resolved,
          clearCategory: resolved == null,
        );
      });
      _reload();
    });
    ref.listen(buyerMarketplaceSlugProvider, (previous, next) {
      if (previous != next) _reload();
    });
    ref.listen(buyerMarketplacesProvider, (previous, next) {
      final slug = ref.read(buyerMarketplaceSlugProvider);
      if (slug == null || slug.isEmpty) return;
      final marketplaces = next.valueOrNull ?? const [];
      if (marketplaces.isEmpty) return;

      final validated = validatedMarketplaceSlug(slug, marketplaces);
      if (validated == null) {
        _clearInvalidMarketplaceSelection();
        _reload();
        return;
      }

      final wasValidated = previous?.valueOrNull != null &&
          validatedMarketplaceSlug(slug, previous!.valueOrNull ?? const []) !=
              null;
      if (!wasValidated) _reload();
    });
    ref.listen(buyerCityProvider, (previous, next) {
      if (previous != next) _reload();
    });

    final filters = _filtersFor(_mode);
    final hasActiveFilters = filters.category != null ||
        filters.minPrice != null ||
        filters.maxPrice != null ||
        filters.minRating != null ||
        filters.deliveryAvailable ||
        filters.pickupOnly;

    final location = GoRouter.maybeOf(context)?.state.uri.path ?? '';
    final isBuyerHomeSearchTab = location == '/buyer/home';

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BuyerAdaptiveHeader(
            showBack: isBuyerHomeSearchTab,
            onBack: isBuyerHomeSearchTab
                ? () => ref.read(buyerTabIndexProvider.notifier).state = 0
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.sm),
                ExcludeFocus(
                  excluding: !widget.autofocusSearch,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.inputRadius),
                      boxShadow: _searchFocused
                          ? AppShadows.warm(
                              context,
                              blur: 8,
                              y: 1,
                              alpha: 0.03,
                            )
                          : null,
                    ),
                    child: TextField(
                      controller: _queryController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: l10n.businessKeyword,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l10n.savedSearchesTitle,
                              onPressed: () => _openSavedSearches(l10n),
                              icon: const Icon(Icons.bookmarks_outlined),
                            ),
                            IconButton(
                              tooltip: l10n.searchFilters,
                              onPressed: () => _openFilters(l10n),
                              icon: Badge(
                                isLabelVisible: hasActiveFilters,
                                child: const Icon(Icons.tune_rounded),
                              ),
                            ),
                          ],
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.inputRadius),
                          borderSide: BorderSide(color: context.colors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.inputRadius),
                          borderSide: const BorderSide(
                            color: Color(0xFFD8CBB8),
                            width: 1.25,
                          ),
                        ),
                      ),
                      onChanged: _onQueryChanged,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SearchModeSelector(
                  mode: _mode,
                  onChanged: _switchMode,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'relevance',
                            label: Text(l10n.searchSortRelevance),
                          ),
                          ButtonSegment(
                            value: 'distance',
                            label: Text(l10n.searchSortNearest),
                          ),
                        ],
                        selected: {_sort},
                        onSelectionChanged: (values) =>
                            _setSort(values.first),
                      ),
                    ),
                  ],
                ),
                if (_sort == 'distance')
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      l10n.searchSortedByNearest,
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildResults(l10n)),
        ],
      ),
    );
  }
}

class _SearchModeSelector extends StatelessWidget {
  const _SearchModeSelector({
    required this.mode,
    required this.onChanged,
  });

  final String mode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = <({String value, String label, IconData icon})>[
      (value: 'products', label: l10n.products, icon: Icons.inventory_2_outlined),
      (value: 'services', label: l10n.services, icon: Icons.handyman_outlined),
      (value: 'providers', label: l10n.provider, icon: Icons.storefront_outlined),
    ];

    return Row(
      children: [
        for (final item in items) ...[
          Expanded(
            child: Builder(
              builder: (context) {
                final active = mode == item.value;
                final colors = context.colors;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: active ? colors.surface : colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active
                          ? colors.primary.withValues(alpha: 0.28)
                          : colors.border.withValues(alpha: 0.7),
                    ),
                    boxShadow: active
                        ? AppShadows.warm(context, blur: 6, y: 1, alpha: 0.022)
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onChanged(item.value),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.icon,
                              size: 18,
                              color: active
                                  ? colors.primary
                                  : colors.textTertiary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? colors.primary
                                    : colors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (item != items.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _SearchFiltersSheet extends StatefulWidget {
  const _SearchFiltersSheet({
    required this.l10n,
    required this.categories,
    required this.initialFilters,
    required this.showDeliveryFilters,
  });

  final AppStrings l10n;
  final List<CategoryModel> categories;
  final SearchFilters initialFilters;
  final bool showDeliveryFilters;

  @override
  State<_SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends State<_SearchFiltersSheet> {
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;
  late final TextEditingController _minRatingController;
  String? _category;
  late bool _deliveryAvailable;
  late bool _pickupOnly;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFilters;
    _minPriceController = TextEditingController(
      text: formatSearchPriceInput(initial.minPrice),
    );
    _maxPriceController = TextEditingController(
      text: formatSearchPriceInput(initial.maxPrice),
    );
    _minRatingController = TextEditingController(
      text: initial.minRating?.toStringAsFixed(1) ?? '',
    );
    _category = initial.category;
    _deliveryAvailable = initial.deliveryAvailable;
    _pickupOnly = initial.pickupOnly;
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _minRatingController.dispose();
    super.dispose();
  }

  SearchFilters _filtersFromInputs() {
    return SearchFilters(
      category: _category,
      minPrice: parseSearchPriceInput(_minPriceController.text),
      maxPrice: parseSearchPriceInput(_maxPriceController.text),
      minRating: double.tryParse(_minRatingController.text.trim()),
      deliveryAvailable: _deliveryAvailable,
      pickupOnly: _pickupOnly,
    );
  }

  void _applyPriceFilters() {
    final filters = _filtersFromInputs();
    if (!isSearchPriceRangeValid(filters.minPrice, filters.maxPrice)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.minPriceExceedsMax)),
      );
      return;
    }
    Navigator.pop(context, filters);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.md,
        AppSpacing.screenHorizontal,
        MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.searchFilters,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              value: _category,
              decoration: InputDecoration(labelText: l10n.productCategory),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l10n.allCategories),
                ),
                ...widget.categories.map(
                  (cat) => DropdownMenuItem(
                    value: cat.slug,
                    child: Text(cat.localizedName(
                      Localizations.localeOf(context).languageCode,
                    )),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _minPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.minPrice),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _maxPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.maxPrice),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _minRatingController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.minRating),
            ),
            if (widget.showDeliveryFilters) ...[
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.deliveryAvailable),
                value: _deliveryAvailable,
                onChanged: (value) => setState(() {
                  _deliveryAvailable = value;
                  if (value) _pickupOnly = false;
                }),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.pickupOnly),
                value: _pickupOnly,
                onChanged: (value) => setState(() {
                  _pickupOnly = value;
                  if (value) _deliveryAvailable = false;
                }),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, const SearchFilters()),
                    child: Text(l10n.clearFilters),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _applyPriceFilters,
                    child: Text(l10n.applyFilters),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
