import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/theme_context.dart';
import 'app_back_handler.dart';

/// Whether the navigator or GoRouter stack can pop to a previous route.
bool margemCanPop(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null && router.canPop()) return true;
  return Navigator.canPop(context);
}

/// Fallback destination when the stack is empty (e.g. orphan deep links).
String? margemFallbackBackLocation(String location) {
  if (location.isEmpty || isAppRootLocation(location)) return null;
  if (location.startsWith('/seller/products') ||
      location.startsWith('/seller/services') ||
      location.startsWith('/seller/analytics') ||
      location.startsWith('/seller/profile') ||
      location.startsWith('/seller/reviews') ||
      location.startsWith('/seller/settings') ||
      location.startsWith('/seller/notifications') ||
      location.startsWith('/seller/messages') ||
      location == '/seller/dashboard') {
    return '/seller/dashboard';
  }
  return '/buyer/home';
}

/// Whether a top-left back control should appear for this route.
bool shouldShowMargemBackButton(BuildContext context) {
  if (margemCanPop(context)) return true;
  final router = GoRouter.maybeOf(context);
  final location = router?.state.uri.path ?? '';
  return margemFallbackBackLocation(location) != null;
}

/// Pop the stack when possible; otherwise navigate to the logical parent route.
void margemNavigateBack(BuildContext context) {
  if (margemCanPop(context)) {
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
      return;
    }
    Navigator.of(context).pop();
    return;
  }

  final router = GoRouter.maybeOf(context);
  final location = router?.state.uri.path ?? '';
  final fallback = margemFallbackBackLocation(location);
  if (fallback != null) {
    router?.go(fallback);
  }
}

/// Standard top-left back control for [MarGemAppBar] and pushed routes.
///
/// Uses [BackButton] so RTL mirroring follows platform conventions.
class MargemBackLeading extends StatelessWidget {
  const MargemBackLeading({
    super.key,
    this.onPressed,
    this.color,
    this.forceShow = false,
  });

  final VoidCallback? onPressed;
  final Color? color;
  final bool forceShow;

  @override
  Widget build(BuildContext context) {
    if (!forceShow && !shouldShowMargemBackButton(context)) {
      return const SizedBox.shrink();
    }
    return BackButton(
      color: color ?? context.colors.textPrimary,
      onPressed: onPressed ?? () => margemNavigateBack(context),
    );
  }
}
