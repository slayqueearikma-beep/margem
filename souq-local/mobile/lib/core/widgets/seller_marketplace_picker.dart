import 'package:flutter/material.dart';

import '../models/models.dart';
import '../../l10n/app_localizations.dart';

/// UI-only value when the seller chooses a market not listed in the app.
const sellerMarketplaceCustomOption = '__custom__';

/// Backend slug for seller-provided market names.
const sellerOtherCasablancaMarketSlug = 'other-casablanca-markets';

/// Popular Casablanca markets plus a "More" option for custom names.
class SellerMarketplacePicker extends StatelessWidget {
  const SellerMarketplacePicker({
    super.key,
    required this.markets,
    required this.selectedSlug,
    required this.customNameController,
    required this.onSlugChanged,
    this.enabled = true,
  });

  final List<MarketplaceVenueModel> markets;
  final String? selectedSlug;
  final TextEditingController customNameController;
  final ValueChanged<String?> onSlugChanged;
  final bool enabled;

  List<MarketplaceVenueModel> get _selectableMarkets => markets
      .where((market) => market.slug != sellerOtherCasablancaMarketSlug)
      .toList();

  bool get isCustomSelected => selectedSlug == sellerMarketplaceCustomOption;

  static bool usesCustomMarket(String? slug, String customName) =>
      slug == sellerMarketplaceCustomOption || customName.trim().isNotEmpty;

  static String? marketplaceSlugForApi({
    required String? selectedSlug,
    required String customName,
  }) {
    if (usesCustomMarket(selectedSlug, customName)) {
      return sellerOtherCasablancaMarketSlug;
    }
    return selectedSlug;
  }

  static String customMarketplaceNameForApi({
    required String? selectedSlug,
    required String customName,
  }) {
    if (selectedSlug == sellerMarketplaceCustomOption) {
      return customName.trim();
    }
    return '';
  }

  static String? initialSelectedSlug({
    required String? marketplaceSlug,
    required String customMarketplaceName,
  }) {
    if (customMarketplaceName.trim().isNotEmpty ||
        marketplaceSlug == sellerOtherCasablancaMarketSlug) {
      return sellerMarketplaceCustomOption;
    }
    return marketplaceSlug;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectable = _selectableMarkets;
    if (selectable.isEmpty) {
      return Text(l10n.somethingWentWrong);
    }

    final dropdownValue = isCustomSelected
        ? sellerMarketplaceCustomOption
        : (selectedSlug != null &&
                selectable.any((market) => market.slug == selectedSlug)
            ? selectedSlug
            : selectable.first.slug);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: dropdownValue,
          decoration: InputDecoration(labelText: l10n.chooseMarketLabel),
          items: [
            for (final market in selectable)
              DropdownMenuItem(
                value: market.slug,
                child: Text(market.displayName),
              ),
            DropdownMenuItem(
              value: sellerMarketplaceCustomOption,
              child: Text(l10n.chooseMarketMoreOption),
            ),
          ],
          onChanged: enabled ? onSlugChanged : null,
        ),
        if (isCustomSelected) ...[
          const SizedBox(height: 12),
          TextField(
            controller: customNameController,
            enabled: enabled,
            decoration: InputDecoration(
              labelText: l10n.customMarketNameLabel,
              hintText: l10n.customMarketNameHint,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.customMarketNameHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
