import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import 'features/auth/account_type_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/home/home_shell.dart';
import 'features/seller/product_detail_screen.dart';
import 'features/seller/seller_detail_screen.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/account-type', builder: (_, __) => const AccountTypeScreen()),
    GoRoute(path: '/home', builder: (_, __) => const HomeShell()),
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

class SouqLocalApp extends ConsumerWidget {
  const SouqLocalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Souq Local',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: _router,
    );
  }
}
