import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/media_url_resolver.dart';
import 'platform_ad_constants.dart';

class FullPageAdOverlay extends StatefulWidget {
  const FullPageAdOverlay({
    super.key,
    required this.ad,
    required this.adViewerId,
    required this.viewKey,
  });

  final PlatformAdvertisementModel ad;
  final String adViewerId;
  final String viewKey;

  @override
  State<FullPageAdOverlay> createState() => _FullPageAdOverlayState();
}

class _FullPageAdOverlayState extends State<FullPageAdOverlay> {
  VideoPlayerController? _videoController;
  var _impressionRecorded = false;

  @override
  void initState() {
    super.initState();
    _recordImpression();
    _initVideoIfNeeded();
  }

  Future<void> _recordImpression() async {
    if (_impressionRecorded) return;
    _impressionRecorded = true;
    try {
      await apiServiceProvider.recordAdImpression(
        campaignId: widget.ad.id,
        placement: PlatformAdPlacements.fullPage,
        viewKey: widget.viewKey,
        adViewerId: widget.adViewerId,
      );
    } on Object {
      // Ads must never break the buyer experience.
    }
  }

  Future<void> _initVideoIfNeeded() async {
    final videoUrl = widget.ad.videoUrl?.trim();
    if (videoUrl == null || videoUrl.isEmpty) return;
    final resolved = MediaUrlResolver.resolve(videoUrl);
    final controller = VideoPlayerController.networkUrl(Uri.parse(resolved));
    _videoController = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (mounted) setState(() {});
    } on Object {
      await controller.dispose();
      _videoController = null;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _openAd() async {
    final clickKey =
        'click-${widget.ad.id}-${DateTime.now().millisecondsSinceEpoch}';
    final url = apiServiceProvider.buildAdClickUrl(
      ad: widget.ad,
      clickKey: clickKey,
    );
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final media = _buildMedia(context);
    if (media == null) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => _openAd(),
                child: media,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
            if (widget.ad.title.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      widget.ad.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget? _buildMedia(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final controller = _videoController;
    if (controller != null && controller.value.isInitialized) {
      return Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        ),
      );
    }

    final imageUrl = MediaUrlResolver.resolve(widget.ad.imageUrl);
    if (imageUrl.isEmpty) return null;
    return Center(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          placeholder: (_, __) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

String generateAdViewKey(String campaignId) {
  final random = math.Random();
  return 'view-$campaignId-${DateTime.now().millisecondsSinceEpoch}-${random.nextInt(1 << 32)}';
}
