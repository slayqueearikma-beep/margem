import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/content_widgets.dart';
import '../../core/widgets/margem_components.dart';
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
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  var _mode = 'products';

  static const _popularSearches = [
    'iPhone',
    'PlayStation',
    'MacBook',
    'Fashion',
    'Electronics',
  ];

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
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

  Future<MarketplaceSearchPage> _load() {
    final city = ref.read(buyerCityProvider);
    return apiServiceProvider.searchMarketplace(
      query: _debounced,
      mode: _mode,
      city: city,
    );
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

  void _applyChipSearch(String term) {
    _searchController.text = term;
    setState(() {
      _debounced = term;
      _future = _load();
    });
  }

  int get _modeIndex => _mode == 'products' ? 0 : 1;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen(buyerCityProvider, (previous, next) {
      if (previous != next) {
        setState(() => _future = _load());
      }
    });
    _future ??= _load();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.md,
              AppSpacing.screenHorizontal,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarGemSearchBar(
                  hint: l10n.businessKeyword,
                  controller: _searchController,
                  focusNode: _focusNode,
                  autofocus: widget.autofocusSearch,
                  onChanged: _onQueryChanged,
                  trailing: IconButton(
                    icon: const Icon(Icons.tune_rounded, size: 22),
                    color: AppColors.textTertiary,
                    onPressed: () {},
                  ),
                ),
                if (_debounced.isEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Popular searches',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _popularSearches
                        .map(
                          (term) => MarGemFilterChip(
                            label: term,
                            selected: false,
                            onTap: () => _applyChipSearch(term),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                MarGemUnderlineTabs(
                  tabs: [l10n.products, l10n.seller],
                  selectedIndex: _modeIndex,
                  onSelected: (index) {
                    setState(() {
                      _mode = index == 0 ? 'products' : 'sellers';
                      _future = _load();
                    });
                  },
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
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return AsyncErrorView.fromError(
                    snapshot.error!,
                    onRetry: () {
                      setState(() {
                        _future = _load();
                      });
                    },
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

                if (isProducts) {
                  return GridView.builder(
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
                    itemCount: count,
                    itemBuilder: (_, index) {
                      final product = page!.products[index];
                      return ProductGridCard(
                        name: product.name,
                        priceLabel: product.priceMad == null
                            ? '—'
                            : '${product.priceMad!.toStringAsFixed(0)} MAD',
                        imageUrl: product.imageUrl,
                        locationLabel: product.sellerCity,
                        onTap: () => context.push(
                          '/product/${product.sellerId}/${product.id}',
                        ),
                      );
                    },
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                  ),
                  itemCount: count,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, index) {
                    final seller = page!.sellers[index];
                    return SellerCard(
                      businessName: seller.businessName,
                      description: '',
                      rating: seller.averageRating,
                      reviewCount: seller.reviewCount,
                      city: seller.city,
                      imageUrl: seller.coverImageUrl,
                      compact: true,
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
