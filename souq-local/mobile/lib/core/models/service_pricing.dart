import '../../l10n/strings/app_strings.dart';

enum ServicePricingModel {
  fixedPrice('fixed_price'),
  startingFrom('starting_from'),
  priceRange('price_range'),
  hourly('hourly'),
  daily('daily'),
  weekly('weekly'),
  monthly('monthly'),
  perPerson('per_person'),
  perUnit('per_unit'),
  perSqm('per_sqm'),
  perKm('per_km'),
  requestQuote('request_quote'),
  contactForPrice('contact_for_price'),
  negotiable('negotiable'),
  free('free');

  const ServicePricingModel(this.apiValue);

  final String apiValue;

  static ServicePricingModel fromApi(String? value) {
    return ServicePricingModel.values.firstWhere(
      (model) => model.apiValue == value,
      orElse: () => ServicePricingModel.fixedPrice,
    );
  }

  bool get requiresSinglePrice =>
      this == fixedPrice ||
      this == startingFrom ||
      this == hourly ||
      this == daily ||
      this == weekly ||
      this == monthly ||
      this == perPerson ||
      this == perUnit ||
      this == perSqm ||
      this == perKm ||
      this == negotiable;

  bool get requiresPriceRange => this == priceRange;

  bool get hidesPriceInput =>
      this == requestQuote || this == contactForPrice || this == free;

  String label(AppStrings l10n) {
    switch (this) {
      case ServicePricingModel.fixedPrice:
        return l10n.pricingModelFixedPrice;
      case ServicePricingModel.startingFrom:
        return l10n.pricingModelStartingFrom;
      case ServicePricingModel.priceRange:
        return l10n.pricingModelPriceRange;
      case ServicePricingModel.hourly:
        return l10n.pricingModelHourly;
      case ServicePricingModel.daily:
        return l10n.pricingModelDaily;
      case ServicePricingModel.weekly:
        return l10n.pricingModelWeekly;
      case ServicePricingModel.monthly:
        return l10n.pricingModelMonthly;
      case ServicePricingModel.perPerson:
        return l10n.pricingModelPerPerson;
      case ServicePricingModel.perUnit:
        return l10n.pricingModelPerUnit;
      case ServicePricingModel.perSqm:
        return l10n.pricingModelPerSqm;
      case ServicePricingModel.perKm:
        return l10n.pricingModelPerKm;
      case ServicePricingModel.requestQuote:
        return l10n.pricingModelRequestQuote;
      case ServicePricingModel.contactForPrice:
        return l10n.pricingModelContactForPrice;
      case ServicePricingModel.negotiable:
        return l10n.pricingModelNegotiable;
      case ServicePricingModel.free:
        return l10n.pricingModelFree;
    }
  }
}

String formatServicePrice(
  AppStrings l10n, {
  required ServicePricingModel pricingModel,
  double? priceMad,
  double? priceMinMad,
  double? priceMaxMad,
  bool priceNegotiable = false,
}) {
  String amount(double value) {
    final decimals = value % 1 == 0 ? 0 : 2;
    return '${value.toStringAsFixed(decimals)} MAD';
  }

  switch (pricingModel) {
    case ServicePricingModel.fixedPrice:
      return priceMad == null ? l10n.priceOnRequest : amount(priceMad);
    case ServicePricingModel.startingFrom:
      return priceMad == null ? l10n.priceOnRequest : l10n.priceStartingFrom(amount(priceMad));
    case ServicePricingModel.priceRange:
      if (priceMinMad == null || priceMaxMad == null) return l10n.priceOnRequest;
      return l10n.priceRangeLabel(amount(priceMinMad), amount(priceMaxMad));
    case ServicePricingModel.hourly:
      return priceMad == null ? l10n.priceOnRequest : l10n.pricePerHour(amount(priceMad));
    case ServicePricingModel.daily:
      return priceMad == null ? l10n.priceOnRequest : l10n.pricePerDay(amount(priceMad));
    case ServicePricingModel.weekly:
      return priceMad == null ? l10n.priceOnRequest : l10n.pricePerWeek(amount(priceMad));
    case ServicePricingModel.monthly:
      return priceMad == null ? l10n.priceOnRequest : l10n.pricePerMonth(amount(priceMad));
    case ServicePricingModel.perPerson:
      return priceMad == null ? l10n.priceOnRequest : l10n.pricePerPerson(amount(priceMad));
    case ServicePricingModel.perUnit:
      return priceMad == null ? l10n.priceOnRequest : l10n.pricePerUnit(amount(priceMad));
    case ServicePricingModel.perSqm:
      return priceMad == null ? l10n.priceOnRequest : l10n.pricePerSqm(amount(priceMad));
    case ServicePricingModel.perKm:
      return priceMad == null ? l10n.priceOnRequest : l10n.pricePerKm(amount(priceMad));
    case ServicePricingModel.requestQuote:
      return l10n.pricingModelRequestQuote;
    case ServicePricingModel.contactForPrice:
      return l10n.pricingModelContactForPrice;
    case ServicePricingModel.negotiable:
      if (priceMad != null) return l10n.priceNegotiableWithAmount(amount(priceMad));
      return l10n.priceNegotiable;
    case ServicePricingModel.free:
      return l10n.pricingModelFree;
  }
}
