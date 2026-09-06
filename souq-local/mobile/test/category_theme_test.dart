import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:souq_local/core/models/models.dart';
import 'package:souq_local/core/services/app_storage.dart';
import 'package:souq_local/core/theme/app_semantic_colors.dart';
import 'package:souq_local/core/theme/app_theme.dart';
import 'package:souq_local/core/widgets/app_brand_logo.dart';
import 'package:souq_local/core/widgets/buyer_ui_components.dart';

void main() {
  test('CategoryModel localizedName falls back to English', () {
    const category = CategoryModel(
      id: '1',
      slug: 'food',
      nameEn: 'Food',
      nameFr: 'Nourriture',
      nameAr: '',
      icon: 'restaurant',
    );
    expect(category.localizedName('en'), 'Food');
    expect(category.localizedName('fr'), 'Nourriture');
    expect(category.localizedName('ar'), 'Food');
  });

  test('AppStorage persists theme mode', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = AppStorage(prefs);
    expect(storage.getThemeMode(), ThemeMode.system);
    await storage.saveThemeMode(ThemeMode.dark);
    expect(storage.getThemeMode(), ThemeMode.dark);
    await storage.saveThemeMode(ThemeMode.light);
    expect(storage.getThemeMode(), ThemeMode.light);
  });

  testWidgets('BuyerScreenScaffold follows MaterialApp dark theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const BuyerScreenScaffold(
          body: Center(child: Text('buyer')),
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppSemanticColors.dark.surface);
  });

  testWidgets('BuyerScreenScaffold follows MaterialApp light theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.light,
        home: const BuyerScreenScaffold(
          body: Center(child: Text('buyer')),
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppSemanticColors.light.surface);
  });

  testWidgets('BuyerShellHeader centers logo between balanced side slots', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BuyerShellHeader(
            onMenu: () {},
            onNotifications: () {},
            onProfile: () {},
          ),
        ),
      ),
    );

    final headerRect = tester.getRect(find.byType(BuyerShellHeader));
    final logoCenter = tester.getCenter(find.byType(AppBrandLogo));
    expect(
      (logoCenter.dx - headerRect.center.dx).abs(),
      lessThan(2),
    );
  });
}
