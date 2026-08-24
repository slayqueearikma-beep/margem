class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.accountType,
    required this.displayName,
    this.profilePhotoUrl = '',
    this.hasSellerProfile = false,
    this.legalAcceptanceComplete = true,
    this.pendingLegalPolicies = const [],
  });

  final String id;
  final String email;
  final String accountType;
  final String displayName;
  final String profilePhotoUrl;
  final bool hasSellerProfile;
  final bool legalAcceptanceComplete;
  final List<String> pendingLegalPolicies;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      accountType: json['account_type'] as String,
      displayName: json['display_name'] as String? ?? '',
      profilePhotoUrl: json['profile_photo_url'] as String? ?? '',
      hasSellerProfile: json['has_seller_profile'] as bool? ?? false,
      legalAcceptanceComplete:
          json['legal_acceptance_complete'] as bool? ?? false,
      pendingLegalPolicies:
          (json['pending_legal_policies'] as List<dynamic>? ?? const [])
              .map((item) => item as String)
              .toList(),
    );
  }

  bool get isBuyer =>
      accountType == 'customer' || accountType == 'buyer' || !hasSellerProfile;
  bool get isSeller =>
      accountType == 'provider' || accountType == 'seller' || hasSellerProfile;
  bool get canSell =>
      hasSellerProfile ||
      accountType == 'provider' ||
      accountType == 'seller';
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.expiresIn = 3600,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;
  final int expiresIn;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int? ?? 3600,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class AuthDeviceSession {
  const AuthDeviceSession({
    required this.id,
    required this.deviceName,
    required this.ipAddress,
    required this.userAgent,
    required this.createdAt,
    required this.lastSeenAt,
    required this.current,
  });

  final String id;
  final String deviceName;
  final String ipAddress;
  final String userAgent;
  final String createdAt;
  final String? lastSeenAt;
  final bool current;

  factory AuthDeviceSession.fromJson(Map<String, dynamic> json) {
    return AuthDeviceSession(
      id: json['id'] as String,
      deviceName: json['device_name'] as String? ?? 'Device',
      ipAddress: json['ip_address'] as String? ?? '',
      userAgent: json['user_agent'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      lastSeenAt: json['last_seen_at'] as String?,
      current: json['current'] as bool? ?? false,
    );
  }
}

class SellerCreatePayload {
  const SellerCreatePayload({
    required this.businessName,
    required this.description,
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.phone,
    this.coverImageUrl = '',
    this.logoImageUrl = '',
    this.openingHours,
    this.categoryIds = const [],
    this.marketplaceSlug,
    this.marketZone = '',
    this.marketStreet = '',
    this.marketGallery = '',
    this.shopNumber = '',
    this.marketFloor = '',
    this.nearbyLandmark = '',
    this.sellerTermsAcknowledged = false,
    this.acceptanceLanguage = 'fr',
  });

  final String businessName;
  final String description;
  final String address;
  final String city;
  final double latitude;
  final double longitude;
  final String phone;
  final String coverImageUrl;
  final String logoImageUrl;
  final Map<String, dynamic>? openingHours;
  final List<String> categoryIds;
  final String? marketplaceSlug;
  final String marketZone;
  final String marketStreet;
  final String marketGallery;
  final String shopNumber;
  final String marketFloor;
  final String nearbyLandmark;
  final bool sellerTermsAcknowledged;
  final String acceptanceLanguage;

  Map<String, dynamic> toJson() => {
        'business_name': businessName,
        'description': description,
        'address': address,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
        'phone': phone,
        'cover_image_url': coverImageUrl,
        'logo_image_url': logoImageUrl,
        if (openingHours != null) 'opening_hours': openingHours,
        'category_ids': categoryIds,
        if (marketplaceSlug != null && marketplaceSlug!.isNotEmpty)
          'marketplace_slug': marketplaceSlug,
        if (marketZone.isNotEmpty) 'market_zone': marketZone,
        if (marketStreet.isNotEmpty) 'market_street': marketStreet,
        if (marketGallery.isNotEmpty) 'market_gallery': marketGallery,
        if (shopNumber.isNotEmpty) 'shop_number': shopNumber,
        if (marketFloor.isNotEmpty) 'market_floor': marketFloor,
        if (nearbyLandmark.isNotEmpty) 'nearby_landmark': nearbyLandmark,
        'seller_terms_acknowledged': sellerTermsAcknowledged,
        'acceptance_language': acceptanceLanguage,
      };
}

class SellerUpdatePayload {
  const SellerUpdatePayload({
    this.businessName,
    this.description,
    this.address,
    this.city,
    this.latitude,
    this.longitude,
    this.phone,
    this.coverImageUrl,
    this.logoImageUrl,
    this.openingHours,
    this.categoryIds,
    this.marketplaceSlug,
    this.marketZone,
    this.marketStreet,
    this.marketGallery,
    this.shopNumber,
    this.marketFloor,
    this.nearbyLandmark,
    this.isActive,
  });

  final String? businessName;
  final String? description;
  final String? address;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? coverImageUrl;
  final String? logoImageUrl;
  final Map<String, dynamic>? openingHours;
  final List<String>? categoryIds;
  final String? marketplaceSlug;
  final String? marketZone;
  final String? marketStreet;
  final String? marketGallery;
  final String? shopNumber;
  final String? marketFloor;
  final String? nearbyLandmark;
  final bool? isActive;

  Map<String, dynamic> toJson() {
    return {
      if (businessName != null) 'business_name': businessName,
      if (description != null) 'description': description,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (phone != null) 'phone': phone,
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
      if (logoImageUrl != null) 'logo_image_url': logoImageUrl,
      if (openingHours != null) 'opening_hours': openingHours,
      if (categoryIds != null) 'category_ids': categoryIds,
      if (marketplaceSlug != null) 'marketplace_slug': marketplaceSlug,
      if (marketZone != null) 'market_zone': marketZone,
      if (marketStreet != null) 'market_street': marketStreet,
      if (marketGallery != null) 'market_gallery': marketGallery,
      if (shopNumber != null) 'shop_number': shopNumber,
      if (marketFloor != null) 'market_floor': marketFloor,
      if (nearbyLandmark != null) 'nearby_landmark': nearbyLandmark,
      if (isActive != null) 'is_active': isActive,
    };
  }
}

class ProductCreatePayload {
  const ProductCreatePayload({
    required this.name,
    required this.description,
    this.pricingType = 'fixed',
    this.priceMad,
    this.categorySlug = '',
    this.deliveryAvailable = false,
    this.pickupOnly = true,
    this.imageUrl = '',
  });

  final String name;
  final String description;
  final String pricingType;
  final double? priceMad;
  final String categorySlug;
  final bool deliveryAvailable;
  final bool pickupOnly;
  final String imageUrl;

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'pricing_type': pricingType,
        if (pricingType == 'fixed' && priceMad != null) 'price_mad': priceMad,
        if (categorySlug.isNotEmpty) 'category_slug': categorySlug,
        'delivery_available': deliveryAvailable,
        'pickup_only': pickupOnly,
        'image_url': imageUrl,
      };
}

class ProductUpdatePayload {
  const ProductUpdatePayload({
    this.name,
    this.description,
    this.priceMad,
    this.imageUrl,
    this.isAvailable,
    this.clearPrice = false,
  });

  final String? name;
  final String? description;
  final double? priceMad;
  final String? imageUrl;
  final bool? isAvailable;
  final bool clearPrice;

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (clearPrice) 'price_mad': null,
      if (!clearPrice && priceMad != null) 'price_mad': priceMad,
      if (imageUrl != null) 'image_url': imageUrl,
      if (isAvailable != null) 'is_available': isAvailable,
    };
  }
}

class ServiceCreatePayload {
  const ServiceCreatePayload({
    required this.name,
    required this.description,
    required this.pricingModel,
    this.priceMad,
    this.priceMinMad,
    this.priceMaxMad,
    this.imageUrl = '',
    this.isAvailable = true,
  });

  final String name;
  final String description;
  final String pricingModel;
  final double? priceMad;
  final double? priceMinMad;
  final double? priceMaxMad;
  final String imageUrl;
  final bool isAvailable;

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'pricing_model': pricingModel,
        if (priceMad != null) 'price_mad': priceMad,
        if (priceMinMad != null) 'price_min_mad': priceMinMad,
        if (priceMaxMad != null) 'price_max_mad': priceMaxMad,
        'image_url': imageUrl,
        'is_available': isAvailable,
      };
}

class ServiceUpdatePayload {
  const ServiceUpdatePayload({
    this.name,
    this.description,
    this.pricingModel,
    this.priceMad,
    this.priceMinMad,
    this.priceMaxMad,
    this.clearPrice = false,
    this.clearMinPrice = false,
    this.clearMaxPrice = false,
    this.imageUrl,
    this.isAvailable,
  });

  final String? name;
  final String? description;
  final String? pricingModel;
  final double? priceMad;
  final double? priceMinMad;
  final double? priceMaxMad;
  final bool clearPrice;
  final bool clearMinPrice;
  final bool clearMaxPrice;
  final String? imageUrl;
  final bool? isAvailable;

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (pricingModel != null) 'pricing_model': pricingModel,
      if (clearPrice) 'price_mad': null,
      if (!clearPrice && priceMad != null) 'price_mad': priceMad,
      if (clearMinPrice) 'price_min_mad': null,
      if (!clearMinPrice && priceMinMad != null) 'price_min_mad': priceMinMad,
      if (clearMaxPrice) 'price_max_mad': null,
      if (!clearMaxPrice && priceMaxMad != null) 'price_max_mad': priceMaxMad,
      if (imageUrl != null) 'image_url': imageUrl,
      if (isAvailable != null) 'is_available': isAvailable,
    };
  }
}

/// Fundamental marketplace category slugs (API taxonomy).
const sellerCategorySlugMap = <String, String>{
  'clothing': 'clothing',
  'shoes': 'shoes',
  'perfumes': 'perfumes',
  'beauty': 'beauty',
  'electronics': 'electronics',
  'food': 'food',
  'home': 'home',
  'jewelry': 'jewelry',
  'accessories': 'accessories',
  'sports': 'sports',
  'health': 'health',
  'kids': 'kids',
};
