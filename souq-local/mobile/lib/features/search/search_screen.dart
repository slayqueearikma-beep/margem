import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/directional_ui.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../core/widgets/network_image_view.dart';
import '../../l10n/app_localizations.dart';
import '../../core/providers/city_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.autofocusSearch = false});

  final bool autofocusSearch;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _debounced = '';
  Timer? _timer;
  Future<MarketplaceSearchPage>? _future;
  final _focusNode = FocusNode();
  final _searchController = TextEditingController();
  var _mode = 'sellers';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autofocusSearch && !oldWidget.autofocusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    } else if (!widget.autofocusSearch && oldWidget.autofocusSearch) {
      _focusNode.unfocus();
    }
  }

  Future<MarketplaceSearchPage> _load() async {
    final city = ref.read(buyerCityProvider);
    final origin = await ref.read(buyerSearchLocationProvider.future);
    return apiServiceProvider.searchMarketplace(
      query: _debounced,
      mode: _mode,
      city: city,
      lat: origin.latitude,
      lng: origin.longitude,
      sort: 'distance',
    );
  }

  void _refreshResults() {
    setState(() {
      _future = _load();
    });
  }

  void _onQueryChanged(String value) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), () {
      setState(() {
        _debounced = value.trim();
        _future = _load();
      });
    });
  }

  String _distanceLabel(double? distanceKm) {
    if (distanceKm == null) return '';
    return context.l10n.distanceLabel(distanceKm);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final city = ref.watch(buyerCityProvider);
    ref.listen(buyerCityProvider, (previous, next) {
      if (previous != next) _refreshResults();
    });

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BuyerScreenTitle(
            title: l10n.search,
            subtitle: city,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.near_me_outlined,
                  size: 14,
                  color: AppColors.lavender,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.searchSortedByNearest,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant(context),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: BuyerSearchBar(
              hint: l10n.businessKeyword,
              controller: _searchController,
              focusNode: _focusNode,
              autofocus: widget.autofocusSearch,
              onChanged: _onQueryChanged,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: BuyerSegmentedToggle<String>(
              selected: _mode,
              onChanged: (value) {
                setState(() {
                  _mode = value;
                  _future = _load();
                });
              },
              segments: [
                BuyerSegment(
                  value: 'sellers',
                  label: l10n.seller,
                  icon: Icons.storefront_outlined,
                ),
                BuyerSegment(
                  value: 'products',
                  label: l10n.products,
                  icon: Icons.inventory_2_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: FutureBuilder<MarketplaceSearchPage>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.lavender),
                  );
                }
                if (snapshot.hasError) {
                  return AsyncErrorView.fromError(
                    snapshot.error!,
                    onRetry: _refreshResults,
                  );
                }
                final page = snapshot.data;
                final isProducts = _mode == 'products';
                final count = isProducts
                    ? (page?.products.length ?? 0)
                    : (page?.sellers.length ?? 0);
                if (count == 0) {
                  return BuyerEmptyState(
                    icon: Icons.search_off_rounded,
                    title: l10n.noBusinessesFound,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    0,
                    AppSpacing.screenHorizontal,
                    AppSpacing.xl,
                  ),
                  itemCount: count,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, index) {
                    if (isProducts) {
                      final product = page!.products[index];
                      final distance = _distanceLabel(product.distanceKm);
                      final subtitle = [
                        product.sellerName,
                        product.sellerCity,
                        if (distance.isNotEmpty) distance,
                      ].join(' · ');
                      return BuyerSurfaceCard(
                        onTap: () => context.push(
                          '/product/${product.sellerId}/${product.id}',
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 4,
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 52,
                              height: 52,
                              child: NetworkImageView(
                                url: product.imageUrl,
                                placeholderIcon: Icons.inventory_2_outlined,
                              ),
                            ),
                          ),
                          title: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(subtitle),
                          trailing: Text(
                            product.priceMad == null
                                ? '—'
                                : '${product.priceMad!.toStringAsFixed(0)} MAD',
                            style: const TextStyle(
                              color: AppColors.lavender,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    }
                    final seller = page!.sellers[index];
                    final distance = _distanceLabel(seller.distanceKm);
                    final subtitle = [
                      seller.city,
                      '${seller.averageRating} ★',
                      if (distance.isNotEmpty) distance,
                    ].join(' · ');
                    return BuyerSurfaceCard(
                      onTap: () => context.push('/seller/${seller.id}'),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 4,
                        ),
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
                        title: Text(
                          seller.businessName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(subtitle),
                        trailing: Icon(
                          DirectionalUi.forwardChevron(context),
                          color: AppColors.textTertiary,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
