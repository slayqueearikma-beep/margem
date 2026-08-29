import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/data/city_coordinates.dart';
import '../../core/models/auth_models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/margem_app_bar.dart';
import '../../core/widgets/seller_marketplace_picker.dart';
import '../../features/buyer/buyer_home_screen.dart';
import '../../l10n/app_localizations.dart';
import '../legal/legal_config.dart';
import '../legal/legal_documents.dart';
import '../legal/legal_document_screen.dart';

/// Logged-in users open a storefront on the same email/password account.
class BecomeSellerScreen extends ConsumerStatefulWidget {
  const BecomeSellerScreen({super.key});

  @override
  ConsumerState<BecomeSellerScreen> createState() => _BecomeSellerScreenState();
}

class _BecomeSellerScreenState extends ConsumerState<BecomeSellerScreen> {
  final _businessName = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _shopNumber = TextEditingController();
  final _marketGallery = TextEditingController();
  final _customMarketName = TextEditingController();
  String? _selectedMarketSlug;
  bool _loading = false;
  bool _sellerTermsAccepted = false;

  @override
  void dispose() {
    _businessName.dispose();
    _description.dispose();
    _address.dispose();
    _phone.dispose();
    _shopNumber.dispose();
    _marketGallery.dispose();
    _customMarketName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final session = ref.read(userSessionProvider);
    if (session == null || session.isGuest) {
      context.push('/login');
      return;
    }
    final markets = ref.read(buyerMarketplacesProvider).valueOrNull ?? const [];
    final marketSlug = _selectedMarketSlug ??
        (markets.isNotEmpty ? markets.first.slug : null);
    final customMarket = _customMarketName.text.trim();
    final usesCustom = SellerMarketplacePicker.usesCustomMarket(marketSlug, customMarket);
    if (_businessName.text.trim().length < 2 ||
        _address.text.trim().length < 5 ||
        _phone.text.trim().isEmpty ||
        marketSlug == null ||
        marketSlug.isEmpty ||
        (usesCustom && customMarket.length < 2)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.completeRequiredStep)),
      );
      return;
    }
    if (!_sellerTermsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.completeRequiredStep)),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final coords = CityCoordinates.casablanca;
      final locale = Localizations.localeOf(context).languageCode;
      final seller = await apiServiceProvider.createSeller(
        SellerCreatePayload(
          businessName: _businessName.text.trim(),
          description: _description.text.trim(),
          address: _address.text.trim(),
          city: AppConfig.launchCity,
          latitude: coords.latitude,
          longitude: coords.longitude,
          phone: _phone.text.trim(),
          marketplaceSlug: SellerMarketplacePicker.marketplaceSlugForApi(
            selectedSlug: _selectedMarketSlug,
            customName: customMarket,
          ),
          customMarketplaceName: SellerMarketplacePicker.customMarketplaceNameForApi(
            selectedSlug: _selectedMarketSlug,
            customName: customMarket,
          ),
          shopNumber: _shopNumber.text.trim(),
          marketGallery: _marketGallery.text.trim(),
          sellerTermsAcknowledged: true,
          acceptanceLanguage: LegalConfig.authoritativeLanguageCode,
        ),
      );
      final storage = ref.read(appStorageProvider);
      final updated = session.copyWith(
        accountType: AccountType.seller,
        sellerId: seller.id,
        businessName: seller.businessName,
        city: seller.city,
      );
      await storage?.saveSession(updated);
      await storage?.saveAppMode(AppMode.seller);
      ref.read(userSessionProvider.notifier).state = updated;
      if (!mounted) return;
      context.go('/seller/dashboard');
    } on ApiException catch (error) {
      if (mounted) {
        await showAppErrorDialog(
          context,
          title: l10n.somethingWentWrong,
          message: error.message,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final marketsAsync = ref.watch(buyerMarketplacesProvider);
    return Scaffold(
      appBar: MarGemAppBar(semanticLabel: l10n.becomeSeller),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          children: [
            Text(
              l10n.becomeSellerSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _businessName,
              decoration: InputDecoration(labelText: l10n.businessName),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.description),
            ),
            const SizedBox(height: AppSpacing.md),
            marketsAsync.when(
              data: (markets) => SellerMarketplacePicker(
                markets: markets,
                selectedSlug: _selectedMarketSlug ?? markets.first.slug,
                customNameController: _customMarketName,
                enabled: !_loading,
                onSlugChanged: (value) => setState(() => _selectedMarketSlug = value),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Text(l10n.somethingWentWrong),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _marketGallery,
              decoration: InputDecoration(labelText: '${l10n.shopLocationTitle} — Gallery'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _shopNumber,
              decoration: InputDecoration(labelText: '${l10n.shopLocationTitle} — Shop #'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _address,
              decoration: InputDecoration(labelText: l10n.fullAddress),
            ),
            const SizedBox(height: AppSpacing.md),
            InputDecorator(
              decoration: InputDecoration(labelText: l10n.city),
              child: const Text(AppConfig.launchCity),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: l10n.phoneNumber),
            ),
            const SizedBox(height: AppSpacing.lg),
            CheckboxListTile(
              value: _sellerTermsAccepted,
              onChanged: _loading
                  ? null
                  : (value) => setState(() => _sellerTermsAccepted = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('${l10n.signupTermsPrefix} '),
                  InkWell(
                    onTap: () =>
                        openLegalDocument(context, LegalDocumentId.sellerTerms),
                    child: Text(
                      l10n.sellerTerms,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  Text(l10n.signupTermsSuffix),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: l10n.openStorefront,
              isLoading: _loading,
              onPressed: _loading || !_sellerTermsAccepted ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
