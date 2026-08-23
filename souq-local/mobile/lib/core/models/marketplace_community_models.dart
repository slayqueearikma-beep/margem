class MarketplaceCommunityHubModel {
  const MarketplaceCommunityHubModel({
    required this.marketplaceId,
    required this.marketplaceSlug,
    required this.marketplaceName,
    this.memberCount = 0,
    this.messageCount = 0,
    this.onlineCount = 0,
    this.isMember = false,
  });

  final String marketplaceId;
  final String marketplaceSlug;
  final String marketplaceName;
  final int memberCount;
  final int messageCount;
  final int onlineCount;
  final bool isMember;

  factory MarketplaceCommunityHubModel.fromJson(Map<String, dynamic> json) {
    return MarketplaceCommunityHubModel(
      marketplaceId: json['marketplace_id'] as String,
      marketplaceSlug: json['marketplace_slug'] as String,
      marketplaceName: json['marketplace_name'] as String? ?? '',
      memberCount: json['member_count'] as int? ?? 0,
      messageCount: json['message_count'] as int? ?? 0,
      onlineCount: json['online_count'] as int? ?? 0,
      isMember: json['is_member'] as bool? ?? false,
    );
  }
}

class MarketplaceCommunityChannelModel {
  const MarketplaceCommunityChannelModel({
    required this.id,
    required this.marketplaceId,
    required this.slug,
    required this.name,
    this.description = '',
    this.defaultPostType = 'general',
    this.messageCount = 0,
  });

  final String id;
  final String marketplaceId;
  final String slug;
  final String name;
  final String description;
  final String defaultPostType;
  final int messageCount;

  factory MarketplaceCommunityChannelModel.fromJson(Map<String, dynamic> json) {
    return MarketplaceCommunityChannelModel(
      id: json['id'] as String,
      marketplaceId: json['marketplace_id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      defaultPostType: json['default_post_type'] as String? ?? 'general',
      messageCount: json['message_count'] as int? ?? 0,
    );
  }
}

class MarketplaceCommunityMessageModel {
  const MarketplaceCommunityMessageModel({
    required this.id,
    required this.channelId,
    required this.senderName,
    required this.senderId,
    required this.body,
    this.postType = 'general',
    this.replyToId,
    this.isPinned = false,
    this.isEdited = false,
    required this.createdAt,
  });

  final String id;
  final String channelId;
  final String senderName;
  final String senderId;
  final String body;
  final String postType;
  final String? replyToId;
  final bool isPinned;
  final bool isEdited;
  final DateTime createdAt;

  factory MarketplaceCommunityMessageModel.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>? ?? const {};
    return MarketplaceCommunityMessageModel(
      id: json['id'] as String,
      channelId: json['channel_id'] as String,
      senderName: sender['display_name'] as String? ?? '',
      senderId: sender['id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      postType: json['post_type'] as String? ?? 'general',
      replyToId: json['reply_to_id'] as String?,
      isPinned: json['is_pinned'] as bool? ?? false,
      isEdited: json['is_edited'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
