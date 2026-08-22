import 'package:flutter/material.dart';

import '../theme/theme_context.dart';

/// Compact PREMIUM ribbon for seller creation cards.
class PremiumRibbonBadge extends StatelessWidget {
  const PremiumRibbonBadge({super.key, this.label = 'PREMIUM'});

  final String label;

  static const _ribbonViolet = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _ribbonViolet,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomLeft: Radius.circular(10),
        ),
        boxShadow: [
          BoxShadow(
            color: _ribbonViolet.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              size: 12,
              color: context.colors.onPrimary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: context.colors.onPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
