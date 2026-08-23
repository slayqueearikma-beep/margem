import 'package:flutter/material.dart';

/// RTL-aware icons and small layout helpers for localized UIs.
class DirectionalUi {
  DirectionalUi._();

  static bool isRtl(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl;

  static IconData forwardChevron(BuildContext context) => isRtl(context)
      ? Icons.chevron_left_rounded
      : Icons.chevron_right_rounded;

  static IconData backArrow(BuildContext context) => isRtl(context)
      ? Icons.arrow_forward_ios_rounded
      : Icons.arrow_back_ios_new_rounded;
}
