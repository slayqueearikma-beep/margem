import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/widgets/app_brand_logo.dart';
import 'package:souq_local/core/widgets/margem_app_bar.dart';

Size _logoBoxSize(WidgetTester tester) {
  final logo = find.bySemanticsLabel('Dribex logo');
  expect(logo, findsOneWidget);
  final renderBox = tester.renderObject<RenderBox>(logo);
  final parent = renderBox.parent;
  expect(parent, isA<RenderBox>());
  return (parent as RenderBox).size;
}

void main() {
  testWidgets('header tier logo uses responsive auth size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Scaffold(
            body: AppBrandLogo(
              tier: AppLogoTier.header,
              includeClearSpace: false,
            ),
          ),
        ),
      ),
    );

    expect(_logoBoxSize(tester), const Size(140, 140));
  });

  testWidgets('navbar tier logo fills shared toolbar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Scaffold(
            body: AppBrandLogo(
              tier: AppLogoTier.navbar,
              includeClearSpace: false,
            ),
          ),
        ),
      ),
    );

    expect(_logoBoxSize(tester), const Size(24, 24));
  });

  testWidgets('MarGemAppBarLogo uses navbar tier', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Scaffold(
            body: const MarGemAppBarLogo(),
          ),
        ),
      ),
    );

    expect(_logoBoxSize(tester), const Size(24, 24));
  });

  testWidgets('forContext honors explicit size override', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Scaffold(
            body: AppBrandLogo.forContext(
              AppBrandContext.compactBranding,
              size: 72,
              includeClearSpace: false,
            ),
          ),
        ),
      ),
    );

    expect(_logoBoxSize(tester), const Size(72, 72));
  });

  testWidgets('settingsBranding maps to header tier size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Scaffold(
            body: AppBrandLogo.forContext(
              AppBrandContext.settingsBranding,
              includeClearSpace: false,
            ),
          ),
        ),
      ),
    );

    expect(_logoBoxSize(tester), const Size(140, 140));
  });

  testWidgets('splash tier uses larger hero size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Scaffold(
            body: AppBrandLogo(
              tier: AppLogoTier.splash,
              includeClearSpace: false,
            ),
          ),
        ),
      ),
    );

    expect(_logoBoxSize(tester), const Size(248, 248));
  });
}
