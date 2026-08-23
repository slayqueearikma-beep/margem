import 'package:flutter/material.dart';

import '../navigation/margem_navigation_leading.dart';
import '../theme/theme_context.dart';
import 'app_brand_logo.dart';

/// Centered MarGem logo for toolbars and sliver app bars.
class MarGemAppBarLogo extends StatelessWidget {
  const MarGemAppBarLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppBrandLogo(
      tier: AppLogoTier.compact,
      includeClearSpace: false,
    );
  }
}

/// App bar with the MarGem logo centered on screen (not offset by actions).
class MarGemAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MarGemAppBar({
    super.key,
    this.leading,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.backgroundColor,
    this.showDivider = true,
    this.semanticLabel,
  });

  final Widget? leading;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final bool showDivider;
  final String? semanticLabel;

  @override
  Size get preferredSize {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    final dividerHeight = showDivider && bottom == null ? 1.0 : 0.0;
    return Size.fromHeight(kToolbarHeight + bottomHeight + dividerHeight);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget? effectiveLeading = leading;
    if (effectiveLeading == null &&
        automaticallyImplyLeading &&
        shouldShowMargemBackButton(context)) {
      effectiveLeading = MargemBackLeading(color: colors.textPrimary);
    }

    final actionWidgets = actions ?? const <Widget>[];

    return Material(
      color: backgroundColor ?? colors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: kToolbarHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (effectiveLeading != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: effectiveLeading,
                    ),
                  Semantics(
                    label: semanticLabel ?? 'MarGem',
                    child: const MarGemAppBarLogo(),
                  ),
                  if (actionWidgets.isNotEmpty)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actionWidgets,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (bottom != null) bottom!,
          if (showDivider && bottom == null)
            Container(height: 1, color: colors.divider),
        ],
      ),
    );
  }
}
