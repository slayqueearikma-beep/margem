import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'seller_navigation.dart';
import 'seller_shell.dart';

/// Legacy entry point kept for route compatibility.
class SellerDashboardScreen extends ConsumerWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SellerShell();
  }
}

/// Redirects `/seller/services` to the catalog tab inside the shell.
class SellerServicesRedirect extends ConsumerWidget {
  const SellerServicesRedirect({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sellerTabIndexProvider.notifier).state = 1;
      if (context.mounted &&
          GoRouterState.of(context).matchedLocation != '/seller/dashboard') {
        context.go('/seller/dashboard');
      }
    });
    return const SellerShell();
  }
}

/// Redirects `/seller/messages` to the messages tab inside the shell.
class SellerMessagesRedirect extends ConsumerWidget {
  const SellerMessagesRedirect({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sellerTabIndexProvider.notifier).state = 2;
      if (context.mounted &&
          GoRouterState.of(context).matchedLocation != '/seller/dashboard') {
        context.go('/seller/dashboard');
      }
    });
    return const SellerShell();
  }
}
