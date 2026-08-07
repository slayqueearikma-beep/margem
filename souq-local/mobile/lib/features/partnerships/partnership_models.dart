class PartnerSummaryModel {
  PartnerSummaryModel({
    required this.sellerId,
    required this.businessName,
    this.logoImageUrl = '',
    this.averageRating = 0,
    this.reviewCount = 0,
    this.verificationStatus = 'unverified',
    this.role = 'partner',
    this.trustScore = 0,
  });

  factory PartnerSummaryModel.fromJson(Map<String, dynamic> json) {
    return PartnerSummaryModel(
      sellerId: json['seller_id'] as String,
      businessName: json['business_name'] as String? ?? '',
      logoImageUrl: json['logo_image_url'] as String? ?? '',
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      verificationStatus: json['verification_status'] as String? ?? 'unverified',
      role: json['role'] as String? ?? 'partner',
      trustScore: (json['trust_score'] as num?)?.toDouble() ?? 0,
    );
  }

  final String sellerId;
  final String businessName;
  final String logoImageUrl;
  final double averageRating;
  final int reviewCount;
  final String verificationStatus;
  final String role;
  final double trustScore;
}

class PartnershipTrustModel {
  PartnershipTrustModel({
    this.isVerified = false,
    this.successfulCollaborations = 0,
    this.durationDays = 0,
    this.jointTrustScore = 0,
    this.combinedRating = 0,
  });

  factory PartnershipTrustModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PartnershipTrustModel();
    return PartnershipTrustModel(
      isVerified: json['is_verified'] as bool? ?? false,
      successfulCollaborations: json['successful_collaborations'] as int? ?? 0,
      durationDays: json['duration_days'] as int? ?? 0,
      jointTrustScore: (json['joint_trust_score'] as num?)?.toDouble() ?? 0,
      combinedRating: (json['combined_rating'] as num?)?.toDouble() ?? 0,
    );
  }

  final bool isVerified;
  final int successfulCollaborations;
  final int durationDays;
  final double jointTrustScore;
  final double combinedRating;
}

class PartnershipModel {
  PartnershipModel({
    required this.id,
    required this.name,
    this.description = '',
    this.partnershipType = 'long_term',
    this.marketplaceSlug = '',
    this.categorySlugs = const [],
    this.status = 'pending',
    this.startDate,
    this.endDate,
    this.isVerified = false,
    this.successfulCollaborations = 0,
    this.members = const [],
    this.trust,
    this.myRole,
    this.myPermissions,
  });

  factory PartnershipModel.fromJson(Map<String, dynamic> json) {
    return PartnershipModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      partnershipType: json['partnership_type'] as String? ?? 'long_term',
      marketplaceSlug: json['marketplace_slug'] as String? ?? '',
      categorySlugs: (json['category_slugs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      status: json['status'] as String? ?? 'pending',
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      successfulCollaborations: json['successful_collaborations'] as int? ?? 0,
      members: (json['members'] as List<dynamic>?)
              ?.map((e) => PartnerSummaryModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      trust: PartnershipTrustModel.fromJson(
          json['trust'] as Map<String, dynamic>?),
      myRole: json['my_role'] as String?,
      myPermissions: (json['my_permissions'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v == true)),
    );
  }

  final String id;
  final String name;
  final String description;
  final String partnershipType;
  final String marketplaceSlug;
  final List<String> categorySlugs;
  final String status;
  final String? startDate;
  final String? endDate;
  final bool isVerified;
  final int successfulCollaborations;
  final List<PartnerSummaryModel> members;
  final PartnershipTrustModel? trust;
  final String? myRole;
  final Map<String, bool>? myPermissions;
}

class PublicPartnershipModel {
  PublicPartnershipModel({
    required this.id,
    required this.name,
    this.isVerified = false,
    this.partnershipType = 'long_term',
    this.members = const [],
    this.combinedRating = 0,
    this.jointTrustScore = 0,
  });

  factory PublicPartnershipModel.fromJson(Map<String, dynamic> json) {
    return PublicPartnershipModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      isVerified: json['is_verified'] as bool? ?? false,
      partnershipType: json['partnership_type'] as String? ?? 'long_term',
      members: (json['members'] as List<dynamic>?)
              ?.map((e) => PartnerSummaryModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      combinedRating: (json['combined_rating'] as num?)?.toDouble() ?? 0,
      jointTrustScore: (json['joint_trust_score'] as num?)?.toDouble() ?? 0,
    );
  }

  final String id;
  final String name;
  final bool isVerified;
  final String partnershipType;
  final List<PartnerSummaryModel> members;
  final double combinedRating;
  final double jointTrustScore;
}

class PartnershipInvitationModel {
  PartnershipInvitationModel({
    required this.id,
    required this.partnershipId,
    required this.partnershipName,
    required this.inviterName,
    required this.inviteeName,
    this.message = '',
    this.status = 'pending',
    this.expiresAt,
    this.invitedRole = 'partner',
  });

  factory PartnershipInvitationModel.fromJson(Map<String, dynamic> json) {
    return PartnershipInvitationModel(
      id: json['id'] as String,
      partnershipId: json['partnership_id'] as String,
      partnershipName: json['partnership_name'] as String? ?? '',
      inviterName: json['inviter_name'] as String? ?? '',
      inviteeName: json['invitee_name'] as String? ?? '',
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      expiresAt: json['expires_at'] as String?,
      invitedRole: json['invited_role'] as String? ?? 'partner',
    );
  }

  final String id;
  final String partnershipId;
  final String partnershipName;
  final String inviterName;
  final String inviteeName;
  final String message;
  final String status;
  final String? expiresAt;
  final String invitedRole;
}

class PartnershipAnalyticsModel {
  PartnershipAnalyticsModel({
    this.totalListings = 0,
    this.activeListings = 0,
    this.totalCollaborations = 0,
    this.fulfilledCollaborations = 0,
    this.totalSharedStock = 0,
    this.reservedStock = 0,
    this.revenueRecordsCount = 0,
    this.totalRevenueMad = 0,
    this.chatMessagesCount = 0,
  });

  factory PartnershipAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return PartnershipAnalyticsModel(
      totalListings: json['total_listings'] as int? ?? 0,
      activeListings: json['active_listings'] as int? ?? 0,
      totalCollaborations: json['total_collaborations'] as int? ?? 0,
      fulfilledCollaborations: json['fulfilled_collaborations'] as int? ?? 0,
      totalSharedStock: json['total_shared_stock'] as int? ?? 0,
      reservedStock: json['reserved_stock'] as int? ?? 0,
      revenueRecordsCount: json['revenue_records_count'] as int? ?? 0,
      totalRevenueMad: (json['total_revenue_mad'] as num?)?.toDouble() ?? 0,
      chatMessagesCount: json['chat_messages_count'] as int? ?? 0,
    );
  }

  final int totalListings;
  final int activeListings;
  final int totalCollaborations;
  final int fulfilledCollaborations;
  final int totalSharedStock;
  final int reservedStock;
  final int revenueRecordsCount;
  final double totalRevenueMad;
  final int chatMessagesCount;
}

class PartnershipChatMessageModel {
  PartnershipChatMessageModel({
    required this.id,
    required this.senderUserId,
    this.body = '',
    this.attachmentUrl = '',
    this.taskTitle = '',
    this.createdAt,
  });

  factory PartnershipChatMessageModel.fromJson(Map<String, dynamic> json) {
    return PartnershipChatMessageModel(
      id: json['id'] as String,
      senderUserId: json['sender_user_id'] as String,
      body: json['body'] as String? ?? '',
      attachmentUrl: json['attachment_url'] as String? ?? '',
      taskTitle: json['task_title'] as String? ?? '',
      createdAt: json['created_at'] as String?,
    );
  }

  final String id;
  final String senderUserId;
  final String body;
  final String attachmentUrl;
  final String taskTitle;
  final String? createdAt;
}
