import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/platform_ad_models.dart';
import '../providers/platform_ad_providers.dart';
import 'platform_ad_banner.dart';

class PlatformAdSlot extends ConsumerWidget {
  const PlatformAdSlot({
    super.key,
    required this.placement,
    this.adContext = const PlatformAdContext(),
    this.limit = 1,
  });

  final String placement;
  final PlatformAdContext adContext;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adsAsync = ref.watch(
      platformAdsProvider((
        placement: placement,
        context: adContext,
        limit: limit,
      )),
    );

    return adsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (ads) {
        if (ads.isEmpty) return const SizedBox.shrink();
        return Column(
          children: ads
              .map(
                (ad) => PlatformAdBanner(
                  ad: ad,
                  placement: placement,
                  adContext: adContext,
                ),
              )
              .toList(),
        );
      },
    );
  }
}
