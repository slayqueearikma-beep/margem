class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.accountType,
    required this.displayName,
    this.hasSellerProfile = false,
    this.role = 'buyer',
    this.status = 'active',
    this.mfaEnabled = false,
  });

  final String id;
  final String email;
  final String accountType;
  final String displayName;
  final bool hasSellerProfile;
  final String role;
  final String status;
  final bool mfaEnabled;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      accountType: json['account_type'] as String,
      displayName: json['display_name'] as String? ?? '',
      hasSellerProfile: json['has_seller_profile'] as bool? ?? false,
      role: json['role'] as String? ?? 'buyer',
      status: json['status'] as String? ?? 'active',
      mfaEnabled: json['mfa_enabled'] as bool? ?? false,
    );
  }

  bool get isBuyer => accountType == 'buyer' || !hasSellerProfile;
  bool get isSeller => accountType == 'seller' || hasSellerProfile;
  bool get canSell => hasSellerProfile || accountType == 'seller';

  static const staffRoles = {'super_admin', 'admin', 'moderator', 'support'};
  static const adminWriteRoles = {'super_admin', 'admin'};
  static const moderatorRoles = {'super_admin', 'admin', 'moderator'};

  bool get isStaff => staffRoles.contains(role);
  bool get canAdminWrite => adminWriteRoles.contains(role);
  bool get canModerate => moderatorRoles.contains(role);
  bool get isSuperAdmin => role == 'super_admin';
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
    this.priceMad,
    this.imageUrl = '',
  });

  final String name;
  final String description;
  final double? priceMad;
  final String imageUrl;

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        if (priceMad != null) 'price_mad': priceMad,
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
