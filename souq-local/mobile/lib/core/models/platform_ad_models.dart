class PlatformAdvertisementModel {
  const PlatformAdvertisementModel({
    required this.id,
    required this.title,
    this.description,
    required this.imageUrl,
    this.videoUrl,
    required this.targetUrl,
    required this.placement,
    required this.clickUrl,
  });

  final String id;
  final String title;
  final String? description;
  final String imageUrl;
  final String? videoUrl;
  final String targetUrl;
  final String placement;
  final String clickUrl;

  factory PlatformAdvertisementModel.fromJson(Map<String, dynamic> json) {
    return PlatformAdvertisementModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String,
      videoUrl: json['video_url'] as String?,
      targetUrl: json['target_url'] as String,
      placement: json['placement'] as String,
      clickUrl: json['click_url'] as String,
    );
  }
}

class PlatformAdContext {
  const PlatformAdContext({
    this.marketplaceSlug,
    this.city,
    this.categorySlug,
    this.listingType,
  });

  final String? marketplaceSlug;
  final String? city;
  final String? categorySlug;
  final String? listingType;

  Map<String, String> toQueryParameters() {
    final params = <String, String>{'platform': 'mobile'};
    if (marketplaceSlug != null && marketplaceSlug!.isNotEmpty) {
      params['marketplace_slug'] = marketplaceSlug!;
    }
    if (city != null && city!.isNotEmpty) params['city'] = city!;
    if (categorySlug != null && categorySlug!.isNotEmpty) {
      params['category_slug'] = categorySlug!;
    }
    if (listingType != null && listingType!.isNotEmpty) {
      params['listing_type'] = listingType!;
    }
    return params;
  }

  Map<String, String?> toImpressionBody() {
    return {
      'marketplace_slug': marketplaceSlug,
      'city': city,
      'category_slug': categorySlug,
      'listing_type': listingType,
    };
  }
}
