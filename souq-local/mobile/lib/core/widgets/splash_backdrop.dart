import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fixed splash illustration — cream sky in light mode, deep navy in dark mode.
class SplashBackdrop extends StatelessWidget {
  const SplashBackdrop({super.key, required this.child});

  final Widget child;

  static const _skylineAsset = 'assets/images/onboarding/onboarding_skyline.png';

  static const _skyTop = Color(0xFFFDF6EE);
  static const _skyMid = Color(0xFFF8F1E9);
  static const _skyLow = Color(0xFFF3E6D8);
  static const _skyBase = Color(0xFFEFE0D2);

  static const _darkSkyTop = Color(0xFF0B0F14);
  static const _darkSkyMid = Color(0xFF111827);
  static const _darkSkyLow = Color(0xFF151B23);
  static const _darkSkyBase = Color(0xFF1F2937);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final minSkyline = math.min(size.width * 0.34, size.height * 0.36);
    final maxSkyline = math.max(size.width * 0.34, size.height * 0.36);
    final skylineHeight = (size.height * 0.30).clamp(minSkyline, maxSkyline);
    final baseColor = isDark ? AppColors.darkBackground : AppColors.cream;
    final gradientColors = isDark
        ? const [_darkSkyTop, _darkSkyMid, _darkSkyLow, _darkSkyBase]
        : const [_skyTop, _skyMid, _skyLow, _skyBase];
    final skylineFade = isDark ? _darkSkyLow : _skyLow;

    return ColoredBox(
      color: baseColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 0.78, 1.0],
                colors: gradientColors,
              ),
            ),
          ),
          Positioned(
            top: -size.height * 0.08,
            left: size.width * 0.18,
            child: _AtmosphericGlow(
              diameter: size.width * 0.95,
              color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFFFF8F2),
              opacity: isDark ? 0.35 : 0.55,
            ),
          ),
          Positioned(
            top: size.height * 0.04,
            right: -size.width * 0.18,
            child: _AtmosphericGlow(
              diameter: size.width * 0.62,
              color: isDark ? const Color(0xFF3B82F6) : const Color(0xFFFFC9A8),
              opacity: isDark ? 0.08 : 0.10,
            ),
          ),
          Positioned(
            top: size.height * 0.22,
            left: -size.width * 0.22,
            child: _AtmosphericGlow(
              diameter: size.width * 0.52,
              color: isDark ? const Color(0xFF6366F1) : const Color(0xFFB8A0E8),
              opacity: isDark ? 0.06 : 0.07,
            ),
          ),
          if (!isDark) ...[
            Positioned(
              top: size.height * 0.05,
              left: -size.width * 0.10,
              child: _CloudBlob(diameter: size.width * 0.78, opacity: 0.36),
            ),
            Positioned(
              top: size.height * 0.14,
              right: -size.width * 0.12,
              child: _CloudBlob(diameter: size.width * 0.62, opacity: 0.28),
            ),
            Positioned(
              top: size.height * 0.26,
              left: size.width * 0.10,
              child: _CloudBlob(diameter: size.width * 0.44, opacity: 0.22),
            ),
          ],
          Positioned(
            top: size.height * 0.10,
            right: size.width * 0.14,
            child: _BirdFlock(
              width: size.width * 0.18,
              isDark: isDark,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: skylineHeight,
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.bottomCenter,
              children: [
                Opacity(
                  opacity: isDark ? 0.72 : 1.0,
                  child: Image.asset(
                    _skylineAsset,
                    width: size.width,
                    height: skylineHeight,
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.bottomCenter,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: skylineHeight * 0.42,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          skylineFade.withValues(alpha: isDark ? 0.96 : 0.92),
                          skylineFade.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AtmosphericGlow extends StatelessWidget {
  const _AtmosphericGlow({
    required this.diameter,
    required this.color,
    required this.opacity,
  });

  final double diameter;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloudBlob extends StatelessWidget {
  const _CloudBlob({required this.diameter, required this.opacity});

  final double diameter;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter * 0.52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(diameter),
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: opacity),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _BirdFlock extends StatelessWidget {
  const _BirdFlock({required this.width, required this.isDark});

  final double width;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: width,
        height: width * 0.35,
        child: CustomPaint(
          painter: _BirdFlockPainter(
            color: (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF8A7B72))
                .withValues(alpha: isDark ? 0.35 : 0.28),
          ),
        ),
      ),
    );
  }
}

class _BirdFlockPainter extends CustomPainter {
  _BirdFlockPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    void bird(Offset center, double span) {
      final path = Path()
        ..moveTo(center.dx - span, center.dy + span * 0.18)
        ..quadraticBezierTo(
          center.dx,
          center.dy - span * 0.42,
          center.dx + span,
          center.dy + span * 0.18,
        );
      canvas.drawPath(path, paint);
    }

    bird(Offset(size.width * 0.22, size.height * 0.55), size.width * 0.07);
    bird(Offset(size.width * 0.52, size.height * 0.42), size.width * 0.08);
    bird(Offset(size.width * 0.78, size.height * 0.58), size.width * 0.06);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
