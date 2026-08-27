import '../../l10n/strings/app_strings.dart';
import 'service_pricing.dart';

enum PricingType { fixed, offer }

PricingType parsePricingType(String? value) {
  if (value == 'offer') return PricingType.offer;
  return PricingType.fixed;
}

class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.slug,
    required this.nameEn,
    this.nameFr = '',
    this.nameAr = '',
    required this.icon,
  });

  final String id;
  final String slug;
  final String nameEn;
  final String nameFr;
  final String nameAr;
  final String icon;

  String localizedName(String languageCode) {
    switch (languageCode) {
      case 'fr':
        return nameFr.isNotEmpty ? nameFr : nameEn;
      case 'ar':
        return nameAr.isNotEmpty ? nameAr : nameEn;
      default:
        return nameEn;
    }
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      slug: json['slug'] as String,
      nameEn: json['name_en'] as String? ?? '',
      nameFr: json['name_fr'] as String? ?? '',
      nameAr: json['name_ar'] as String? ?? '',
      icon: json['icon'] as String? ?? 'store',
    );
  }
}

class MarketplaceVenueModel {
  const MarketplaceVenueModel({
    required this.id,
    required this.slug,
    required this.name,
    this.description = '',
    this.district = '',
    this.city = 'Casablanca',
    this.coverImageUrl = '',
    this.logoImageUrl = '',
    this.displayOrder = 0,
    this.categoryCount = 0,
    this.sellerCount = 0,
    this.knownFor = '',
    this.latitude = 0,
    this.longitude = 0,
  });

  final String id;
  final String slug;
  final String name;
  final String description;
  final String district;
  final String city;
  final String coverImageUrl;
  final String logoImageUrl;
  final int displayOrder;
  final int categoryCount;
  final int sellerCount;
  final String knownFor;
  final double latitude;
  final double longitude;

  /// User-facing marketplace label (slug may differ from display name).
  String get displayName {
    if (slug == '9ri3a' || name == '9ri3a') return 'Al Qurayaa';
    return name;
  }

  factory MarketplaceVenueModel.fromJson(Map<String, dynamic> json) {
    return MarketplaceVenueModel(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      district: json['district'] as String? ?? '',
      city: json['city'] as String? ?? 'Casablanca',
      coverImageUrl: json['cover_image_url'] as String? ?? '',
      logoImageUrl: json['logo_image_url'] as String? ?? '',
      displayOrder: json['display_order'] as int? ?? 0,
      categoryCount: json['category_count'] as int? ?? 0,
      sellerCount: json['seller_count'] as int? ?? 0,
      knownFor: json['known_for'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}

class OpeningHoursModel {
  const OpeningHoursModel({
    this.days = const {},
    this.open = '09:00',
    this.close = '21:00',
  });

  final Map<String, bool> days;
  final String open;
  final String close;

  factory OpeningHoursModel.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const OpeningHoursModel();
    }
    final rawDays = json['days'];
    final days = <String, bool>{};
    if (rawDays is Map) {
      rawDays.forEach((key, value) {
        days[key.toString()] = value == true;
      });
    }
    return OpeningHoursModel(
      days: days,
      open: json['open'] as String? ?? '09:00',
      close: json['close'] as String? ?? '21:00',
    );
  }

  Map<String, dynamic> toJson() => {
        'days': days,
        'open': open,
        'close': close,
      };

  bool get isEmpty => days.isEmpty;
}

class SellerModel {
  const SellerModel({
    required this.id,
    required this.businessName,
    required this.description,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.coverImageUrl,
    required this.achievementStars,
    required this.averageRating,
    required this.reviewCount,
    this.goldenCrowns = 0,
    this.avgProductQuality = 0,
    this.avgCustomerService = 0,
    this.avgCommunication = 0,
    this.avgTrustworthiness = 0,
    this.logoImageUrl = '',
    this.address = '',
    this.phone = '',
    this.websiteUrl = '',
    this.instagramUrl = '',
    this.facebookUrl = '',
    this.tiktokUrl = '',
    this.whatsappNumber = '',
    this.paymentMethods = const [],
    this.deliveryMethods = const [],
    this.serviceAreas = const [],
    this.openingHours = const OpeningHoursModel(),
    this.profileViewCount = 0,
    this.inquiryCount = 0,
    this.favoriteCount = 0,
    this.contactClickCount = 0,
    this.followerCount = 0,
    this.avgResponseMinutes = 0,
    this.isPremium = false,
    this.isSellerPro = false,
    this.isBuyerPlus = false,
    this.verificationStatus = 'unverified',
    this.marketplaceSlug,
    this.marketplaceName,
    this.customMarketplaceName = '',
    this.marketZone = '',
    this.marketStreet = '',
    this.marketGallery = '',
    this.shopNumber = '',
    this.marketFloor = '',
    this.nearbyLandmark = '',
    this.stallLocationSummary = '',
    this.phoneVerified = false,
    this.createdAt,
    this.categories = const [],
    this.products = const [],
    this.services = const [],
    this.userId = '',
  });

  final String id;
  final String userId;
  final String businessName;
  final String description;
  final String city;
  final double latitude;
  final double longitude;
  final String coverImageUrl;
  final String logoImageUrl;
  final int achievementStars;
  final int goldenCrowns;
  final double averageRating;
  final int reviewCount;
  final double avgProductQuality;
  final double avgCustomerService;
  final double avgCommunication;
  final double avgTrustworthiness;
  final String address;
  final String phone;
  final String websiteUrl;
  final String instagramUrl;
  final String facebookUrl;
  final String tiktokUrl;
  final String whatsappNumber;
  final List<String> paymentMethods;
  final List<String> deliveryMethods;
  final List<String> serviceAreas;
  final OpeningHoursModel openingHours;
  final int profileViewCount;
  final int inquiryCount;
  final int favoriteCount;
  final int contactClickCount;
  final int followerCount;
  final int avgResponseMinutes;
  final bool isPremium;
  final bool isSellerPro;
  final bool isBuyerPlus;
  final String verificationStatus;
  final String? marketplaceSlug;
  final String? marketplaceName;
  final String customMarketplaceName;
  final String marketZone;
  final String marketStreet;
  final String marketGallery;
  final String shopNumber;
  final String marketFloor;
  final String nearbyLandmark;
  final String stallLocationSummary;
  final bool phoneVerified;
  final DateTime? createdAt;
  final List<CategoryModel> categories;
  final List<ProductModel> products;
  final List<ServiceModel> services;

  factory SellerModel.fromJson(Map<String, dynamic> json) {
    return SellerModel(
      id: json['id'] as String,
      userId: json['user_id']?.toString() ?? '',
      businessName: json['business_name'] as String,
      description: json['description'] as String? ?? '',
      city: json['city'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      coverImageUrl: json['cover_image_url'] as String? ?? '',
      logoImageUrl: json['logo_image_url'] as String? ?? '',
      achievementStars: json['achievement_stars'] as int? ?? 0,
      goldenCrowns: json['golden_crowns'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      avgProductQuality: (json['avg_product_quality'] as num?)?.toDouble() ?? 0,
      avgCustomerService:
          (json['avg_customer_service'] as num?)?.toDouble() ?? 0,
      avgCommunication: (json['avg_communication'] as num?)?.toDouble() ?? 0,
      avgTrustworthiness:
          (json['avg_trustworthiness'] as num?)?.toDouble() ?? 0,
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      websiteUrl: json['website_url'] as String? ?? '',
      instagramUrl: json['instagram_url'] as String? ?? '',
      facebookUrl: json['facebook_url'] as String? ?? '',
      tiktokUrl: json['tiktok_url'] as String? ?? '',
      whatsappNumber: json['whatsapp_number'] as String? ?? '',
      paymentMethods: (json['payment_methods'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      deliveryMethods: (json['delivery_methods'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      serviceAreas: (json['service_areas'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      openingHours: OpeningHoursModel.fromJson(
        json['opening_hours'] is Map<String, dynamic>
            ? json['opening_hours'] as Map<String, dynamic>
            : null,
      ),
      profileViewCount: json['profile_view_count'] as int? ?? 0,
      inquiryCount: json['inquiry_count'] as int? ?? 0,
      favoriteCount: json['favorite_count'] as int? ?? 0,
      contactClickCount: json['contact_click_count'] as int? ?? 0,
      followerCount: json['follower_count'] as int? ?? 0,
      avgResponseMinutes: json['avg_response_minutes'] as int? ?? 0,
      isPremium: json['is_seller_pro'] as bool? ?? json['is_premium'] as bool? ?? false,
      isSellerPro: json['is_seller_pro'] as bool? ?? json['is_premium'] as bool? ?? false,
      isBuyerPlus: json['is_buyer_plus'] as bool? ?? false,
      verificationStatus:
          json['verification_status'] as String? ?? 'unverified',
      marketplaceSlug: json['marketplace_slug'] as String?,
      marketplaceName: json['marketplace_name'] as String?,
      customMarketplaceName: json['custom_marketplace_name'] as String? ?? '',
      marketZone: json['market_zone'] as String? ?? '',
      marketStreet: json['market_street'] as String? ?? '',
      marketGallery: json['market_gallery'] as String? ?? '',
      shopNumber: json['shop_number'] as String? ?? '',
      marketFloor: json['market_floor'] as String? ?? '',
      nearbyLandmark: json['nearby_landmark'] as String? ?? '',
      stallLocationSummary: json['stall_location_summary'] as String? ?? '',
      phoneVerified: json['phone_verified'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      products: (json['products'] as List<dynamic>? ?? [])
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      services: (json['services'] as List<dynamic>? ?? [])
          .map((e) => ServiceModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SellerDashboardStats {
  const SellerDashboardStats({
    required this.sellerId,
    required this.businessName,
    required this.profileViewCount,
    required this.productCount,
    required this.availableProductCount,
    required this.serviceCount,
    required this.reviewCount,
    required this.averageRating,
    required this.achievementStars,
    required this.recentReviewCount,
    required this.isActive,
    this.goldenCrowns = 0,
    this.inquiryCount = 0,
    this.favoriteCount = 0,
    this.contactClickCount = 0,
    this.avgResponseMinutes = 0,
    this.isPremium = false,
    this.verificationStatus = 'unverified',
  });

  final String sellerId;
  final String businessName;
  final int profileViewCount;
  final int productCount;
  final int availableProductCount;
  final int serviceCount;
  final int reviewCount;
  final double averageRating;
  final int achievementStars;
  final int goldenCrowns;
  final int recentReviewCount;
  final bool isActive;
  final int inquiryCount;
  final int favoriteCount;
  final int contactClickCount;
  final int avgResponseMinutes;
  final bool isPremium;
  final String verificationStatus;

  factory SellerDashboardStats.fromJson(Map<String, dynamic> json) {
    return SellerDashboardStats(
      sellerId: json['seller_id'] as String,
      businessName: json['business_name'] as String,
      profileViewCount: json['profile_view_count'] as int? ?? 0,
      productCount: json['product_count'] as int? ?? 0,
      availableProductCount: json['available_product_count'] as int? ?? 0,
      serviceCount: json['service_count'] as int? ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      achievementStars: json['achievement_stars'] as int? ?? 0,
      goldenCrowns: json['golden_crowns'] as int? ?? 0,
      recentReviewCount: json['recent_review_count'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      inquiryCount: json['inquiry_count'] as int? ?? 0,
      favoriteCount: json['favorite_count'] as int? ?? 0,
      contactClickCount: json['contact_click_count'] as int? ?? 0,
      avgResponseMinutes: json['avg_response_minutes'] as int? ?? 0,
      isPremium: json['is_premium'] as bool? ?? false,
      verificationStatus:
          json['verification_status'] as String? ?? 'unverified',
    );
  }

  String get formattedViews {
    if (profileViewCount >= 1000) {
      final k = profileViewCount / 1000;
      return k >= 10 ? '${k.round()}k' : '${k.toStringAsFixed(1)}k';
    }
    return '$profileViewCount';
  }

  String get ratingTrend {
    if (reviewCount == 0) return 'No reviews yet';
    return '${averageRating.toStringAsFixed(1)} avg';
  }
}

class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    this.pricingType = PricingType.fixed,
    this.priceMad,
    this.imageUrl = '',
    this.isAvailable = true,
    this.priceNegotiable = false,
    this.availabilityNote = '',
    this.acceptedPaymentMethods = const [],
    this.deliveryOptions = const [],
    this.mediaUrls = const [],
    this.videoUrl = '',
    this.categorySlug = '',
    this.deliveryAvailable = false,
    this.pickupOnly = true,
    this.stockQuantity = 1,
    this.isFeatured = false,
    this.isPaused = false,
  });

  final String id;
  final String name;
  final String description;
  final PricingType pricingType;
  final double? priceMad;
  final String imageUrl;
  final bool isAvailable;
  final bool priceNegotiable;
  final String availabilityNote;
  final List<String> acceptedPaymentMethods;
  final List<String> deliveryOptions;
  final List<String> mediaUrls;
  final String videoUrl;
  final String categorySlug;
  final bool deliveryAvailable;
  final bool pickupOnly;
  final int stockQuantity;
  final bool isFeatured;
  final bool isPaused;

  bool get isOffer => pricingType == PricingType.offer;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      pricingType: parsePricingType(json['pricing_type'] as String?),
      priceMad: (json['price_mad'] as num?)?.toDouble(),
      imageUrl: json['image_url'] as String? ?? '',
      isAvailable: json['is_available'] as bool? ?? true,
      priceNegotiable: json['price_negotiable'] as bool? ?? false,
      availabilityNote: json['availability_note'] as String? ?? '',
      acceptedPaymentMethods:
          (json['accepted_payment_methods'] as List<dynamic>? ?? [])
              .map((item) => item.toString())
              .toList(),
      deliveryOptions: (json['delivery_options'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      mediaUrls: (json['media_urls'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      videoUrl: json['video_url'] as String? ?? '',
      categorySlug: json['category_slug'] as String? ?? '',
      deliveryAvailable: json['delivery_available'] as bool? ?? false,
      pickupOnly: json['pickup_only'] as bool? ?? true,
      stockQuantity: json['stock_quantity'] as int? ?? 1,
      isFeatured: json['is_featured'] as bool? ?? false,
      isPaused: json['is_paused'] as bool? ?? false,
    );
  }
}

class SearchProductModel {
  const SearchProductModel({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.sellerCity,
    required this.sellerVerified,
    required this.sellerPremium,
    required this.sellerRating,
    required this.name,
    required this.description,
    this.pricingType = PricingType.fixed,
    required this.priceMad,
    required this.imageUrl,
    required this.isAvailable,
    this.categorySlug = '',
    this.deliveryAvailable = false,
    this.pickupOnly = true,
  });

  final String id;
  final String sellerId;
  final String sellerName;
  final String sellerCity;
  final bool sellerVerified;
  final bool sellerPremium;
  final double sellerRating;
  final String name;
  final String description;
  final PricingType pricingType;
  final double? priceMad;
  final String imageUrl;
  final bool isAvailable;
  final String categorySlug;
  final bool deliveryAvailable;
  final bool pickupOnly;

  bool get isOffer => pricingType == PricingType.offer;

  factory SearchProductModel.fromJson(Map<String, dynamic> json) {
    return SearchProductModel(
      id: json['id'] as String,
      sellerId: json['seller_id'] as String,
      sellerName: json['seller_name'] as String? ?? '',
      sellerCity: json['seller_city'] as String? ?? '',
      sellerVerified: json['seller_verified'] as bool? ?? false,
      sellerPremium: json['seller_premium'] as bool? ?? false,
      sellerRating: (json['seller_rating'] as num?)?.toDouble() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      pricingType: parsePricingType(json['pricing_type'] as String?),
      priceMad: (json['price_mad'] as num?)?.toDouble(),
      imageUrl: json['image_url'] as String? ?? '',
      isAvailable: json['is_available'] as bool? ?? true,
      categorySlug: json['category_slug'] as String? ?? '',
      deliveryAvailable: json['delivery_available'] as bool? ?? false,
      pickupOnly: json['pickup_only'] as bool? ?? true,
    );
  }
}

class SearchServiceModel {
  const SearchServiceModel({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.sellerCity,
    required this.sellerVerified,
    required this.sellerPremium,
    required this.sellerRating,
    required this.name,
    required this.description,
    this.pricingType = PricingType.fixed,
    required this.priceMad,
    required this.imageUrl,
    required this.isAvailable,
    this.categorySlug = '',
  });

  final String id;
  final String sellerId;
  final String sellerName;
  final String sellerCity;
  final bool sellerVerified;
  final bool sellerPremium;
  final double sellerRating;
  final String name;
  final String description;
  final PricingType pricingType;
  final double? priceMad;
  final String imageUrl;
  final bool isAvailable;
  final String categorySlug;

  bool get isOffer => pricingType == PricingType.offer;

  factory SearchServiceModel.fromJson(Map<String, dynamic> json) {
    return SearchServiceModel(
      id: json['id'] as String,
      sellerId: json['seller_id'] as String,
      sellerName: json['seller_name'] as String? ?? '',
      sellerCity: json['seller_city'] as String? ?? '',
      sellerVerified: json['seller_verified'] as bool? ?? false,
      sellerPremium: json['seller_premium'] as bool? ?? false,
      sellerRating: (json['seller_rating'] as num?)?.toDouble() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      pricingType: parsePricingType(json['pricing_type'] as String?),
      priceMad: (json['price_mad'] as num?)?.toDouble(),
      imageUrl: json['image_url'] as String? ?? '',
      isAvailable: json['is_available'] as bool? ?? true,
      categorySlug: json['category_slug'] as String? ?? '',
    );
  }
}

class MarketplaceSearchPage {
  const MarketplaceSearchPage({
    required this.sellers,
    required this.products,
    required this.services,
    required this.totalSellers,
    required this.totalProducts,
    required this.totalServices,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  final List<SellerModel> sellers;
  final List<SearchProductModel> products;
  final List<SearchServiceModel> services;
  final int totalSellers;
  final int totalProducts;
  final int totalServices;
  final int limit;
  final int offset;
  final bool hasMore;

  factory MarketplaceSearchPage.fromJson(Map<String, dynamic> json) {
    return MarketplaceSearchPage(
      sellers: (json['sellers'] as List<dynamic>? ?? [])
          .map((e) => SellerModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      products: (json['products'] as List<dynamic>? ?? [])
          .map((e) => SearchProductModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      services: (json['services'] as List<dynamic>? ?? [])
          .map((e) => SearchServiceModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalSellers: json['total_sellers'] as int? ?? 0,
      totalProducts: json['total_products'] as int? ?? 0,
      totalServices: json['total_services'] as int? ?? 0,
      limit: json['limit'] as int? ?? 20,
      offset: json['offset'] as int? ?? 0,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}

class ServiceModel {
  const ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    this.pricingModel = ServicePricingModel.fixedPrice,
    this.pricingType = PricingType.fixed,
    this.priceMad,
    this.priceMinMad,
    this.priceMaxMad,
    this.priceNegotiable = false,
    this.imageUrl = '',
    this.isAvailable = true,
    this.isFeatured = false,
    this.categorySlug = '',
    this.coverageAreas = const [],
  });

  final String id;
  final String name;
  final String description;
  final ServicePricingModel pricingModel;
  final PricingType pricingType;
  final double? priceMad;
  final double? priceMinMad;
  final double? priceMaxMad;
  final bool priceNegotiable;
  final String imageUrl;
  final bool isAvailable;
  final bool isFeatured;
  final String categorySlug;
  final List<String> coverageAreas;

  bool get isOffer => pricingType == PricingType.offer;

  String displayPrice(AppStrings l10n) => formatServicePrice(
        l10n,
        pricingModel: pricingModel,
        priceMad: priceMad,
        priceMinMad: priceMinMad,
        priceMaxMad: priceMaxMad,
        priceNegotiable: priceNegotiable || isOffer,
      );

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      pricingModel: ServicePricingModel.fromApi(json['pricing_model'] as String?),
      pricingType: parsePricingType(json['pricing_type'] as String?),
      priceMad: (json['price_mad'] as num?)?.toDouble(),
      priceMinMad: (json['price_min_mad'] as num?)?.toDouble(),
      priceMaxMad: (json['price_max_mad'] as num?)?.toDouble(),
      priceNegotiable: json['price_negotiable'] as bool? ?? false,
      imageUrl: json['image_url'] as String? ?? '',
      isAvailable: json['is_available'] as bool? ?? true,
      isFeatured: json['is_featured'] as bool? ?? false,
      categorySlug: json['category_slug'] as String? ?? '',
      coverageAreas: (json['coverage_areas'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.rating,
    required this.overallRating,
    required this.productQuality,
    required this.customerService,
    required this.communication,
    required this.trustworthiness,
    required this.comment,
    required this.buyerDisplayName,
    required this.createdAt,
  });

  final String id;
  final int rating;
  final double overallRating;
  final int productQuality;
  final int customerService;
  final int communication;
  final int trustworthiness;
  final String comment;
  final String buyerDisplayName;
  final String createdAt;

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final productQuality =
        json['product_quality'] as int? ?? json['rating'] as int? ?? 0;
    final customerService = json['customer_service'] as int? ?? productQuality;
    final communication = json['communication'] as int? ?? productQuality;
    final trustworthiness = json['trustworthiness'] as int? ?? productQuality;
    final overall = (json['overall_rating'] as num?)?.toDouble() ??
        ((productQuality + customerService + communication + trustworthiness) /
            4.0);
    return ReviewModel(
      id: json['id'] as String,
      rating: json['rating'] as int? ?? overall.round(),
      overallRating: overall,
      productQuality: productQuality,
      customerService: customerService,
      communication: communication,
      trustworthiness: trustworthiness,
      comment: json['comment'] as String? ?? '',
      buyerDisplayName: json['buyer_display_name'] as String? ?? 'Buyer',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class ReviewEligibilityModel {
  const ReviewEligibilityModel({
    required this.canReview,
    required this.reason,
    required this.hasReviewed,
  });

  final bool canReview;
  final String reason;
  final bool hasReviewed;

  factory ReviewEligibilityModel.fromJson(Map<String, dynamic> json) {
    return ReviewEligibilityModel(
      canReview: json['can_review'] as bool? ?? false,
      reason: json['reason'] as String? ?? 'unknown',
      hasReviewed: json['has_reviewed'] as bool? ?? false,
    );
  }
}

class SavedSearchModel {
  const SavedSearchModel({
    required this.id,
    required this.query,
    required this.city,
    required this.category,
    this.marketplaceSlug = '',
  });

  final String id;
  final String query;
  final String city;
  final String category;
  final String marketplaceSlug;

  factory SavedSearchModel.fromJson(Map<String, dynamic> json) {
    return SavedSearchModel(
      id: json['id'] as String,
      query: json['query'] as String? ?? '',
      city: json['city'] as String? ?? '',
      category: json['category'] as String? ?? '',
      marketplaceSlug: json['marketplace_slug'] as String? ?? '',
    );
  }
}

class MapPinModel {
  const MapPinModel({
    required this.id,
    required this.businessName,
    required this.latitude,
    required this.longitude,
    required this.achievementStars,
    required this.averageRating,
    required this.categorySlugs,
    this.goldenCrowns = 0,
    this.marketplaceSlug,
    this.marketZone = '',
    this.marketStreet = '',
    this.marketGallery = '',
    this.shopNumber = '',
    this.stallLocationSummary = '',
    this.isSellerPro = false,
  });

  final String id;
  final String businessName;
  final double latitude;
  final double longitude;
  final int achievementStars;
  final int goldenCrowns;
  final double averageRating;
  final List<String> categorySlugs;
  final String? marketplaceSlug;
  final String marketZone;
  final String marketStreet;
  final String marketGallery;
  final String shopNumber;
  final String stallLocationSummary;
  final bool isSellerPro;

  String get zoneLabel {
    if (marketZone.isNotEmpty) return marketZone;
    if (marketGallery.isNotEmpty) return marketGallery;
    if (marketStreet.isNotEmpty) return marketStreet;
    return '';
  }

  factory MapPinModel.fromJson(Map<String, dynamic> json) {
    return MapPinModel(
      id: json['id'] as String,
      businessName: json['business_name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      achievementStars: json['achievement_stars'] as int? ?? 0,
      goldenCrowns: json['golden_crowns'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      categorySlugs: (json['category_slugs'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      marketplaceSlug: json['marketplace_slug'] as String?,
      marketZone: json['market_zone'] as String? ?? '',
      marketStreet: json['market_street'] as String? ?? '',
      marketGallery: json['market_gallery'] as String? ?? '',
      shopNumber: json['shop_number'] as String? ?? '',
      stallLocationSummary: json['stall_location_summary'] as String? ?? '',
      isSellerPro: json['is_seller_pro'] as bool? ?? false,
    );
  }
}

class WarningZoneModel {
  const WarningZoneModel({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  factory WarningZoneModel.fromJson(Map<String, dynamic> json) {
    return WarningZoneModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: (json['radius_meters'] as num?)?.toDouble() ?? 200,
    );
  }
}

class FavoriteItemModel {
  const FavoriteItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.imageUrl,
    required this.priceMad,
    required this.sellerId,
    required this.sellerName,
  });

  final String id;
  final String productId;
  final String productName;
  final String imageUrl;
  final double? priceMad;
  final String sellerId;
  final String sellerName;

  factory FavoriteItemModel.fromJson(Map<String, dynamic> json) {
    return FavoriteItemModel(
      id: json['id'] as String,
      productId: json['product_id'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      priceMad: (json['price_mad'] as num?)?.toDouble(),
      sellerId: json['seller_id'] as String? ?? '',
      sellerName: json['seller_name'] as String? ?? '',
    );
  }
}

class SellerFollowModel {
  const SellerFollowModel({
    required this.id,
    required this.sellerId,
    required this.businessName,
    required this.city,
    this.logoImageUrl = '',
    this.averageRating = 0,
    this.isPremium = false,
    this.verificationStatus = 'unverified',
  });

  final String id;
  final String sellerId;
  final String businessName;
  final String city;
  final String logoImageUrl;
  final double averageRating;
  final bool isPremium;
  final String verificationStatus;

  factory SellerFollowModel.fromJson(Map<String, dynamic> json) {
    return SellerFollowModel(
      id: json['id'] as String,
      sellerId: json['seller_id'] as String,
      businessName: json['business_name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      logoImageUrl: json['logo_image_url'] as String? ?? '',
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      isPremium: json['is_premium'] as bool? ?? false,
      verificationStatus:
          json['verification_status'] as String? ?? 'unverified',
    );
  }
}

class AppNotificationModel {
  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.data,
    required this.readAt,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String kind;
  final Map<String, dynamic> data;
  final String? readAt;
  final String createdAt;

  bool get isRead => readAt != null && readAt!.isNotEmpty;

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : const {},
      readAt: json['read_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class SubscriptionPlanModel {
  const SubscriptionPlanModel({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.priceMad,
    required this.billingPeriodDays,
    required this.features,
    required this.isActive,
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final double priceMad;
  final int billingPeriodDays;
  final List<String> features;
  final bool isActive;

  /// User-facing plan label (legacy API rows may still use older names).
  String get displayName {
    if (code == 'buyer_premium') return 'Dribex Plus+';
    if (code == 'seller_pro') return 'DriverPro';
    return name;
  }

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      priceMad: (json['price_mad'] as num?)?.toDouble() ?? 0,
      billingPeriodDays: json['billing_period_days'] as int? ?? 30,
      features: (json['features'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class SubscriptionModel {
  const SubscriptionModel({
    required this.id,
    required this.plan,
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.provider,
    this.cancelledAt,
    this.cancelAtPeriodEnd = false,
  });

  final String id;
  final SubscriptionPlanModel plan;
  final String status;
  final String currentPeriodStart;
  final String currentPeriodEnd;
  final String provider;
  final String? cancelledAt;
  final bool cancelAtPeriodEnd;

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] as String,
      plan:
          SubscriptionPlanModel.fromJson(json['plan'] as Map<String, dynamic>),
      status: json['status'] as String? ?? '',
      currentPeriodStart: json['current_period_start'] as String? ?? '',
      currentPeriodEnd: json['current_period_end'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      cancelledAt: json['cancelled_at'] as String?,
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
    );
  }
}

class BillingStatusModel {
  const BillingStatusModel({
    required this.selfServeEnabled,
    this.provider,
  });

  final bool selfServeEnabled;
  final String? provider;

  factory BillingStatusModel.fromJson(Map<String, dynamic> json) {
    return BillingStatusModel(
      selfServeEnabled: json['self_serve_enabled'] as bool? ?? false,
      provider: json['provider'] as String?,
    );
  }
}

class BillingCheckoutResult {
  const BillingCheckoutResult({
    this.checkoutUrl,
    this.activated = false,
    this.paymentId,
    this.provider,
    this.subscription,
  });

  final String? checkoutUrl;
  final bool activated;
  final String? paymentId;
  final String? provider;
  final SubscriptionModel? subscription;

  factory BillingCheckoutResult.fromJson(Map<String, dynamic> json) {
    return BillingCheckoutResult(
      checkoutUrl: json['checkout_url'] as String?,
      activated: json['activated'] as bool? ?? false,
      paymentId: json['payment_id'] as String?,
      provider: json['provider'] as String?,
      subscription: json['subscription'] is Map<String, dynamic>
          ? SubscriptionModel.fromJson(
              json['subscription'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class AdvertisingPackageModel {
  const AdvertisingPackageModel({
    required this.code,
    required this.name,
    required this.description,
    required this.placementType,
    required this.priceMad,
    required this.durationDays,
  });

  final String code;
  final String name;
  final String description;
  final String placementType;
  final double priceMad;
  final int durationDays;

  factory AdvertisingPackageModel.fromJson(Map<String, dynamic> json) {
    return AdvertisingPackageModel(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      placementType: json['placement_type'] as String? ?? '',
      priceMad: (json['price_mad'] as num?)?.toDouble() ?? 0,
      durationDays: json['duration_days'] as int? ?? 0,
    );
  }
}

class PlatformPaymentModel {
  const PlatformPaymentModel({
    required this.id,
    required this.serviceType,
    required this.serviceCode,
    required this.amountMad,
    required this.currency,
    required this.status,
    required this.provider,
    required this.providerReference,
    required this.createdAt,
    this.paidAt,
  });

  final String id;
  final String serviceType;
  final String serviceCode;
  final double amountMad;
  final String currency;
  final String status;
  final String provider;
  final String providerReference;
  final String createdAt;
  final String? paidAt;

  factory PlatformPaymentModel.fromJson(Map<String, dynamic> json) {
    return PlatformPaymentModel(
      id: json['id'] as String,
      serviceType: json['service_type'] as String? ?? '',
      serviceCode: json['service_code'] as String? ?? '',
      amountMad: (json['amount_mad'] as num?)?.toDouble() ?? 0,
      currency: (json['currency'] as String? ?? 'mad').toUpperCase(),
      status: json['status'] as String? ?? 'pending',
      provider: json['provider'] as String? ?? '',
      providerReference: json['provider_reference'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      paidAt: json['paid_at'] as String?,
    );
  }
}

class SellerVideoQuotaModel {
  const SellerVideoQuotaModel({
    required this.isPremium,
    required this.activeVideos,
    this.limit,
    this.remaining,
    this.videoUploadsEnabled = false,
  });

  final bool isPremium;
  final int activeVideos;
  final int? limit;
  final int? remaining;
  final bool videoUploadsEnabled;

  bool get isAtLimit =>
      !videoUploadsEnabled && remaining != null && remaining! <= 0;

  factory SellerVideoQuotaModel.fromJson(Map<String, dynamic> json) {
    return SellerVideoQuotaModel(
      isPremium: json['is_premium'] as bool? ?? false,
      activeVideos: json['active_videos'] as int? ?? 0,
      limit: json['limit'] as int?,
      remaining: json['remaining'] as int?,
      videoUploadsEnabled: json['video_uploads_enabled'] as bool? ?? false,
    );
  }
}

class BuyerEntitlementsModel {
  const BuyerEntitlementsModel({
    this.planCode,
    this.status,
    this.plusPlusActive = false,
    this.showPlusBadge = false,
    this.promotionalAdsSuppressed = false,
    this.startedAt,
    this.expiresAt,
  });

  final String? planCode;
  final String? status;
  final bool plusPlusActive;
  final bool showPlusBadge;
  final bool promotionalAdsSuppressed;
  final String? startedAt;
  final String? expiresAt;

  factory BuyerEntitlementsModel.fromJson(Map<String, dynamic> json) {
    return BuyerEntitlementsModel(
      planCode: json['plan_code'] as String?,
      status: json['status'] as String?,
      plusPlusActive: json['plus_plus_active'] as bool? ?? false,
      showPlusBadge: json['show_plus_badge'] as bool? ?? false,
      promotionalAdsSuppressed:
          json['promotional_ads_suppressed'] as bool? ?? false,
      startedAt: json['started_at'] as String?,
      expiresAt: json['expires_at'] as String?,
    );
  }
}

class SellerEntitlementsModel {
  const SellerEntitlementsModel({
    this.planCode,
    this.status,
    this.driverProActive = false,
    this.combinedListingCount = 0,
    this.combinedListingLimit = 5,
    this.combinedListingRemaining = 5,
    this.videoUploadsEnabled = false,
    this.startedAt,
    this.expiresAt,
  });

  final String? planCode;
  final String? status;
  final bool driverProActive;
  final int combinedListingCount;
  final int combinedListingLimit;
  final int combinedListingRemaining;
  final bool videoUploadsEnabled;
  final String? startedAt;
  final String? expiresAt;

  factory SellerEntitlementsModel.fromJson(Map<String, dynamic> json) {
    return SellerEntitlementsModel(
      planCode: json['plan_code'] as String?,
      status: json['status'] as String?,
      driverProActive: json['driver_pro_active'] as bool? ?? false,
      combinedListingCount: json['combined_listing_count'] as int? ?? 0,
      combinedListingLimit: json['combined_listing_limit'] as int? ?? 5,
      combinedListingRemaining:
          json['combined_listing_remaining'] as int? ?? 5,
      videoUploadsEnabled: json['video_uploads_enabled'] as bool? ?? false,
      startedAt: json['started_at'] as String?,
      expiresAt: json['expires_at'] as String?,
    );
  }
}

class EntitlementsBundleModel {
  const EntitlementsBundleModel({
    required this.buyer,
    this.seller,
  });

  final BuyerEntitlementsModel buyer;
  final SellerEntitlementsModel? seller;

  factory EntitlementsBundleModel.fromJson(Map<String, dynamic> json) {
    return EntitlementsBundleModel(
      buyer: BuyerEntitlementsModel.fromJson(
        json['buyer'] as Map<String, dynamic>? ?? const {},
      ),
      seller: json['seller'] is Map<String, dynamic>
          ? SellerEntitlementsModel.fromJson(
              json['seller'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.lastMessageAt,
    this.peerUserId = '',
    this.peerName = '',
    this.unreadCount = 0,
    this.lastMessagePreview = '',
  });

  final String id;
  final String buyerId;
  final String sellerId;
  final String peerUserId;
  final String lastMessageAt;
  final String peerName;
  final int unreadCount;
  final String lastMessagePreview;

  bool get hasUnread => unreadCount > 0;

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id']?.toString() ?? '',
      buyerId: json['buyer_id']?.toString() ?? '',
      sellerId: json['seller_id']?.toString() ?? '',
      peerUserId: json['peer_user_id']?.toString() ??
          json['buyer_id']?.toString() ??
          '',
      lastMessageAt: json['last_message_at']?.toString() ?? '',
      peerName: json['peer_name'] as String? ?? '',
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      lastMessagePreview: json['last_message_preview'] as String? ?? '',
    );
  }
}

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final String createdAt;
  final String? readAt;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      readAt: json['read_at'] as String?,
    );
  }
}
