import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Reserved logo placeholder matching the Visily splash / auth screens.
class AppLogoPlaceholder extends StatelessWidget {
  const AppLogoPlaceholder({
    super.key,
    this.size = 120,
    this.onPurpleBackground = false,
  });

  final double size;
  final bool onPurpleBackground;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Application logo placeholder',
      child: CustomPaint(
        size: Size(size, size),
        painter: _LogoPainter(onPurpleBackground: onPurpleBackground),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.onPurpleBackground});

  final bool onPurpleBackground;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38;

    final blobPaint = Paint()
      ..color = onPurpleBackground ? AppColors.logoPlaceholder : AppColors.primary
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(center.dx, center.dy - radius);
    path.quadraticBezierTo(center.dx + radius * 1.1, center.dy - radius * 0.3, center.dx + radius * 0.7, center.dy + radius * 0.6);
    path.quadraticBezierTo(center.dx + radius * 0.2, center.dy + radius * 1.1, center.dx - radius * 0.5, center.dy + radius * 0.5);
    path.quadraticBezierTo(center.dx - radius * 1.0, center.dy - radius * 0.1, center.dx, center.dy - radius);
    path.close();
    canvas.drawPath(path, blobPaint);

    final innerPaint = Paint()
      ..color = onPurpleBackground ? AppColors.logoInner : AppColors.logoPlaceholder
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.28, innerPaint);

    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.1, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Compact logo for app bars and headers.
class AppLogoHeader extends StatelessWidget {
  const AppLogoHeader({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return AppLogoPlaceholder(size: size, onPurpleBackground: false);
  }
}
