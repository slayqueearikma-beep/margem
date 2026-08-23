import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/category_theme.dart';
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
  final _focusNode = FocusNode();
  var _mode = 'products';
  var _offset = 0;
  String? _categorySlug;
  static const _pageSize = 20;
  MarketplaceSearchPage? _page;
  var _loading = true;
  var _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(reset: true);
    });
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

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _offset = 0;
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final city = ref.read(buyerCityProvider);
      final result = await apiServiceProvider.searchMarketplace(
        query: _debounced,
        mode: _mode,
        city: city,
        category: _categorySlug,
        offset: reset ? 0 : _offset,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (reset || _page == null) {
          _page = result;
        } else {
          _page = MarketplaceSearchPage(
            sellers: [..._page!.sellers, ...result.sellers],
            products: [..._page!.products, ...result.products],
            totalSellers: result.totalSellers,
            totalProducts: result.totalProducts,
            limit: result.limit,
            offset: result.offset,
            hasMore: result.hasMore,
          );
        }
        _offset = _mode == 'products' ? _page!.products.length : _page!.sellers.length;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e;
      });
    }
  }

  void _onQueryChanged(String value) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), () {
      setState(() => _debounced = value.trim());
      _load(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final city = ref.watch(buyerCityProvider);
    final categoriesAsync = ref.watch(buyerCategoriesProvider);
    ref.listen(buyerCityProvider, (previous, next) {
      if (previous != next) {
        _load(reset: true);
      }
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
                Text(l10n.search,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  city,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
                      value: 'products',
                      label: Text(l10n.products),
                      icon: const Icon(Icons.inventory_2_outlined),
                    ),
                    ButtonSegment(
                      value: 'sellers',
                      label: Text(l10n.seller),
                      icon: const Icon(Icons.storefront_outlined),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (values) {
                    setState(() => _mode = values.first);
                    _load(reset: true);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                categoriesAsync.when(
                  data: (categories) => SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length + 1,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (_, index) {
                        final isAll = index == 0;
                        final category =
                            isAll ? null : categories[index - 1];
                        final selected = isAll
                            ? _categorySlug == null
                            : _categorySlug == category?.slug;
                        final label = isAll
                            ? l10n.allCategories
                            : category!.localizedName(
                                Localizations.localeOf(context).languageCode,
                              );
                        final accent = isAll
                            ? AppColors.primary
                            : CategoryTheme.accentColor(
                                category!.accentColor,
                                slug: category.slug,
                              );
                        return FilterChip(
                          label: Text(label),
                          selected: selected,
                          avatar: Icon(
                            isAll
                                ? Icons.apps_rounded
                                : CategoryTheme.iconFor(category!.icon),
                            size: 16,
                            color: selected ? Colors.white : accent,
                          ),
                          selectedColor: accent,
                          checkmarkColor: Colors.white,
                          onSelected: (_) {
                            setState(() {
                              _categorySlug = isAll ? null : category!.slug;
                            });
                            _load(reset: true);
                          },
                        );
                      },
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (_loading && _page == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_error != null && _page == null) {
                  return AsyncErrorView.fromError(
                    _error!,
                    onRetry: () => _load(reset: true),
                  );
                }
                final page = _page;
                final isProducts = _mode == 'products';
                final items = isProducts ? page?.products ?? [] : page?.sellers ?? [];
                final total = isProducts ? page?.totalProducts ?? 0 : page?.totalSellers ?? 0;
                if (items.isEmpty) {
                  return Center(child: Text(l10n.noBusinessesFound));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal),
                  itemCount: items.length + (_page?.hasMore == true ? 1 : 0),
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, index) {
                    if (index == items.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Center(
                          child: _loadingMore
                              ? const CircularProgressIndicator()
                              : OutlinedButton(
                                  onPressed: () => _load(reset: false),
                                  child: Text('Load more ($total total)'),
                                ),
                        ),
                      );
                    }
                    if (isProducts) {
                      final product = page!.products[index];
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
                              memCacheWidth: 104,
                              memCacheHeight: 104,
                            ),
                          ),
                        ),
                        title: Text(product.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${product.sellerName} · ${product.sellerCity}'),
                        trailing: Text(
                          product.priceMad == null
                              ? '—'
                              : '${product.priceMad!.toStringAsFixed(0)} MAD',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800),
                        ),
                        onTap: () => context
                            .push('/product/${product.sellerId}/${product.id}'),
                      );
                    }
                    final seller = page!.sellers[index];
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
                            memCacheWidth: 88,
                            memCacheHeight: 88,
                          ),
                        ),
                      ),
                      title: Text(seller.businessName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle:
                          Text('${seller.city} · ${seller.averageRating} ★'),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondary),
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
