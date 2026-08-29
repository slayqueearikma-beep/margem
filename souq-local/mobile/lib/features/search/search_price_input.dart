double? parseSearchPriceInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  return double.tryParse(trimmed);
}

String formatSearchPriceInput(double? value) {
  if (value == null) return '';
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toString();
}

bool isSearchPriceRangeValid(double? minPrice, double? maxPrice) {
  if (minPrice == null || maxPrice == null) return true;
  return minPrice <= maxPrice;
}
