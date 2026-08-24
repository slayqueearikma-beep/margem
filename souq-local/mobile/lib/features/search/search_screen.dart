import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/utils/directional_ui.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../core/widgets/network_image_view.dart';
import '../../l10n/app_localizations.dart';
import '../buyer/buyer_home_screen.dart';

class SearchFilters {
  const SearchFilters({
    this.category,
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.deliveryAvailable = false,
    this.pickupOnly = false,
  });

  final String? category;
  final double? minPrice;
  final double? maxPrice;
  final double? minRating;
  final bool deliveryAvailable;
  final bool pickupOnly;

  SearchFilters copyWith({
    String? category,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    bool? deliveryAvailable,
    bool? pickupOnly,
    bool clearCategory = false,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
    bool clearMinRating = false,
  }) {
    return SearchFilters(
      category: clearCategory ? null : (category ?? this.category),
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      deliveryAvailable: deliveryAvailable ?? this.deliveryAvailable,
      pickupOnly: pickupOnly ?? this.pickupOnly,
    );
  }
}

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
  var _searchFocused = false;
  var _mode = 'products';
  SearchFilters _filters = const SearchFilters();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onSearchFocusChanged);
  }

  void _onSearchFocusChanged() {
    final focused = _focusNode.hasFocus;
    if (focused != _searchFocused && mounted) {
      setState(() => _searchFocused = focused);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onSearchFocusChanged);
    _timer?.cancel();
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
    _focusNode.dispose();
    super.dispose();
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

  Future<MarketplaceSearchPage> _load() {
    final homeCategory = ref.read(buyerCategorySlugProvider);
    final category = _filters.category ?? homeCategory;
    final marketplace = ref.read(buyerMarketplaceSlugProvider);
    return apiServiceProvider.searchMarketplace(
      query: _debounced,
      mode: _mode,
      category: category?.isEmpty == true ? null : category,
      marketplace: marketplace,
      minPrice: _filters.minPrice,
      maxPrice: _filters.maxPrice,
      minRating: _filters.minRating,
      deliveryAvailable: _filters.deliveryAvailable ? true : null,
      pickupOnly: _filters.pickupOnly ? true : null,
    );
  }

  void _refresh() => setState(() => _future = _load());

  void _onQueryChanged(String value) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _debounced = value.trim();
        _future = _load();
      });
    });
  }

  String _priceLabel(AppStrings l10n, {required bool isOffer, double? priceMad}) {
    if (isOffer) return l10n.pricingOffer;
    if (priceMad == null) return '—';
    return '${priceMad.toStringAsFixed(0)} MAD';
  }

  Future<void> _openFilters(AppStrings l10n) async {
    final categories = await ref.read(buyerCategoriesProvider.future);
    if (!mounted) return;

    final minPriceController = TextEditingController(
      text: _filters.minPrice?.toStringAsFixed(0) ?? '',
    );
    final maxPriceController = TextEditingController(
      text: _filters.maxPrice?.toStringAsFixed(0) ?? '',
    );
    final minRatingController = TextEditingController(
      text: _filters.minRating?.toStringAsFixed(1) ?? '',
    );
    var category = _filters.category;
    var deliveryAvailable = _filters.deliveryAvailable;
    var pickupOnly = _filters.pickupOnly;

    final result = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                      value: category,
                      decoration: InputDecoration(labelText: l10n.productCategory),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l10n.allCategories),
                        ),
                        ...categories.map(
                          (cat) => DropdownMenuItem(
                            value: cat.slug,
                            child: Text(cat.localizedName(
                              Localizations.localeOf(context).languageCode,
                            )),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setModalState(() => category = value),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: minPriceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: l10n.minPrice),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: maxPriceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: l10n.maxPrice),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: minRatingController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: l10n.minRating),
                    ),
                    if (_mode == 'products') ...[
                      const SizedBox(height: AppSpacing.sm),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.deliveryAvailable),
                        value: deliveryAvailable,
                        onChanged: (value) => setModalState(() {
                          deliveryAvailable = value;
                          if (value) pickupOnly = false;
                        }),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.pickupOnly),
                        value: pickupOnly,
                        onChanged: (value) => setModalState(() {
                          pickupOnly = value;
                          if (value) deliveryAvailable = false;
                        }),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(
                                context,
                                const SearchFilters(),
                              );
                            },
                            child: Text(l10n.clearFilters),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.pop(
                                context,
                                SearchFilters(
                                  category: category,
                                  minPrice: double.tryParse(
                                      minPriceController.text.trim()),
                                  maxPrice: double.tryParse(
                                      maxPriceController.text.trim()),
                                  minRating: double.tryParse(
                                      minRatingController.text.trim()),
                                  deliveryAvailable: deliveryAvailable,
                                  pickupOnly: pickupOnly,
                                ),
                              );
                            },
                            child: Text(l10n.applyFilters),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    minPriceController.dispose();
    maxPriceController.dispose();
    minRatingController.dispose();

    if (result != null) {
      setState(() {
        _filters = result;
        _future = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen(buyerCategorySlugProvider, (previous, next) {
      if (previous != next) _refresh();
    });
    _future ??= _load();

    final hasActiveFilters = _filters.category != null ||
        _filters.minPrice != null ||
        _filters.maxPrice != null ||
        _filters.minRating != null ||
        _filters.deliveryAvailable ||
        _filters.pickupOnly;

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
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: l10n.businessKeyword,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: l10n.searchFilters,
                          onPressed: () => _openFilters(l10n),
                          icon: Badge(
                            isLabelVisible: hasActiveFilters,
                            child: const Icon(Icons.tune_rounded),
                          ),
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
                  onChanged: (value) {
                    setState(() {
                      _mode = value;
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
                    onRetry: _refresh,
                  );
                }
                final page = snapshot.data;
                final count = switch (_mode) {
                  'services' => page?.services.length ?? 0,
                  'providers' => page?.sellers.length ?? 0,
                  _ => page?.products.length ?? 0,
                };
                if (count == 0) {
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal),
                  itemCount: count,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, index) {
                    if (_mode == 'services') {
                      final service = page!.services[index];
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
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${service.sellerName} · ${service.sellerCity}'),
                        trailing: Text(
                          _priceLabel(
                            l10n,
                            isOffer: service.isOffer,
                            priceMad: service.priceMad,
                          ),
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800),
                        ),
                        onTap: () => context
                            .push('/seller/${service.sellerId}'),
                      );
                    }
                    if (_mode == 'providers') {
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
                            ),
                          ),
                        ),
                        title: Text(seller.businessName,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle:
                            Text('${seller.city} · ${seller.averageRating} ★'),
                        trailing: Icon(
                          DirectionalUi.forwardChevron(context),
                          color: AppColors.textSecondary,
                        ),
                        onTap: () => context.push('/seller/${seller.id}'),
                      );
                    }
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
                          ),
                        ),
                      ),
                      title: Text(product.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          '${product.sellerName} · ${product.sellerCity}'),
                      trailing: Text(
                        _priceLabel(
                          l10n,
                          isOffer: product.isOffer,
                          priceMad: product.priceMad,
                        ),
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800),
                      ),
                      onTap: () => context
                          .push('/product/${product.sellerId}/${product.id}'),
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
