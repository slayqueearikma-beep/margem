import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:souq_local/core/navigation/margem_navigation_leading.dart';
import 'package:souq_local/core/widgets/buyer_ui_components.dart';
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

  testWidgets('BuyerAdaptiveHeader hides back inside buyer home tab shell',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: BuyerAdaptiveHeader(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('BuyerAdaptiveHeader shows back on pushed /search route',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(
              path: 'search',
              builder: (_, __) => const Scaffold(
                body: BuyerAdaptiveHeader(),
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/search');
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('BuyerAdaptiveHeader can force back for buyer home tabs',
      (tester) async {
    var homeTab = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuyerAdaptiveHeader(
            showBack: true,
            onBack: () => homeTab = 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(homeTab, 0);
  });
}
