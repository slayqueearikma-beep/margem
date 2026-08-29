import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/auth_models.dart';
import '../../core/models/models.dart';
import '../../core/models/service_pricing.dart';
import '../../core/services/api_service.dart';
import '../../core/services/upload_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/margem_app_bar.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/network_image_view.dart';
import '../../core/widgets/service_pricing_fields.dart';
import '../../l10n/app_localizations.dart';
import 'seller_account_provider.dart';

class SellerServiceEditorScreen extends ConsumerStatefulWidget {
  const SellerServiceEditorScreen({super.key, this.serviceId});

  final String? serviceId;

  bool get isEditing => serviceId != null;

  @override
  ConsumerState<SellerServiceEditorScreen> createState() =>
      _SellerServiceEditorScreenState();
}

class _SellerServiceEditorScreenState
    extends ConsumerState<SellerServiceEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pricingKey = GlobalKey<ServicePricingFieldsState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _available = true;
  bool _loading = false;
  bool _initialized = false;
  String _imageUrl = '';
  XFile? _pickedImage;
  ServiceModel? _existing;
  ServicePricingModel _pricingModel = ServicePricingModel.fixedPrice;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _hydrate(ServiceModel service) {
    if (_initialized) return;
    _existing = service;
    _nameController.text = service.name;
    _descriptionController.text = service.description;
    _available = service.isAvailable;
    _imageUrl = service.imageUrl;
    _pricingModel = service.pricingModel;
    _initialized = true;
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
    );
    if (image != null) setState(() => _pickedImage = image);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.completeRequiredStep)),
      );
      return;
    }

    ServicePricingInput pricingInput;
    try {
      pricingInput = _pricingKey.currentState!.validate()!;
    } on PricingValidationException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    setState(() => _loading = true);
    try {
      await apiServiceProvider.runSubmit(() async {
        final account = await ref.read(sellerAccountProvider.future);
        final sellerId = account.profile.id;

        var imageUrl = _imageUrl;
        if (_pickedImage != null) {
          imageUrl = await ref.read(uploadServiceProvider).uploadImage(_pickedImage!);
        }

        if (widget.isEditing) {
          await apiServiceProvider.updateService(
            sellerId,
            widget.serviceId!,
            ServiceUpdatePayload(
              name: name,
              description: _descriptionController.text.trim(),
              pricingModel: pricingInput.pricingModel.apiValue,
              priceMad: pricingInput.priceMad,
              priceMinMad: pricingInput.priceMinMad,
              priceMaxMad: pricingInput.priceMaxMad,
              clearPrice: pricingInput.priceMad == null &&
                  !pricingInput.pricingModel.requiresSinglePrice &&
                  pricingInput.pricingModel != ServicePricingModel.negotiable,
              clearMinPrice: pricingInput.priceMinMad == null,
              clearMaxPrice: pricingInput.priceMaxMad == null,
              imageUrl: imageUrl,
              isAvailable: _available,
            ),
          );
        } else {
          await apiServiceProvider.addService(
            sellerId,
            ServiceCreatePayload(
              name: name,
              description: _descriptionController.text.trim(),
              pricingModel: pricingInput.pricingModel.apiValue,
              priceMad: pricingInput.priceMad,
              priceMinMad: pricingInput.priceMinMad,
              priceMaxMad: pricingInput.priceMaxMad,
              imageUrl: imageUrl,
              isAvailable: _available,
            ),
          );
        }
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

  Future<void> _delete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteService),
        content: Text(l10n.deleteServiceConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteService),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final account = await ref.read(sellerAccountProvider.future);
      await apiServiceProvider.deleteService(
        account.profile.id,
        widget.serviceId!,
      );
      ref.invalidate(sellerAccountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.serviceDeleted)),
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

    if (widget.isEditing) {
      final accountAsync = ref.watch(sellerAccountProvider);
      return accountAsync.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(
          appBar: const MarGemAppBar(),
          body: AsyncErrorView.fromError(
            error,
            onRetry: () => ref.invalidate(sellerAccountProvider),
          ),
        ),
        data: (account) {
          final service = account.profile.services
              .where((item) => item.id == widget.serviceId)
              .firstOrNull;
          if (service == null) {
            return Scaffold(
              appBar: const MarGemAppBar(),
              body: Center(child: Text(l10n.somethingWentWrong)),
            );
          }
          _hydrate(service);
          return _buildForm(l10n, service);
        },
      );
    }

    return _buildForm(l10n, _existing);
  }

  Widget _buildForm(AppStrings l10n, ServiceModel? existing) {
    return Scaffold(
      appBar: MarGemAppBar(
        semanticLabel: widget.isEditing ? l10n.editService : l10n.addService,
        actions: [
          if (widget.isEditing)
            IconButton(
              onPressed: _loading ? null : _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteService,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          children: [
            GestureDetector(
              onTap: _loading ? null : _pickImage,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _pickedImage != null
                      ? Image.file(File(_pickedImage!.path), fit: BoxFit.cover)
                      : _imageUrl.isNotEmpty
                          ? NetworkImageView(
                              url: _imageUrl,
                              placeholderIcon: Icons.handyman_outlined,
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_a_photo_outlined, size: 36),
                                const SizedBox(height: 8),
                                Text(l10n.tapToUpload),
                              ],
                            ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _nameController,
              enabled: !_loading,
              decoration: InputDecoration(labelText: l10n.name),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionController,
              enabled: !_loading,
              decoration: InputDecoration(labelText: l10n.description),
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            ServicePricingFields(
              key: _pricingKey,
              l10n: l10n,
              initialModel: existing?.pricingModel ?? _pricingModel,
              initialPriceMad: existing?.priceMad,
              initialPriceMinMad: existing?.priceMinMad,
              initialPriceMaxMad: existing?.priceMaxMad,
              enabled: !_loading,
            ),
            if (widget.isEditing) ...[
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_available ? l10n.available : l10n.unavailable),
                value: _available,
                onChanged:
                    _loading ? null : (value) => setState(() => _available = value),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: l10n.saveChanges,
              onPressed: _save,
              isLoading: _loading,
            ),
            if (_existing != null) const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
