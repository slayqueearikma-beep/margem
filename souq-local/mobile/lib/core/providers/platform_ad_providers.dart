import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/platform_ad_models.dart';
import '../services/api_service.dart';
import '../services/app_storage.dart';

typedef PlatformAdRequest = ({
  String placement,
  PlatformAdContext context,
  int limit,
});

final platformAdsProvider = FutureProvider.autoDispose
    .family<List<PlatformAdvertisementModel>, PlatformAdRequest>((ref, request) async {
  final storage = ref.watch(appStorageProvider);
  final viewerKey = storage?.getAdViewerKey();
  try {
    return await apiServiceProvider.fetchActivePlatformAds(
      placement: request.placement,
      context: request.context,
      limit: request.limit,
      viewerKey: viewerKey,
    );
  } catch (_) {
    return const [];
  }
});
