import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/platform_ad_models.dart';
import '../services/api_service.dart';
import '../services/app_storage.dart';
import '../services/media_url_resolver.dart';
import '../theme/app_spacing.dart';
import '../theme/theme_context.dart';
import 'network_image_view.dart';

class PlatformAdBanner extends ConsumerStatefulWidget {
  const PlatformAdBanner({
    super.key,
    required this.ad,
    required this.placement,
    this.adContext = const PlatformAdContext(),
  });

  final PlatformAdvertisementModel ad;
  final String placement;
  final PlatformAdContext adContext;

  @override
  ConsumerState<PlatformAdBanner> createState() => _PlatformAdBannerState();
}

class _PlatformAdBannerState extends ConsumerState<PlatformAdBanner> {
  bool _impressionRecorded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordImpression());
  }

  Future<void> _recordImpression() async {
    if (_impressionRecorded) return;
    _impressionRecorded = true;
    final storage = ref.read(appStorageProvider);
    if (storage == null) return;
    final viewerKey = storage.getAdViewerKey();
    final viewKey = '${widget.ad.id}-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(99999)}';
    try {
      await apiServiceProvider.recordPlatformAdImpression(
        campaignId: widget.ad.id,
        placement: widget.placement,
        viewKey: viewKey,
        viewerKey: viewerKey,
        adContext: widget.adContext,
      );
    } catch (_) {
      // Ads must never break the surrounding screen.
    }
  }

  Future<void> _handleTap() async {
    final clickUri = apiServiceProvider.buildPlatformAdClickUri(
      ad: widget.ad,
      context: widget.adContext,
      clickKey: '${widget.ad.id}-click-${DateTime.now().millisecondsSinceEpoch}',
    );
    if (!await launchUrl(clickUri, mode: LaunchMode.externalApplication)) {
      return;
    }
  }

  String _resolveCreativeUrl(String url, {required bool video}) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      if (trimmed.contains('/media/')) {
        return MediaUrlResolver.resolve(trimmed);
      }
      if (!video) {
        return '${AppConfig.apiBaseUrl}/ads/media/${widget.ad.id}/image';
      }
      return '${AppConfig.apiBaseUrl}/ads/media/${widget.ad.id}/video';
    }
    if (trimmed.startsWith('/media/')) {
      return MediaUrlResolver.resolve('${AppConfig.apiBaseUrl}$trimmed');
    }
    if (trimmed.startsWith('/')) {
      return '${AppConfig.apiBaseUrl}$trimmed';
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveCreativeUrl(widget.ad.imageUrl, video: false);
    if (imageUrl.isEmpty) return const SizedBox.shrink();

    final videoUrl = widget.ad.videoUrl == null || widget.ad.videoUrl!.isEmpty
        ? null
        : _resolveCreativeUrl(widget.ad.videoUrl!, video: true);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Text(
                    'Advertisement',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.colors.textSecondary,
                          letterSpacing: 1.2,
                        ),
                  ),
                ),
                AspectRatio(
                  aspectRatio: 21 / 9,
                  child: videoUrl != null
                      ? NetworkImageView(url: videoUrl, fit: BoxFit.cover)
                      : NetworkImageView(url: imageUrl, fit: BoxFit.cover),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.ad.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (widget.ad.description != null &&
                          widget.ad.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            widget.ad.description!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: context.colors.textSecondary,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
