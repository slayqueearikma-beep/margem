class CommunityCityModel {
  const CommunityCityModel({
    required this.id,
    required this.slug,
    required this.name,
    this.description = '',
    this.isActive = true,
    this.memberCount = 0,
    this.messageCount = 0,
    this.onlineCount = 0,
    this.isMember = false,
    this.isHomeCity = false,
  });

  final String id;
  final String slug;
  final String name;
  final String description;
  final bool isActive;
  final int memberCount;
  final int messageCount;
  final int onlineCount;
  final bool isMember;
  final bool isHomeCity;

  factory CommunityCityModel.fromJson(Map<String, dynamic> json) {
    return CommunityCityModel(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      memberCount: json['member_count'] as int? ?? 0,
      messageCount: json['message_count'] as int? ?? 0,
      onlineCount: json['online_count'] as int? ?? 0,
      isMember: json['is_member'] as bool? ?? false,
      isHomeCity: json['is_home_city'] as bool? ?? false,
    );
  }
}

class CommunityChannelModel {
  const CommunityChannelModel({
    required this.id,
    required this.cityId,
    required this.category,
    required this.name,
    this.description = '',
    this.messageCount = 0,
    this.unreadCount = 0,
    this.isActive = true,
  });

  final String id;
  final String cityId;
  final String category;
  final String name;
  final String description;
  final int messageCount;
  final int unreadCount;
  final bool isActive;

  factory CommunityChannelModel.fromJson(Map<String, dynamic> json) {
    return CommunityChannelModel(
      id: json['id'] as String,
      cityId: json['city_id'] as String,
      category: json['category'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      messageCount: json['message_count'] as int? ?? 0,
      unreadCount: json['unread_count'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class CommunitySenderModel {
  const CommunitySenderModel({
    required this.id,
    required this.displayName,
    this.avatarUrl = '',
    this.role = 'buyer',
    this.isPremium = false,
    this.showPlusBadge = false,
    this.isVerified = false,
    this.trustScore = 0,
    this.badges = const [],
  });

  final String id;
  final String displayName;
  final String avatarUrl;
  final String role;
  final bool isPremium;
  final bool showPlusBadge;
  final bool isVerified;
  final int trustScore;
  final List<String> badges;

  factory CommunitySenderModel.fromJson(Map<String, dynamic> json) {
    return CommunitySenderModel(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'User',
      avatarUrl: json['avatar_url'] as String? ?? '',
      role: json['role'] as String? ?? 'buyer',
      isPremium: json['is_premium'] as bool? ?? false,
      showPlusBadge:
          json['show_plus_badge'] as bool? ?? json['is_premium'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? false,
      trustScore: json['trust_score'] as int? ?? 0,
      badges: (json['badges'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class CommunityReactionModel {
  const CommunityReactionModel({
    required this.emoji,
    required this.count,
    this.reactedByMe = false,
  });

  final String emoji;
  final int count;
  final bool reactedByMe;

  factory CommunityReactionModel.fromJson(Map<String, dynamic> json) {
    return CommunityReactionModel(
      emoji: json['emoji'] as String,
      count: json['count'] as int? ?? 0,
      reactedByMe: json['reacted_by_me'] as bool? ?? false,
    );
  }
}

class CommunityMessageModel {
  const CommunityMessageModel({
    required this.id,
    required this.channelId,
    required this.sender,
    required this.body,
    this.replyToId,
    this.threadRootId,
    this.threadReplyCount = 0,
    this.attachments = const [],
    this.mentions = const [],
    this.hashtags = const [],
    this.language = '',
    this.status = 'visible',
    this.isPinned = false,
    this.isEdited = false,
    this.reactions = const [],
    required this.createdAt,
    this.editedAt,
  });

  final String id;
  final String channelId;
  final CommunitySenderModel sender;
  final String body;
  final String? replyToId;
  final String? threadRootId;
  final int threadReplyCount;
  final List<Map<String, dynamic>> attachments;
  final List<String> mentions;
  final List<String> hashtags;
  final String language;
  final String status;
  final bool isPinned;
  final bool isEdited;
  final List<CommunityReactionModel> reactions;
  final DateTime createdAt;
  final DateTime? editedAt;

  factory CommunityMessageModel.fromJson(Map<String, dynamic> json) {
    return CommunityMessageModel(
      id: json['id'] as String,
      channelId: json['channel_id'] as String,
      sender: CommunitySenderModel.fromJson(
        json['sender'] as Map<String, dynamic>,
      ),
      body: json['body'] as String? ?? '',
      replyToId: json['reply_to_id'] as String?,
      threadRootId: json['thread_root_id'] as String?,
      threadReplyCount: json['thread_reply_count'] as int? ?? 0,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      mentions: (json['mentions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      hashtags: (json['hashtags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      language: json['language'] as String? ?? '',
      status: json['status'] as String? ?? 'visible',
      isPinned: json['is_pinned'] as bool? ?? false,
      isEdited: json['is_edited'] as bool? ?? false,
      reactions: (json['reactions'] as List<dynamic>?)
              ?.map((e) =>
                  CommunityReactionModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['created_at'] as String),
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String)
          : null,
    );
  }
}

class CommunityDiscoverModel {
  const CommunityDiscoverModel({
    this.trending = const [],
    this.mostActive = const [],
    this.fastestGrowing = const [],
  });

  final List<CommunityCityModel> trending;
  final List<CommunityCityModel> mostActive;
  final List<CommunityCityModel> fastestGrowing;

  factory CommunityDiscoverModel.fromJson(Map<String, dynamic> json) {
    List<CommunityCityModel> parseList(dynamic value) {
      return (value as List<dynamic>?)
              ?.map((e) =>
                  CommunityCityModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [];
    }

    return CommunityDiscoverModel(
      trending: parseList(json['trending']),
      mostActive: parseList(json['most_active']),
      fastestGrowing: parseList(json['fastest_growing']),
    );
  }
}
