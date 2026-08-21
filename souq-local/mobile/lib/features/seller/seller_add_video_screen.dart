import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/services/api_service.dart';
import '../../core/services/upload_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/margem_app_bar.dart';
import '../../l10n/app_localizations.dart';
import 'seller_account_provider.dart';
import 'seller_video_constants.dart';

class SellerAddVideoScreen extends ConsumerStatefulWidget {
  const SellerAddVideoScreen({super.key, this.initialFile});

  final File? initialFile;

  @override
  ConsumerState<SellerAddVideoScreen> createState() =>
      _SellerAddVideoScreenState();
}

class _SellerAddVideoScreenState extends ConsumerState<SellerAddVideoScreen> {
  File? _videoFile;
  VideoPlayerController? _previewController;
  Duration? _duration;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _setVideoFile(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _setVideoFile(File file) async {
    _previewController?.dispose();
    setState(() {
      _videoFile = file;
      _duration = null;
      _error = null;
    });

    final controller = VideoPlayerController.file(file);
    _previewController = controller;
    try {
      await controller.initialize();
      final duration = controller.value.duration;
      if (!mounted) return;
      if (duration.inSeconds >= 60) {
        setState(() {
          _error = context.l10n.videoTooLong;
          _videoFile = null;
        });
        await controller.dispose();
        _previewController = null;
        return;
      }
      setState(() => _duration = duration);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = context.l10n.videoLoadFailed);
    }
  }

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: maxVideoDurationSeconds),
    );
    if (picked == null || !mounted) return;
    await _setVideoFile(File(picked.path));
  }

  Future<void> _recordVideo() async {
    final file = await context.push<File?>(
      '/seller/videos/record',
    );
    if (file == null || !mounted) return;
    await _setVideoFile(file);
  }

  Future<void> _publish() async {
    final l10n = context.l10n;
    final file = _videoFile;
    final duration = _duration;
    if (file == null || duration == null) return;
    if (duration.inSeconds >= 60) {
      setState(() => _error = l10n.videoTooLong);
      return;
    }

    final account = ref.read(sellerAccountProvider).valueOrNull;
    if (account == null) return;
    if (!_isPremium(account.stats.isPremium || account.profile.isPremium)) {
      _showPremiumRequired();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final upload = ref.read(uploadServiceProvider);
      final uploaded = await upload.uploadVideo(
        XFile(file.path),
        durationSeconds: duration.inMilliseconds / 1000.0,
      );
      await apiServiceProvider.addSellerVideo(
        account.profile.id,
        videoUrl: uploaded.publicUrl,
        durationSeconds: uploaded.durationSeconds,
        contentType: uploaded.contentType,
      );
      ref.invalidate(sellerAccountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.videoPublished)),
      );
      context.pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      await showAppErrorDialog(
        context,
        title: l10n.somethingWentWrong,
        message: error.message,
      );
    } catch (_) {
      if (!mounted) return;
      await showAppErrorDialog(
        context,
        title: l10n.somethingWentWrong,
        message: l10n.somethingWentWrong,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isPremium(bool flag) => flag;

  void _showPremiumRequired() {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.premiumRequiredTitle),
        content: Text(l10n.premiumRequiredForVideo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/premium');
            },
            child: Text(l10n.upgradeToPremium),
          ),
        ],
      ),
    );
  }

  String _formatTimer(Duration value) {
    final m = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accountAsync = ref.watch(sellerAccountProvider);

    return accountAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: const MarGemAppBar(),
        body: AsyncErrorView.fromError(
          error,
          onRetry: () => ref.invalidate(sellerAccountProvider),
        ),
      ),
      data: (account) {
        final isPremium =
            account.stats.isPremium || account.profile.isPremium;

        if (_videoFile == null) {
          return Scaffold(
            appBar: MarGemAppBar(
              semanticLabel: l10n.addVideo,
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.md,
                AppSpacing.screenHorizontal,
                AppSpacing.lg,
              ),
              children: [
                Text(
                  l10n.addVideoSub,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SourceOptionCard(
                  icon: Icons.videocam_outlined,
                  title: l10n.createVideo,
                  subtitle: l10n.createVideoSub,
                  onTap: isPremium ? _recordVideo : _showPremiumRequired,
                ),
                const SizedBox(height: AppSpacing.sm),
                _SourceOptionCard(
                  icon: Icons.video_library_outlined,
                  title: l10n.selectVideo,
                  subtitle: l10n.selectVideoSub,
                  onTap: isPremium ? _pickFromGallery : _showPremiumRequired,
                ),
                if (!isPremium) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.premiumRequiredForVideo,
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                ],
              ],
            ),
          );
        }

        final controller = _previewController;
        return Scaffold(
          appBar: MarGemAppBar(
            semanticLabel: l10n.addVideo,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.md,
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
            ),
            children: [
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: context.colors.error),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (controller != null && controller.value.isInitialized)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio == 0
                        ? 16 / 9
                        : controller.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(controller),
                        Container(
                          color: Colors.black45,
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '${_formatTimer(controller.value.position)} / 00:59',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: IconButton(
                            iconSize: 56,
                            color: Colors.white,
                            onPressed: () {
                              setState(() {
                                if (controller.value.isPlaying) {
                                  controller.pause();
                                } else {
                                  controller.play();
                                }
                              });
                            },
                            icon: Icon(
                              controller.value.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Center(child: CircularProgressIndicator()),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : _recordVideo,
                      child: Text(l10n.retakeVideo),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : _pickFromGallery,
                      child: Text(l10n.chooseAnotherVideo),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: _loading ? null : () => context.pop(),
                child: Text(l10n.cancel),
              ),
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(
                label: l10n.continueLabel,
                onPressed: _loading || _duration == null ? null : _publish,
                isLoading: _loading,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SourceOptionCard extends StatelessWidget {
  const _SourceOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: context.colors.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
