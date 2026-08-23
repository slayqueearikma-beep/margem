class BundleSlotTemplateModel {
  const BundleSlotTemplateModel({
    required this.key,
    required this.label,
    this.categorySlug = '',
    this.query = '',
  });

  final String key;
  final String label;
  final String categorySlug;
  final String query;

  factory BundleSlotTemplateModel.fromJson(Map<String, dynamic> json) {
    return BundleSlotTemplateModel(
      key: json['key'] as String,
      label: json['label'] as String,
      categorySlug: json['category_slug'] as String? ?? '',
      query: json['query'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'category_slug': categorySlug,
        'query': query,
      };
}

class BundleTemplateModel {
  const BundleTemplateModel({
    required this.slug,
    required this.name,
    required this.description,
    required this.icon,
    required this.marketplaceSlug,
    required this.slots,
  });

  final String slug;
  final String name;
  final String description;
  final String icon;
  final String marketplaceSlug;
  final List<BundleSlotTemplateModel> slots;

  factory BundleTemplateModel.fromJson(Map<String, dynamic> json) {
    final slots = json['slots'] as List<dynamic>? ?? const [];
    return BundleTemplateModel(
      slug: json['slug'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? 'inventory_2',
      marketplaceSlug: json['marketplace_slug'] as String? ?? '',
      slots: slots
          .map((e) => BundleSlotTemplateModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BundlePickModel {
  const BundlePickModel({
    required this.slotKey,
    required this.slotLabel,
    required this.productId,
    required this.productName,
    required this.priceMad,
    required this.imageUrl,
    required this.categorySlug,
    required this.isAvailable,
    required this.stockQuantity,
    required this.availabilityNote,
    required this.warrantyNote,
    required this.sellerId,
    required this.sellerName,
    required this.sellerVerified,
    required this.sellerRating,
    required this.valueScore,
    required this.referencePriceMad,
  });

  final String slotKey;
  final String slotLabel;
  final String productId;
  final String productName;
  final double priceMad;
  final String imageUrl;
  final String categorySlug;
  final bool isAvailable;
  final int stockQuantity;
  final String availabilityNote;
  final String warrantyNote;
  final String sellerId;
  final String sellerName;
  final bool sellerVerified;
  final double sellerRating;
  final double valueScore;
  final double referencePriceMad;

  factory BundlePickModel.fromJson(Map<String, dynamic> json) {
    return BundlePickModel(
      slotKey: json['slot_key'] as String,
      slotLabel: json['slot_label'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String? ?? '',
      priceMad: (json['price_mad'] as num).toDouble(),
      imageUrl: json['image_url'] as String? ?? '',
      categorySlug: json['category_slug'] as String? ?? '',
      isAvailable: json['is_available'] as bool? ?? true,
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      availabilityNote: json['availability_note'] as String? ?? '',
      warrantyNote: json['warranty_note'] as String? ?? '',
      sellerId: json['seller_id'] as String,
      sellerName: json['seller_name'] as String? ?? '',
      sellerVerified: json['seller_verified'] as bool? ?? false,
      sellerRating: (json['seller_rating'] as num?)?.toDouble() ?? 0,
      valueScore: (json['value_score'] as num?)?.toDouble() ?? 0,
      referencePriceMad: (json['reference_price_mad'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BundleSellerBreakdownModel {
  const BundleSellerBreakdownModel({
    required this.sellerId,
    required this.sellerName,
    required this.sellerVerified,
    required this.sellerRating,
    required this.subtotalMad,
    required this.itemCount,
    required this.warrantySummary,
    required this.items,
  });

  final String sellerId;
  final String sellerName;
  final bool sellerVerified;
  final double sellerRating;
  final double subtotalMad;
  final int itemCount;
  final String warrantySummary;
  final List<BundlePickModel> items;

  factory BundleSellerBreakdownModel.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>? ?? const [];
    return BundleSellerBreakdownModel(
      sellerId: json['seller_id'] as String,
      sellerName: json['seller_name'] as String? ?? '',
      sellerVerified: json['seller_verified'] as bool? ?? false,
      sellerRating: (json['seller_rating'] as num?)?.toDouble() ?? 0,
      subtotalMad: (json['subtotal_mad'] as num).toDouble(),
      itemCount: json['item_count'] as int? ?? items.length,
      warrantySummary: json['warranty_summary'] as String? ?? '',
      items: items
          .map((e) => BundlePickModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BundleResolveResultModel {
  const BundleResolveResultModel({
    required this.marketplace,
    this.templateSlug,
    required this.slotsRequested,
    required this.slotsMatched,
    required this.totalPriceMad,
    required this.referencePriceMad,
    required this.savingsMad,
    required this.savingsPercent,
    required this.allAvailable,
    required this.picks,
    required this.missingSlots,
    required this.sellerBreakdown,
  });

  final String marketplace;
  final String? templateSlug;
  final int slotsRequested;
  final int slotsMatched;
  final double totalPriceMad;
  final double referencePriceMad;
  final double savingsMad;
  final double savingsPercent;
  final bool allAvailable;
  final List<BundlePickModel> picks;
  final List<String> missingSlots;
  final List<BundleSellerBreakdownModel> sellerBreakdown;

  factory BundleResolveResultModel.fromJson(Map<String, dynamic> json) {
    final picks = json['picks'] as List<dynamic>? ?? const [];
    final breakdown = json['seller_breakdown'] as List<dynamic>? ?? const [];
    final missing = json['missing_slots'] as List<dynamic>? ?? const [];
    return BundleResolveResultModel(
      marketplace: json['marketplace'] as String? ?? '',
      templateSlug: json['template_slug'] as String?,
      slotsRequested: json['slots_requested'] as int? ?? 0,
      slotsMatched: json['slots_matched'] as int? ?? 0,
      totalPriceMad: (json['total_price_mad'] as num?)?.toDouble() ?? 0,
      referencePriceMad: (json['reference_price_mad'] as num?)?.toDouble() ?? 0,
      savingsMad: (json['savings_mad'] as num?)?.toDouble() ?? 0,
      savingsPercent: (json['savings_percent'] as num?)?.toDouble() ?? 0,
      allAvailable: json['all_available'] as bool? ?? false,
      picks: picks
          .map((e) => BundlePickModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      missingSlots: missing.map((e) => e.toString()).toList(),
      sellerBreakdown: breakdown
          .map((e) => BundleSellerBreakdownModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
