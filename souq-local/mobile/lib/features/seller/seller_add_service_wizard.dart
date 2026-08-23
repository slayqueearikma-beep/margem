import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/auth_models.dart';
import '../../core/models/service_pricing.dart';
import '../../core/services/api_service.dart';
import '../../core/services/upload_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/network_image_view.dart';
import '../../core/widgets/service_pricing_fields.dart';
import '../../l10n/app_localizations.dart';
import 'seller_account_provider.dart';
import 'seller_widgets.dart';

class SellerAddServiceWizard extends ConsumerStatefulWidget {
  const SellerAddServiceWizard({super.key});

  @override
  ConsumerState<SellerAddServiceWizard> createState() =>
      _SellerAddServiceWizardState();
}

class _SellerAddServiceWizardState extends ConsumerState<SellerAddServiceWizard> {
  final _pageController = PageController();
  final _pricingKey = GlobalKey<ServicePricingFieldsState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _step = 0;
  bool _loading = false;
  bool _available = true;
  String _imageUrl = '';
  XFile? _pickedImage;
  ServicePricingInput? _pricingPreview;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
    );
    if (image != null) setState(() => _pickedImage = image);
  }

  void _next() {
    final l10n = context.l10n;
    if (_step == 0) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.completeRequiredStep)),
        );
        return;
      }
    }
    if (_step == 1) {
      try {
        _pricingPreview = _pricingKey.currentState!.validate();
      } on PricingValidationException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
        return;
      }
    }
    if (_step < 2) {
      setState(() => _step += 1);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _save();
    }
  }

  void _back() {
    if (_step == 0) {
      context.pop();
      return;
    }
    setState(() => _step -= 1);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final pricing = _pricingPreview ?? _pricingKey.currentState?.validate();
    if (pricing == null) return;

    setState(() => _loading = true);
    try {
      await apiServiceProvider.runSubmit(() async {
        final account = await ref.read(sellerAccountProvider.future);
        var imageUrl = _imageUrl;
        if (_pickedImage != null) {
          imageUrl =
              await ref.read(uploadServiceProvider).uploadImage(_pickedImage!);
        }
        await apiServiceProvider.addService(
          account.profile.id,
          ServiceCreatePayload(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            pricingModel: pricing.pricingModel.apiValue,
            priceMad: pricing.priceMad,
            priceMinMad: pricing.priceMinMad,
            priceMaxMad: pricing.priceMaxMad,
            imageUrl: imageUrl,
            isAvailable: _available,
          ),
        );
      });
      ref.invalidate(sellerAccountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.serviceSaved)),
      );
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorDialog(
        context,
        title: l10n.somethingWentWrong,
        message: e.message,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final previewPrice = _pricingPreview == null
        ? l10n.priceOnRequest
        : formatServicePrice(
            l10n,
            pricingModel: _pricingPreview!.pricingModel,
            priceMad: _pricingPreview!.priceMad,
            priceMinMad: _pricingPreview!.priceMinMad,
            priceMaxMad: _pricingPreview!.priceMaxMad,
          );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _loading ? null : _back,
        ),
        title: Text(l10n.addService),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              8,
              AppSpacing.screenHorizontal,
              12,
            ),
            child: SellerStepIndicator(
              currentStep: _step,
              totalSteps: 3,
              labels: [
                l10n.stepBasicInfo,
                l10n.stepPricing,
                l10n.stepDetails,
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StepBasicInfo(
                  nameController: _nameController,
                  descriptionController: _descriptionController,
                  pickedImage: _pickedImage,
                  imageUrl: _imageUrl,
                  onPickImage: _pickImage,
                  l10n: l10n,
                ),
                _StepPricing(
                  pricingKey: _pricingKey,
                  l10n: l10n,
                  previewName: _nameController.text.trim().isEmpty
                      ? l10n.name
                      : _nameController.text.trim(),
                  previewPrice: previewPrice,
                ),
                _StepDetails(
                  available: _available,
                  onAvailableChanged: (value) =>
                      setState(() => _available = value),
                  l10n: l10n,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: PrimaryButton(
              label: _step == 2 ? l10n.publishService : l10n.nextStep,
              onPressed: _next,
              isLoading: _loading,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _StepBasicInfo extends StatelessWidget {
  const _StepBasicInfo({
    required this.nameController,
    required this.descriptionController,
    required this.pickedImage,
    required this.imageUrl,
    required this.onPickImage,
    required this.l10n,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final XFile? pickedImage;
  final String imageUrl;
  final VoidCallback onPickImage;
  final AppStrings l10n;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      children: [
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              GestureDetector(
                onTap: onPickImage,
                child: Container(
                  width: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: pickedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(pickedImage!.path),
                            fit: BoxFit.cover,
                          ),
                        )
                      : imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: NetworkImageView(
                                url: imageUrl,
                                placeholderIcon: Icons.add_a_photo_outlined,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_a_photo_outlined),
                                const SizedBox(height: 4),
                                Text(l10n.tapToUpload, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: l10n.name,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: l10n.description,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

class _StepPricing extends StatelessWidget {
  const _StepPricing({
    required this.pricingKey,
    required this.l10n,
    required this.previewName,
    required this.previewPrice,
  });

  final GlobalKey<ServicePricingFieldsState> pricingKey;
  final AppStrings l10n;
  final String previewName;
  final String previewPrice;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(AppSpacing.screenHorizontal),
      children: [
        ServicePricingFields(
          key: pricingKey,
          l10n: l10n,
          initialModel: ServicePricingModel.fixedPrice,
        ),
        SizedBox(height: AppSpacing.lg),
        Text(
          l10n.customersWillSee,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        SizedBox(height: 8),
        Card(
          child: ListTile(
            title: Text(previewName),
            trailing: Text(
              previewPrice,
              style: TextStyle(
                color: context.colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepDetails extends StatelessWidget {
  const _StepDetails({
    required this.available,
    required this.onAvailableChanged,
    required this.l10n,
  });

  final bool available;
  final ValueChanged<bool> onAvailableChanged;
  final AppStrings l10n;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.serviceStatusLive),
          subtitle: Text(
            available ? l10n.available : l10n.unavailable,
          ),
          value: available,
          onChanged: onAvailableChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.serviceDetailsHint,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
