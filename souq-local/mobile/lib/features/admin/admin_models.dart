/// Data models for the MarGem administration console.
library;
class StaffMe {
  const StaffMe({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.roleLabel,
    required this.permissions,
  });

  final String id;
  final String email;
  final String displayName;
  final String role;
  final String roleLabel;
  final List<String> permissions;

  factory StaffMe.fromJson(Map<String, dynamic> json) {
    return StaffMe(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String? ?? '',
      role: json['role'] as String? ?? 'support',
      roleLabel: json['role_label'] as String? ?? '',
      permissions: (json['permissions'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  bool hasPermission(String key) => permissions.contains(key);
}

class AdminDashboard {
  const AdminDashboard({
    required this.totalUsers,
    required this.activeUsers,
    required this.newUsers7d,
    required this.totalBusinesses,
    required this.verifiedBusinesses,
    required this.pendingVerifications,
    required this.totalListings,
    required this.featuredListings,
    required this.totalCategories,
    required this.totalReviews,
    required this.openReports,
    required this.premiumSubscribers,
    required this.userGrowth30d,
    required this.listingGrowth30d,
    required this.recentActivity,
    required this.systemStatus,
  });

  final int totalUsers;
  final int activeUsers;
  final int newUsers7d;
  final int totalBusinesses;
  final int verifiedBusinesses;
  final int pendingVerifications;
  final int totalListings;
  final int featuredListings;
  final int totalCategories;
  final int totalReviews;
  final int openReports;
  final int premiumSubscribers;
  final List<GrowthPoint> userGrowth30d;
  final List<GrowthPoint> listingGrowth30d;
  final List<ActivityItem> recentActivity;
  final Map<String, String> systemStatus;

  factory AdminDashboard.fromJson(Map<String, dynamic> json) {
    return AdminDashboard(
      totalUsers: json['total_users'] as int? ?? 0,
      activeUsers: json['active_users'] as int? ?? 0,
      newUsers7d: json['new_users_7d'] as int? ?? 0,
      totalBusinesses: json['total_businesses'] as int? ?? 0,
      verifiedBusinesses: json['verified_businesses'] as int? ?? 0,
      pendingVerifications: json['pending_verifications'] as int? ?? 0,
      totalListings: json['total_listings'] as int? ?? 0,
      featuredListings: json['featured_listings'] as int? ?? 0,
      totalCategories: json['total_categories'] as int? ?? 0,
      totalReviews: json['total_reviews'] as int? ?? 0,
      openReports: json['open_reports'] as int? ?? 0,
      premiumSubscribers: json['premium_subscribers'] as int? ?? 0,
      userGrowth30d: (json['user_growth_30d'] as List<dynamic>? ?? [])
          .map((e) => GrowthPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      listingGrowth30d: (json['listing_growth_30d'] as List<dynamic>? ?? [])
          .map((e) => GrowthPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentActivity: (json['recent_activity'] as List<dynamic>? ?? [])
          .map((e) => ActivityItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      systemStatus: (json['system_status'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v.toString())),
    );
  }
}

class GrowthPoint {
  const GrowthPoint({required this.date, required this.count});

  final String date;
  final int count;

  factory GrowthPoint.fromJson(Map<String, dynamic> json) {
    return GrowthPoint(
      date: json['date'] as String? ?? json['month'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

class ActivityItem {
  const ActivityItem({
    required this.type,
    required this.id,
    required this.at,
    required this.label,
  });

  final String type;
  final String id;
  final String at;
  final String label;

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      type: json['type'] as String? ?? '',
      id: json['id'] as String? ?? '',
      at: json['at'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

class AdminUserSummary {
  const AdminUserSummary({
    required this.id,
    required this.email,
    required this.displayName,
    required this.accountType,
    required this.role,
    required this.status,
    required this.isPremium,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String accountType;
  final String role;
  final String status;
  final bool isPremium;
  final String createdAt;

  factory AdminUserSummary.fromJson(Map<String, dynamic> json) {
    return AdminUserSummary(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String? ?? '',
      accountType: json['account_type'] as String? ?? 'buyer',
      role: json['role'] as String? ?? 'buyer',
      status: json['status'] as String? ?? 'active',
      isPremium: json['is_premium'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class AdminUserPage {
  const AdminUserPage({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
  });

  final List<AdminUserSummary> items;
  final int total;
  final int offset;
  final int limit;

  factory AdminUserPage.fromJson(Map<String, dynamic> json) {
    return AdminUserPage(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => AdminUserSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      offset: json['offset'] as int? ?? 0,
      limit: json['limit'] as int? ?? 50,
    );
  }
}

class AdminUserDetail extends AdminUserSummary {
  const AdminUserDetail({
    required super.id,
    required super.email,
    required super.displayName,
    required super.accountType,
    required super.role,
    required super.status,
    required super.isPremium,
    required super.createdAt,
    this.phone = '',
    this.lastLoginAt,
    this.emailVerified = false,
  });

  final String phone;
  final String? lastLoginAt;
  final bool emailVerified;

  factory AdminUserDetail.fromJson(Map<String, dynamic> json) {
    return AdminUserDetail(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String? ?? '',
      accountType: json['account_type'] as String? ?? 'buyer',
      role: json['role'] as String? ?? 'buyer',
      status: json['status'] as String? ?? 'active',
      isPremium: json['is_premium'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      lastLoginAt: json['last_login_at'] as String?,
      emailVerified: json['email_verified'] as bool? ?? false,
    );
  }
}

class AdminSellerSummary {
  const AdminSellerSummary({
    required this.id,
    required this.businessName,
    required this.city,
    required this.verificationStatus,
    required this.isActive,
    required this.isPremium,
    required this.userId,
    required this.createdAt,
  });

  final String id;
  final String businessName;
  final String city;
  final String verificationStatus;
  final bool isActive;
  final bool isPremium;
  final String userId;
  final String createdAt;

  factory AdminSellerSummary.fromJson(Map<String, dynamic> json) {
    return AdminSellerSummary(
      id: json['id'] as String,
      businessName: json['business_name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      verificationStatus: json['verification_status'] as String? ?? 'unverified',
      isActive: json['is_active'] as bool? ?? true,
      isPremium: json['is_premium'] as bool? ?? false,
      userId: json['user_id'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class AdminProductSummary {
  const AdminProductSummary({
    required this.id,
    required this.name,
    required this.sellerId,
    required this.categorySlug,
    required this.isHidden,
    required this.isFeatured,
    required this.isPaused,
    required this.isAvailable,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String sellerId;
  final String categorySlug;
  final bool isHidden;
  final bool isFeatured;
  final bool isPaused;
  final bool isAvailable;
  final String createdAt;

  factory AdminProductSummary.fromJson(Map<String, dynamic> json) {
    return AdminProductSummary(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      sellerId: json['seller_id'] as String? ?? '',
      categorySlug: json['category_slug'] as String? ?? '',
      isHidden: json['is_hidden'] as bool? ?? false,
      isFeatured: json['is_featured'] as bool? ?? false,
      isPaused: json['is_paused'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? true,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class AdminReportSummary {
  const AdminReportSummary({
    required this.id,
    required this.reason,
    required this.details,
    required this.status,
    required this.sellerId,
    required this.productId,
    required this.reporterId,
    required this.createdAt,
  });

  final String id;
  final String reason;
  final String details;
  final String status;
  final String? sellerId;
  final String? productId;
  final String? reporterId;
  final String createdAt;

  factory AdminReportSummary.fromJson(Map<String, dynamic> json) {
    return AdminReportSummary(
      id: json['id'] as String,
      reason: json['reason'] as String? ?? '',
      details: json['details'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      sellerId: json['seller_id'] as String?,
      productId: json['product_id'] as String?,
      reporterId: json['reporter_id'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class AdminCategoryItem {
  const AdminCategoryItem({
    required this.id,
    required this.slug,
    required this.nameEn,
    required this.nameFr,
    required this.nameAr,
    required this.icon,
    required this.accentColor,
    required this.sortOrder,
  });

  final String id;
  final String slug;
  final String nameEn;
  final String nameFr;
  final String nameAr;
  final String icon;
  final String accentColor;
  final int sortOrder;

  factory AdminCategoryItem.fromJson(Map<String, dynamic> json) {
    return AdminCategoryItem(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      nameFr: json['name_fr'] as String? ?? '',
      nameAr: json['name_ar'] as String? ?? '',
      icon: json['icon'] as String? ?? 'store',
      accentColor: json['accent_color'] as String? ?? '#5B6CFF',
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

class AdminAnalytics {
  const AdminAnalytics({
    required this.userGrowth,
    required this.businessGrowth,
    required this.popularCategories,
    required this.dailyActiveUsers,
    required this.monthlyActiveUsers,
    required this.geographicDistribution,
    required this.searchEvents7d,
  });

  final List<GrowthPoint> userGrowth;
  final List<GrowthPoint> businessGrowth;
  final List<Map<String, dynamic>> popularCategories;
  final int dailyActiveUsers;
  final int monthlyActiveUsers;
  final List<Map<String, dynamic>> geographicDistribution;
  final int searchEvents7d;

  factory AdminAnalytics.fromJson(Map<String, dynamic> json) {
    return AdminAnalytics(
      userGrowth: (json['user_growth'] as List<dynamic>? ?? [])
          .map((e) => GrowthPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      businessGrowth: (json['business_growth'] as List<dynamic>? ?? [])
          .map((e) => GrowthPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      popularCategories: (json['popular_categories'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      dailyActiveUsers: json['daily_active_users'] as int? ?? 0,
      monthlyActiveUsers: json['monthly_active_users'] as int? ?? 0,
      geographicDistribution:
          (json['geographic_distribution'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
      searchEvents7d: json['search_events_7d'] as int? ?? 0,
    );
  }
}

class AdminAuditEntry {
  const AdminAuditEntry({
    required this.id,
    required this.actorId,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.ipAddress,
    required this.success,
    required this.createdAt,
    this.previousValue,
    this.newValue,
    this.metadata = const {},
  });

  final String id;
  final String actorId;
  final String action;
  final String targetType;
  final String targetId;
  final String ipAddress;
  final bool success;
  final String createdAt;
  final Map<String, dynamic>? previousValue;
  final Map<String, dynamic>? newValue;
  final Map<String, dynamic> metadata;

  factory AdminAuditEntry.fromJson(Map<String, dynamic> json) {
    return AdminAuditEntry(
      id: json['id'] as String,
      actorId: json['actor_id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      targetType: json['target_type'] as String? ?? '',
      targetId: json['target_id'] as String? ?? '',
      ipAddress: json['ip_address'] as String? ?? '',
      success: json['success'] as bool? ?? true,
      createdAt: json['created_at'] as String? ?? '',
      previousValue: json['previous_value'] is Map<String, dynamic>
          ? json['previous_value'] as Map<String, dynamic>
          : null,
      newValue: json['new_value'] is Map<String, dynamic>
          ? json['new_value'] as Map<String, dynamic>
          : null,
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : const {},
    );
  }
}

class AdminSessionInfo {
  const AdminSessionInfo({
    required this.id,
    required this.deviceName,
    required this.ipAddress,
    required this.userAgent,
    required this.createdAt,
    required this.revoked,
    this.lastSeenAt,
  });

  final String id;
  final String deviceName;
  final String ipAddress;
  final String userAgent;
  final String createdAt;
  final String? lastSeenAt;
  final bool revoked;

  factory AdminSessionInfo.fromJson(Map<String, dynamic> json) {
    return AdminSessionInfo(
      id: json['id'] as String,
      deviceName: json['device_name'] as String? ?? 'Device',
      ipAddress: json['ip_address'] as String? ?? '',
      userAgent: json['user_agent'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      lastSeenAt: json['last_seen_at'] as String?,
      revoked: json['revoked'] as bool? ?? false,
    );
  }
}

class AdminSellerPage {
  const AdminSellerPage({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
  });

  final List<AdminSellerSummary> items;
  final int total;
  final int offset;
  final int limit;

  factory AdminSellerPage.fromJson(
    Map<String, dynamic> json,
    List<AdminSellerSummary> Function(List<dynamic>) parseItems,
  ) {
    return AdminSellerPage(
      items: parseItems(json['items'] as List<dynamic>? ?? []),
      total: json['total'] as int? ?? 0,
      offset: json['offset'] as int? ?? 0,
      limit: json['limit'] as int? ?? 50,
    );
  }
}

class AdminProductPage {
  const AdminProductPage({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
  });

  final List<AdminProductSummary> items;
  final int total;
  final int offset;
  final int limit;

  factory AdminProductPage.fromJson(Map<String, dynamic> json) {
    return AdminProductPage(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => AdminProductSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      offset: json['offset'] as int? ?? 0,
      limit: json['limit'] as int? ?? 50,
    );
  }
}

class AdminReportPage {
  const AdminReportPage({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
  });

  final List<AdminReportSummary> items;
  final int total;
  final int offset;
  final int limit;

  factory AdminReportPage.fromJson(Map<String, dynamic> json) {
    return AdminReportPage(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => AdminReportSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      offset: json['offset'] as int? ?? 0,
      limit: json['limit'] as int? ?? 50,
    );
  }
}

class AdminAuditPage {
  const AdminAuditPage({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
  });

  final List<AdminAuditEntry> items;
  final int total;
  final int offset;
  final int limit;

  factory AdminAuditPage.fromJson(Map<String, dynamic> json) {
    return AdminAuditPage(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => AdminAuditEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      offset: json['offset'] as int? ?? 0,
      limit: json['limit'] as int? ?? 50,
    );
  }
}
