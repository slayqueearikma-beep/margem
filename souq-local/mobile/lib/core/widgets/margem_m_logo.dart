import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Programmatic MarGem logo — three overlapping lavender + peach pills.
///
/// Vector rendering stays crisp at any DPI; PNG assets are generated from the
/// same geometry via [scripts/generate_margem_logo.py].
class MargemMLogo extends StatelessWidget {
  const MargemMLogo({
    super.key,
    this.size = 80,
    this.showWordmark = false,
    this.wordmarkSize,
  });

  final double size;
  final bool showWordmark;
  final double? wordmarkSize;

  @override
  Widget build(BuildContext context) {
    final mark = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: const _MargemMLogoPainter(),
      ),
    );

    if (!showWordmark) return mark;

    final wmSize = wordmarkSize ?? size * 0.28;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(height: size * 0.12),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: wmSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.05,
            ),
            children: const [
              TextSpan(
                text: 'Mar',
                style: TextStyle(color: AppColors.navy),
              ),
              TextSpan(
                text: 'Gem',
                style: TextStyle(color: AppColors.lavender),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MargemMLogoPainter extends CustomPainter {
  const _MargemMLogoPainter();

  static const _lavender = Color(0xFF9A87F6);
  static const _peach = AppColors.peach;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Left lavender leg — curved pill
    final leftPath = Path()
      ..moveTo(w * 0.20, h * 0.90)
      ..cubicTo(w * 0.10, h * 0.62, w * 0.14, h * 0.22, w * 0.30, h * 0.10)
      ..cubicTo(w * 0.36, h * 0.38, w * 0.40, h * 0.62, w * 0.46, h * 0.90)
      ..close();

    // Right peach leg — curved pill
    final rightPath = Path()
      ..moveTo(w * 0.80, h * 0.90)
      ..cubicTo(w * 0.90, h * 0.62, w * 0.86, h * 0.22, w * 0.70, h * 0.10)
      ..cubicTo(w * 0.64, h * 0.38, w * 0.60, h * 0.62, w * 0.54, h * 0.90)
      ..close();

    // Center overlap pill — semi-transparent lavender
    final centerPath = Path()
      ..moveTo(w * 0.46, h * 0.90)
      ..cubicTo(w * 0.48, h * 0.55, w * 0.50, h * 0.30, w * 0.50, h * 0.14)
      ..cubicTo(w * 0.52, h * 0.30, w * 0.52, h * 0.55, w * 0.54, h * 0.90)
      ..close();

    canvas.drawPath(leftPath, Paint()..color = _lavender);
    canvas.drawPath(rightPath, Paint()..color = _peach);
    canvas.drawPath(
      centerPath,
      Paint()
        ..color = _lavender.withValues(alpha: 0.45)
        ..blendMode = BlendMode.srcOver,
    );

    // Soft highlight on overlap for glass depth
    canvas.drawPath(
      centerPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..blendMode = BlendMode.softLight,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Renders logo to an image for asset export (dev tooling).
Future<ui.Image> renderMargemLogoImage(double size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const painter = _MargemMLogoPainter();
  painter.paint(canvas, Size.square(size));
  final picture = recorder.endRecording();
  return picture.toImage(size.toInt(), size.toInt());
}
