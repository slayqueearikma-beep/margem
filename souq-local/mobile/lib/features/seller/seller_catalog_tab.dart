import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/network_image_view.dart';
import '../../core/widgets/service_card.dart';
import '../../l10n/app_localizations.dart';
import 'seller_account_provider.dart';
import 'seller_navigation.dart';
import 'seller_widgets.dart';

class SellerCatalogTab extends ConsumerStatefulWidget {
  const SellerCatalogTab({super.key});

  @override
  ConsumerState<SellerCatalogTab> createState() => _SellerCatalogTabState();
}

class _SellerCatalogTabState extends ConsumerState<SellerCatalogTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kind = ref.watch(sellerCatalogKindProvider);
    final availability = ref.watch(sellerCatalogAvailabilityProvider);
    final accountAsync = ref.watch(sellerAccountProvider);

    return accountAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AsyncErrorView.fromError(
        error,
        onRetry: () => ref.invalidate(sellerAccountProvider),
      ),
      data: (account) {
          final services = account.profile.services.where((service) {
            final matchesQuery = _query.isEmpty ||
                service.name.toLowerCase().contains(_query.toLowerCase());
            final matchesAvailability = switch (availability) {
              SellerCatalogAvailability.all => true,
              SellerCatalogAvailability.active => service.isAvailable,
              SellerCatalogAvailability.inactive => !service.isAvailable,
            };
            return matchesQuery && matchesAvailability;
          }).toList();

          final products = account.profile.products.where((product) {
            final matchesQuery = _query.isEmpty ||
                product.name.toLowerCase().contains(_query.toLowerCase());
            final matchesAvailability = switch (availability) {
              SellerCatalogAvailability.all => true,
              SellerCatalogAvailability.active => product.isAvailable,
              SellerCatalogAvailability.inactive => !product.isAvailable,
            };
            return matchesQuery && matchesAvailability;
          }).toList();

          final showingServices = kind == SellerCatalogKind.services;
          final items = showingServices ? services.length : products.length;
          final activeCount = showingServices
              ? account.profile.services.where((s) => s.isAvailable).length
              : account.profile.products.where((p) => p.isAvailable).length;
          final inactiveCount = showingServices
              ? account.profile.services.length - activeCount
              : account.profile.products.length - activeCount;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  0,
                  AppSpacing.screenHorizontal,
                  8,
                ),
                child: SegmentedButton<SellerCatalogKind>(
                  segments: [
                    ButtonSegment(
                      value: SellerCatalogKind.services,
                      label: Text(l10n.services),
                      icon: const Icon(Icons.handyman_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: SellerCatalogKind.products,
                      label: Text(l10n.products),
                      icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    ),
                  ],
                  selected: {kind},
                  onSelectionChanged: (value) {
                    ref.read(sellerCatalogKindProvider.notifier).state =
                        value.first;
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                child: Row(
                  children: [
                    _FilterChip(
                      label: l10n.filterAll(items),
                      selected: availability == SellerCatalogAvailability.all,
                      onTap: () => ref
                          .read(sellerCatalogAvailabilityProvider.notifier)
                          .state = SellerCatalogAvailability.all,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: l10n.filterActive(activeCount),
                      selected:
                          availability == SellerCatalogAvailability.active,
                      onTap: () => ref
                          .read(sellerCatalogAvailabilityProvider.notifier)
                          .state = SellerCatalogAvailability.active,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: l10n.filterInactive(inactiveCount),
                      selected:
                          availability == SellerCatalogAvailability.inactive,
                      onTap: () => ref
                          .read(sellerCatalogAvailabilityProvider.notifier)
                          .state = SellerCatalogAvailability.inactive,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => ref.invalidate(sellerAccountProvider),
                  child: items == 0
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Icon(
                              showingServices
                                  ? Icons.handyman_outlined
                                  : Icons.inventory_2_outlined,
                              size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                showingServices
                                    ? l10n.noServicesYet
                                    : l10n.noProductsYet,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenHorizontal,
                            8,
                            AppSpacing.screenHorizontal,
                            100,
                          ),
                          itemCount: items,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            if (showingServices) {
                              final service = services[index];
                              return ServiceCard(
                                service: service,
                                showAvailability: true,
                                onTap: () => context.push(
                                  '/seller/services/${service.id}',
                                ),
                              );
                            }
                            final product = products[index];
                            return _ProductListCard(
                              productName: product.name,
                              priceLabel: product.priceMad != null
                                  ? '${product.priceMad!.toStringAsFixed(0)} MAD'
                                  : l10n.priceOnRequest,
                              imageUrl: product.imageUrl,
                              active: product.isAvailable,
                              activeLabel: l10n.available,
                              inactiveLabel: l10n.unavailable,
                              onTap: () => context.push(
                                '/seller/products/${product.id}',
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.cardSelected,
      checkmarkColor: AppColors.primary,
    );
  }
}

class _ProductListCard extends StatelessWidget {
  const _ProductListCard({
    required this.productName,
    required this.priceLabel,
    required this.imageUrl,
    required this.active,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.onTap,
  });

  final String productName;
  final String priceLabel;
  final String imageUrl;
  final bool active;
  final String activeLabel;
  final String inactiveLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: NetworkImageView(
                    url: imageUrl,
                    placeholderIcon: Icons.shopping_bag_outlined,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      priceLabel,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SellerStatusBadge(
                      label: active ? activeLabel : inactiveLabel,
                      active: active,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
