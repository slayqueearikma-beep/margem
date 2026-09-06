import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/marketplace_community_models.dart';
import '../../core/services/api_service.dart';

final marketplaceCommunityHubProvider = FutureProvider.autoDispose
    .family<MarketplaceCommunityHubModel, String>((ref, slug) {
  return apiServiceProvider.fetchMarketplaceCommunityHub(slug, auth: true);
});

final marketplaceCommunityChannelsProvider = FutureProvider.autoDispose
    .family<List<MarketplaceCommunityChannelModel>, String>((ref, slug) {
  return apiServiceProvider.fetchMarketplaceCommunityChannels(slug, auth: true);
});
