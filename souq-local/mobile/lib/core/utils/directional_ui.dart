import 'package:flutter/material.dart';

/// RTL-aware icons and small layout helpers for localized UIs.
class DirectionalUi {
  DirectionalUi._();

  static bool isRtl(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl;

  static IconData forwardChevron(BuildContext context) => isRtl(context)
      ? Icons.chevron_left_rounded
      : Icons.chevron_right_rounded;

  static IconData forwardArrow(BuildContext context) => isRtl(context)
      ? Icons.arrow_back_rounded
      : Icons.arrow_forward_rounded;

  static IconData backArrow(BuildContext context) => isRtl(context)
      ? Icons.arrow_forward_ios_rounded
      : Icons.arrow_back_ios_new_rounded;

  static IconData sendIcon(BuildContext context) => Icons.send_rounded;

  static Widget mirroredSendIcon(BuildContext context, {Color? color, double size = 24}) {
    final icon = Icon(sendIcon(context), color: color, size: size);
    if (!isRtl(context)) return icon;
    return Transform.flip(child: icon, flipX: true);
  }
}
