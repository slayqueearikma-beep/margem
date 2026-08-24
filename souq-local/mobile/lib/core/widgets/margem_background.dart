import 'package:flutter/material.dart';

import '../theme/theme_context.dart';

/// Neutral background used across MarGem screens.
class MargemBackground extends StatelessWidget {
  const MargemBackground({
    super.key,
    required this.child,
    this.showBlobs = false,
    this.padding,
  });

  final Widget child;
  final bool showBlobs;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.background),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showBlobs) ...[
            Positioned(
              top: -80,
              left: -60,
              child: _GradientBlob(
                size: 280,
                colors: [
                  colors.surfaceVariant.withValues(alpha: 0.35),
                  colors.background.withValues(alpha: 0),
                ],
              ),
            ),
            Positioned(
              bottom: -100,
              right: -80,
              child: _GradientBlob(
                size: 320,
                colors: [
                  colors.surfaceVariant.withValues(alpha: 0.25),
                  colors.background.withValues(alpha: 0),
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
