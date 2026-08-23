import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/geo_utils.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/network_image_view.dart';
import '../../l10n/app_localizations.dart';
import '../buyer/buyer_home_screen.dart';

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
    setState(() => _future = _load());
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
    return GeoUtils.formatDistanceKm(distanceKm);
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
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.search,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  city,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      Icons.near_me_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.searchSortedByNearest,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  focusNode: _focusNode,
                  autofocus: widget.autofocusSearch,
                  decoration: InputDecoration(
                    hintText: l10n.businessKeyword,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: _onQueryChanged,
                ),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'sellers',
                      label: Text(l10n.seller),
                      icon: const Icon(Icons.storefront_outlined),
                    ),
                    ButtonSegment(
                      value: 'products',
                      label: Text(l10n.products),
                      icon: const Icon(Icons.inventory_2_outlined),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (values) {
                    setState(() {
                      _mode = values.first;
                      _future = _load();
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<MarketplaceSearchPage>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
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
                  return Center(child: Text(l10n.noBusinessesFound));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
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
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
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
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(subtitle),
                        trailing: Text(
                          product.priceMad == null
                              ? '—'
                              : '${product.priceMad!.toStringAsFixed(0)} MAD',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onTap: () => context.push(
                          '/product/${product.sellerId}/${product.id}',
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
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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
                      title: Text(
                        seller.businessName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(subtitle),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onTap: () => context.push('/seller/${seller.id}'),
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
