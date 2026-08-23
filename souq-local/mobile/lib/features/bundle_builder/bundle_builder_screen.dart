import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/bundle_models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/buyer_ui_components.dart';
import '../../core/widgets/network_image_view.dart';
import '../../l10n/app_localizations.dart';
import '../buyer/buyer_home_screen.dart';

final bundleTemplatesProvider =
    FutureProvider.autoDispose<List<BundleTemplateModel>>((ref) async {
  final marketplace = ref.watch(buyerMarketplaceSlugProvider);
  return apiServiceProvider.fetchBundleTemplates(marketplace: marketplace);
});

class BundleBuilderScreen extends ConsumerStatefulWidget {
  const BundleBuilderScreen({super.key, this.initialTemplateSlug});

  final String? initialTemplateSlug;

  @override
  ConsumerState<BundleBuilderScreen> createState() => _BundleBuilderScreenState();
}

class _BundleBuilderScreenState extends ConsumerState<BundleBuilderScreen> {
  BundleTemplateModel? _selectedTemplate;
  BundleResolveResultModel? _result;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialTemplateSlug != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _selectBySlug(widget.initialTemplateSlug!));
    }
  }

  Future<void> _selectBySlug(String slug) async {
    final templates = await ref.read(bundleTemplatesProvider.future);
    final match = templates.where((t) => t.slug == slug).firstOrNull;
    if (match != null) {
      setState(() => _selectedTemplate = match);
      await _resolveBundle(match);
    }
  }

  Future<void> _resolveBundle(BundleTemplateModel template) async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedTemplate = template;
    });
    final marketplace =
        ref.read(buyerMarketplaceSlugProvider) ?? template.marketplaceSlug;
    try {
      final result = await apiServiceProvider.resolveBundle(
        marketplace: marketplace,
        templateSlug: template.slug,
        slots: template.slots,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final templatesAsync = ref.watch(bundleTemplatesProvider);
    final marketplace = ref.watch(buyerMarketplaceSlugProvider);

    return BuyerScreenScaffold(
      appBar: BuyerAppBar(title: l10n.bundleBuilderTitle),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(bundleTemplatesProvider);
          if (_selectedTemplate != null) {
            await _resolveBundle(_selectedTemplate!);
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          children: [
            Text(
              l10n.bundleBuilderSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
            ),
            if (marketplace != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.bundleBuilderMarketplace(marketplace),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.bundleBuilderChooseTemplate,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            templatesAsync.when(
              data: (templates) => Column(
                children: templates
                    .map(
                      (template) => _TemplateCard(
                        template: template,
                        selected: _selectedTemplate?.slug == template.slug,
                        onTap: () => _resolveBundle(template),
                      ),
                    )
                    .toList(),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => AsyncErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(bundleTemplatesProvider),
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: AppSpacing.lg),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AsyncErrorView(
                message: _error!,
                onRetry: _selectedTemplate == null
                    ? null
                    : () => _resolveBundle(_selectedTemplate!),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _BundleSummaryCard(result: _result!),
              const SizedBox(height: AppSpacing.md),
              ..._result!.picks.map((pick) => _BundlePickTile(pick: pick)),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.bundleBuilderSellerBreakdown,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ..._result!.sellerBreakdown.map(
                (seller) => _SellerBreakdownCard(
                  seller: seller,
                  onContact: () => context.push('/seller/${seller.sellerId}'),
                ),
              ),
              if (_result!.missingSlots.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _MissingSlotsBanner(slots: _result!.missingSlots),
              ],
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final BundleTemplateModel template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? context.colors.primary : context.colors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: context.colors.surfaceVariant,
                child: Icon(_iconFor(template.icon), color: context.colors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.description,
                      style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${template.slots.length} components',
                      style: TextStyle(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: context.colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _BundleSummaryCard extends StatelessWidget {
  const _BundleSummaryCard({required this.result});

  final BundleResolveResultModel result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      color: context.colors.surfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.bundleBuilderSummary,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: AppSpacing.md),
            _SummaryRow(
              label: l10n.bundleBuilderTotalPrice,
              value: '${result.totalPriceMad.toStringAsFixed(0)} MAD',
              emphasized: true,
            ),
            _SummaryRow(
              label: l10n.bundleBuilderSavings,
              value:
                  '${result.savingsMad.toStringAsFixed(0)} MAD (${result.savingsPercent.toStringAsFixed(0)}%)',
              valueColor: Colors.green.shade700,
            ),
            _SummaryRow(
              label: l10n.bundleBuilderAvailability,
              value: result.allAvailable
                  ? l10n.bundleBuilderAllAvailable
                  : l10n.bundleBuilderPartialAvailability,
            ),
            _SummaryRow(
              label: l10n.bundleBuilderMatchedSlots,
              value: '${result.slotsMatched}/${result.slotsRequested}',
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
              fontSize: emphasized ? 18 : 14,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _BundlePickTile extends StatelessWidget {
  const _BundlePickTile({required this.pick});

  final BundlePickModel pick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 56,
            height: 56,
            child: pick.imageUrl.isNotEmpty
                ? NetworkImageView(url: pick.imageUrl, fit: BoxFit.cover)
                : ColoredBox(
                    color: context.colors.surfaceVariant,
                    child: Icon(Icons.inventory_2_outlined, color: context.colors.primary),
                  ),
          ),
        ),
        title: Text(pick.slotLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pick.productName),
            Text('${pick.priceMad.toStringAsFixed(0)} MAD · ${pick.sellerName}'),
            Text(
              '${l10n.bundleBuilderWarranty}: ${pick.warrantyNote}',
              style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
            ),
            Text(
              pick.isAvailable && pick.stockQuantity > 0
                  ? l10n.bundleBuilderInStock
                  : l10n.bundleBuilderCheckAvailability,
              style: TextStyle(
                fontSize: 12,
                color: pick.isAvailable ? Colors.green.shade700 : Colors.orange.shade800,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () => context.push('/seller/${pick.sellerId}'),
      ),
    );
  }
}

class _SellerBreakdownCard extends StatelessWidget {
  const _SellerBreakdownCard({
    required this.seller,
    required this.onContact,
  });

  final BundleSellerBreakdownModel seller;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    seller.sellerName,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                if (seller.sellerVerified)
                  Icon(Icons.verified_rounded, size: 18, color: context.colors.primary),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${seller.itemCount} items · ${seller.subtotalMad.toStringAsFixed(0)} MAD',
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              '${l10n.bundleBuilderWarranty}: ${seller.warrantySummary}',
              style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: seller.items
                  .map((item) => Chip(label: Text(item.slotLabel)))
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onContact, child: Text(l10n.bundleBuilderContactSeller)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingSlotsBanner extends StatelessWidget {
  const _MissingSlotsBanner({required this.slots});

  final List<String> slots;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Text(
        'No listings found for: ${slots.join(', ')}',
        style: TextStyle(color: Colors.orange.shade900),
      ),
    );
  }
}

IconData _iconFor(String name) {
  const map = {
    'sports_esports': Icons.sports_esports_rounded,
    'smartphone': Icons.smartphone_rounded,
    'car_repair': Icons.car_repair_rounded,
  };
  return map[name] ?? Icons.inventory_2_outlined;
}
