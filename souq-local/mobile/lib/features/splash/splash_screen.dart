import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/post_auth_navigation.dart';
import '../../core/services/legal_acceptance_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_brand_logo.dart';
import '../../core/widgets/splash_backdrop.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  static const _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.cream,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(_overlayStyle);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    final storage = ref.read(appStorageProvider);
    if (storage == null) {
      await ref.read(sharedPreferencesProvider.future);
      if (!mounted) return;
      return _navigateNext();
    }

    final storedSession = storage.getSession();
    final isReturningUser =
        storedSession != null || storage.isOnboardingComplete;
    if (!isReturningUser) {
      await Future<void>.delayed(const Duration(milliseconds: 2200));
    }
    if (!mounted) return;

    await ref.read(authServiceProvider).loadStoredToken();
    var restored = await ref.read(authServiceProvider).restoreAuthSession();
    if (restored != null) {
      ref.read(authSessionProvider.notifier).state = restored;
      syncLegalAcceptanceFromAuthUser(ref, restored.user);
    }

    final session = storage.getSession();
    if (session != null) {
      if (session.isGuest) {
        ref.read(userSessionProvider.notifier).state = session;
        if (mounted) context.go('/buyer/home');
        return;
      }
      final valid = await ref.read(authServiceProvider).ensureSessionValid();
      if (!valid) {
        await storage.logout();
        ref.read(userSessionProvider.notifier).state = null;
        ref.read(authSessionProvider.notifier).state = null;
        if (mounted) context.go('/login');
        return;
      }
      restored ??= await ref.read(authServiceProvider).restoreAuthSession();
      if (restored == null) {
        ref.read(userSessionProvider.notifier).state = session;
        if (mounted) {
          context.go(
            await resolveAuthenticatedDestination(ref, storage, session),
          );
        }
        return;
      }
      ref.read(authSessionProvider.notifier).state = restored;
      final hydrated = session.copyWith(
        name: restored.user.displayName,
        email: restored.user.email,
      );
      await storage.saveSession(hydrated);
      ref.read(userSessionProvider.notifier).state = hydrated;
      if (mounted) {
        context.go(
          await resolveAuthenticatedDestination(ref, storage, hydrated),
        );
      }
      return;
    }

    if (!storage.isOnboardingComplete) {
      if (!mounted) return;
      context.go('/onboarding');
      return;
    }

    if (!mounted) return;
    context.go('/login');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final logoSize = AppLogoLayout.sizeFor(context, AppLogoTier.splash);

    // Place the logo slightly above optical center, accounting for skyline mass.
    final logoCenterY = (screenHeight * 0.43) + (viewPadding.top * 0.15);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayStyle,
      child: ColoredBox(
        color: AppColors.cream,
        child: SplashBackdrop(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: logoCenterY - (logoSize / 2),
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    alignment: Alignment.center,
                    child: const Center(
                      child: AppBrandLogo(
                        tier: AppLogoTier.splash,
                        includeClearSpace: false,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
