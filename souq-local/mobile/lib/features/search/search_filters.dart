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
