class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.accountType,
    required this.displayName,
    this.hasSellerProfile = false,
  });

  final String id;
  final String email;
  final String accountType;
  final String displayName;
  final bool hasSellerProfile;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      accountType: json['account_type'] as String,
      displayName: json['display_name'] as String? ?? '',
      hasSellerProfile: json['has_seller_profile'] as bool? ?? false,
    );
  }

  bool get isCustomer =>
      accountType == 'customer' || accountType == 'buyer' || !hasSellerProfile;
  bool get isProvider =>
      accountType == 'provider' || accountType == 'seller' || hasSellerProfile;
  bool get canSell =>
      hasSellerProfile ||
      accountType == 'provider' ||
      accountType == 'seller';

  /// Legacy aliases for existing call sites.
  bool get isBuyer => isCustomer;
  bool get isSeller => isProvider;
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
    this.pricingType,
    this.priceMad,
    this.categorySlug,
    this.deliveryAvailable,
    this.pickupOnly,
    this.imageUrl,
    this.isAvailable,
    this.clearPrice = false,
  });

  final String? name;
  final String? description;
  final String? pricingType;
  final double? priceMad;
  final String? categorySlug;
  final bool? deliveryAvailable;
  final bool? pickupOnly;
  final String? imageUrl;
  final bool? isAvailable;
  final bool clearPrice;

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (pricingType != null) 'pricing_type': pricingType,
      if (clearPrice || pricingType == 'offer') 'price_mad': null,
      if (!clearPrice &&
          pricingType != 'offer' &&
          priceMad != null)
        'price_mad': priceMad,
      if (categorySlug != null) 'category_slug': categorySlug,
      if (deliveryAvailable != null) 'delivery_available': deliveryAvailable,
      if (pickupOnly != null) 'pickup_only': pickupOnly,
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
