import 'package:flutter/material.dart';

import '../../l10n/strings/app_strings.dart';
import '../models/service_pricing.dart';
import '../theme/app_spacing.dart';

class ServicePricingInput {
  const ServicePricingInput({
    required this.pricingModel,
    this.priceMad,
    this.priceMinMad,
    this.priceMaxMad,
  });

  final ServicePricingModel pricingModel;
  final double? priceMad;
  final double? priceMinMad;
  final double? priceMaxMad;
}

class ServicePricingFields extends StatefulWidget {
  const ServicePricingFields({
    super.key,
    required this.l10n,
    required this.initialModel,
    this.initialPriceMad,
    this.initialPriceMinMad,
    this.initialPriceMaxMad,
    this.enabled = true,
  });

  final AppStrings l10n;
  final ServicePricingModel initialModel;
  final double? initialPriceMad;
  final double? initialPriceMinMad;
  final double? initialPriceMaxMad;
  final bool enabled;

  @override
  State<ServicePricingFields> createState() => ServicePricingFieldsState();
}

class ServicePricingFieldsState extends State<ServicePricingFields> {
  late ServicePricingModel _model;
  final _priceController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _model = widget.initialModel;
    _setController(_priceController, widget.initialPriceMad);
    _setController(_minPriceController, widget.initialPriceMinMad);
    _setController(_maxPriceController, widget.initialPriceMaxMad);
  }

  @override
  void dispose() {
    _priceController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _setController(TextEditingController controller, double? value) {
    if (value == null) return;
    controller.text = value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
  }

  ServicePricingInput? validate() {
    final l10n = widget.l10n;

    if (_model.hidesPriceInput) {
      return ServicePricingInput(pricingModel: _model);
    }

    if (_model.requiresPriceRange) {
      final min = double.tryParse(_minPriceController.text.trim());
      final max = double.tryParse(_maxPriceController.text.trim());
      if (min == null || max == null) {
        throw PricingValidationException(l10n.enterValidPrice);
      }
      if (min > max) {
        throw PricingValidationException(l10n.minPriceExceedsMax);
      }
      return ServicePricingInput(
        pricingModel: _model,
        priceMinMad: min,
        priceMaxMad: max,
      );
    }

    if (_model.requiresSinglePrice && _model != ServicePricingModel.negotiable) {
      final price = double.tryParse(_priceController.text.trim());
      if (price == null) {
        throw PricingValidationException(l10n.enterValidPrice);
      }
      return ServicePricingInput(pricingModel: _model, priceMad: price);
    }

    if (_model == ServicePricingModel.negotiable) {
      final priceText = _priceController.text.trim();
      final price = priceText.isEmpty ? null : double.tryParse(priceText);
      if (priceText.isNotEmpty && price == null) {
        throw PricingValidationException(l10n.enterValidPrice);
      }
      return ServicePricingInput(pricingModel: _model, priceMad: price);
    }

    return ServicePricingInput(pricingModel: _model);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<ServicePricingModel>(
          value: _model,
          decoration: InputDecoration(
            labelText: l10n.pricingModel,
            border: const OutlineInputBorder(),
          ),
          items: ServicePricingModel.values
              .map(
                (model) => DropdownMenuItem(
                  value: model,
                  child: Text(model.label(l10n)),
                ),
              )
              .toList(),
          onChanged: widget.enabled
              ? (value) {
                  if (value == null) return;
                  setState(() {
                    _model = value;
                    if (value.hidesPriceInput) {
                      _priceController.clear();
                      _minPriceController.clear();
                      _maxPriceController.clear();
                    }
                  });
                }
              : null,
        ),
        const SizedBox(height: AppSpacing.md),
        if (_model.requiresSinglePrice)
          TextField(
            controller: _priceController,
            enabled: widget.enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _model == ServicePricingModel.negotiable
                  ? l10n.priceOptional
                  : l10n.priceMad,
              hintText: l10n.priceHint,
              border: const OutlineInputBorder(),
            ),
          ),
        if (_model.requiresPriceRange) ...[
          TextField(
            controller: _minPriceController,
            enabled: widget.enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.minPrice,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _maxPriceController,
            enabled: widget.enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.maxPrice,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
        if (_model.hidesPriceInput)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: Text(
              _model.label(l10n),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class PricingValidationException implements Exception {
  PricingValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
