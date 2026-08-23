import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Programmatic MarGem "M" logo — overlapping lavender + peach glass shapes.
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
    if (!showWordmark) {
      return CustomPaint(
        size: Size.square(size),
        painter: _MargemMLogoPainter(),
      );
    }

    final wmSize = wordmarkSize ?? size * 0.32;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size.square(size),
          painter: _MargemMLogoPainter(),
        ),
        SizedBox(height: size * 0.14),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: wmSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.05,
              fontFamily: 'Inter',
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
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Left lavender leg
    final leftPath = Path()
      ..moveTo(cx - w * 0.38, h * 0.88)
      ..quadraticBezierTo(
        cx - w * 0.42,
        h * 0.55,
        cx - w * 0.30,
        h * 0.12,
      )
      ..quadraticBezierTo(
        cx - w * 0.22,
        h * 0.42,
        cx - w * 0.08,
        h * 0.88,
      )
      ..close();

    // Right peach leg
    final rightPath = Path()
      ..moveTo(cx + w * 0.38, h * 0.88)
      ..quadraticBezierTo(
        cx + w * 0.42,
        h * 0.55,
        cx + w * 0.30,
        h * 0.12,
      )
      ..quadraticBezierTo(
        cx + w * 0.22,
        h * 0.42,
        cx + w * 0.08,
        h * 0.88,
      )
      ..close();

    final leftPaint = Paint()
      ..color = AppColors.lavender.withValues(alpha: 0.92)
      ..blendMode = BlendMode.srcOver;
    final rightPaint = Paint()
      ..color = AppColors.peach.withValues(alpha: 0.92)
      ..blendMode = BlendMode.srcOver;

    canvas.drawPath(leftPath, leftPaint);
    canvas.drawPath(rightPath, rightPaint);

    // Center overlap highlight
    final overlap = Path()
      ..moveTo(cx - w * 0.08, h * 0.88)
      ..quadraticBezierTo(cx, h * 0.50, cx + w * 0.08, h * 0.88)
      ..close();
    canvas.drawPath(
      overlap,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
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
  _MargemMLogoPainter().paint(canvas, Size.square(size));
  final picture = recorder.endRecording();
  return picture.toImage(size.toInt(), size.toInt());
}
