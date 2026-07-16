import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/buyer/buyer_home_screen.dart';
import 'features/onboarding/account_type_onboarding_screen.dart';
import 'features/onboarding/buyer_registration_screen.dart';
import 'features/onboarding/onboarding_welcome_screen.dart';
import 'features/onboarding/seller_registration_screen.dart';
import 'features/seller/product_detail_screen.dart';
import 'features/seller/seller_dashboard_screen.dart';
import 'features/seller/seller_detail_screen.dart';
import 'features/splash/splash_screen.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingWelcomeScreen()),
      GoRoute(path: '/onboarding/account-type', builder: (_, __) => const AccountTypeOnboardingScreen()),
      GoRoute(path: '/onboarding/buyer-register', builder: (_, __) => const BuyerRegistrationScreen()),
      GoRoute(path: '/onboarding/seller-register', builder: (_, __) => const SellerRegistrationScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/buyer/home', builder: (_, __) => const BuyerHomeShell()),
      GoRoute(path: '/seller/dashboard', builder: (_, __) => const SellerDashboardScreen()),
      GoRoute(
        path: '/seller/:id',
        builder: (_, state) => SellerDetailScreen(sellerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/product/:sellerId/:productId',
        builder: (_, state) => ProductDetailScreen(
          sellerId: state.pathParameters['sellerId']!,
          productId: state.pathParameters['productId']!,
        ),
      ),
    ],
  );
});

class SouqLocalApp extends ConsumerWidget {
  const SouqLocalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Souq Local',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
