import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_brand_logo.dart';
import '../../core/widgets/onboarding_backdrop.dart';
import '../../l10n/app_localizations.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = Tween<double>(begin: 0.95, end: 1).animate(
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

    final session = storage.getSession();
    final isReturningUser =
        session != null || storage.isOnboardingComplete;
    if (!isReturningUser) {
      await Future<void>.delayed(const Duration(milliseconds: 2200));
    }
    if (!mounted) return;

    await ref.read(authServiceProvider).loadStoredToken();
    var restored = await ref.read(authServiceProvider).restoreAuthSession();
    if (restored != null) {
      ref.read(authSessionProvider.notifier).state = restored;
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
        await storage.logout();
        ref.read(userSessionProvider.notifier).state = null;
        ref.read(authSessionProvider.notifier).state = null;
        if (mounted) context.go('/login');
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
        context.go(storage.homeRouteFor(hydrated));
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
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: OnboardingBackdrop(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  const AppBrandLogo(
                    tier: AppLogoTier.splash,
                    includeClearSpace: false,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.appName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.lavender,
                          letterSpacing: -0.5,
                          height: 1.05,
                        ) ??
                        const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.lavender,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                    ),
                    child: Text(
                      l10n.splashTagline,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.navy.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                            height: 1.35,
                          ),
                    ),
                  ),
                  const Spacer(flex: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
