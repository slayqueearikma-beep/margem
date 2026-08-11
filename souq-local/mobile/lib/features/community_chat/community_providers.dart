import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/models/community_models.dart';
import '../../core/providers/city_providers.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';

final communityCitySlugProvider = Provider<String>((ref) {
  final model = ref.watch(buyerCityModelProvider);
  if (model != null) return model.slug;
  return ref.watch(buyerCityProvider).toLowerCase().replaceAll(' ', '-');
});

final communityCitiesProvider =
    FutureProvider.autoDispose<List<CommunityCityModel>>((ref) async {
  final session = ref.watch(userSessionProvider);
  return apiServiceProvider.fetchCommunityCities(auth: session != null && !session.isGuest);
});

final communityDiscoverProvider =
    FutureProvider.autoDispose<CommunityDiscoverModel>((ref) async {
  final session = ref.watch(userSessionProvider);
  return apiServiceProvider.fetchCommunityDiscover(
    auth: session != null && !session.isGuest,
  );
});

final communityChannelsProvider = FutureProvider.autoDispose
    .family<List<CommunityChannelModel>, String>((ref, citySlug) async {
  final session = ref.watch(userSessionProvider);
  return apiServiceProvider.fetchCommunityChannels(
    citySlug,
    auth: session != null && !session.isGuest,
  );
});

final communityMessagesProvider = FutureProvider.autoDispose
    .family<List<CommunityMessageModel>, String>((ref, channelId) async {
  return apiServiceProvider.fetchCommunityMessages(channelId);
});

final communitySearchQueryProvider = StateProvider<String>((ref) => '');
final communityVerifiedFilterProvider = StateProvider<bool>((ref) => false);
final communityTrustedFilterProvider = StateProvider<bool>((ref) => false);
final communitySelectedCategoryProvider = StateProvider<String?>((ref) => null);
final communityTypingUsersProvider =
    StateProvider.autoDispose<Set<String>>((ref) => {});

final communityHomeCityProvider = FutureProvider.autoDispose<String>((ref) async {
  final slug = ref.watch(communityCitySlugProvider);
  if (slug.isNotEmpty) return slug;
  return AppConfig.launchCity.toLowerCase();
});
