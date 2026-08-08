import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:souq_local/core/navigation/margem_navigation_leading.dart';
import 'package:souq_local/core/widgets/margem_app_bar.dart';

void main() {
  testWidgets('MarGemAppBar shows back on pushed child routes', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(
              path: 'child',
              builder: (_, __) => const Scaffold(
                appBar: MarGemAppBar(),
                body: Text('child'),
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/child');
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget);
    expect(shouldShowMargemBackButton(
      router.routerDelegate.navigatorKey.currentContext!,
    ), isTrue);
  });

  testWidgets('MarGemAppBar hides back on app root route', (tester) async {
    final router = GoRouter(
      initialLocation: '/buyer/home',
      routes: [
        GoRoute(
          path: '/buyer/home',
          builder: (_, __) => const Scaffold(
            appBar: MarGemAppBar(),
            body: Text('home'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('MarGemAppBar shows back for orphan deep links', (tester) async {
    final router = GoRouter(
      initialLocation: '/product/s1/p1',
      routes: [
        GoRoute(
          path: '/product/:sellerId/:productId',
          builder: (_, __) => const Scaffold(
            appBar: MarGemAppBar(),
            body: Text('product'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget);
  });
}
