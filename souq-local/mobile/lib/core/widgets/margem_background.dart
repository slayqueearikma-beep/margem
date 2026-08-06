import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Soft neutral gradient blob background used across MarGem screens.
class MargemBackground extends StatelessWidget {
  const MargemBackground({
    super.key,
    required this.child,
    this.showBlobs = true,
    this.padding,
  });

  final Widget child;
  final bool showBlobs;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final accent = AppColors.accent(brightness);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.scaffold(brightness),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showBlobs) ...[
            Positioned(
              top: -80,
              left: -60,
              child: _GradientBlob(
                size: 280,
                colors: isDark
                    ? [
                        AppColors.surfaceMuted.withValues(alpha: 0.12),
                        AppColors.surfaceMuted.withValues(alpha: 0.02),
                      ]
                    : [
                        AppColors.border.withValues(alpha: 0.35),
                        AppColors.border.withValues(alpha: 0.05),
                      ],
              ),
            ),
            Positioned(
              bottom: -100,
              right: -80,
              child: _GradientBlob(
                size: 320,
                colors: isDark
                    ? [
                        accent.withValues(alpha: 0.10),
                        accent.withValues(alpha: 0.02),
                      ]
                    : [
                        accent.withValues(alpha: 0.12),
                        accent.withValues(alpha: 0.03),
                      ],
              ),
            ),
          ],
          if (padding != null)
            Padding(padding: padding!, child: child)
          else
            child,
        ],
      ),
    );
  }
}

class _GradientBlob extends StatelessWidget {
  const _GradientBlob({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: colors,
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}
