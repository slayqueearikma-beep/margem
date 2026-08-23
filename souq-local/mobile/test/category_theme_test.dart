import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:souq_local/core/models/models.dart';
import 'package:souq_local/core/services/app_storage.dart';
import 'package:souq_local/core/theme/category_theme.dart';

void main() {
  test('CategoryModel localizedName falls back to English', () {
    const category = CategoryModel(
      id: '1',
      slug: 'doctors',
      nameEn: 'Doctors',
      nameFr: 'Médecins',
      nameAr: '',
      icon: 'medical_services',
      accentColor: '#E53935',
    );
    expect(category.localizedName('en'), 'Doctors');
    expect(category.localizedName('fr'), 'Médecins');
    expect(category.localizedName('ar'), 'Doctors');
  });

  test('CategoryTheme resolves icons and accent colors', () {
    expect(CategoryTheme.iconFor('restaurant'), Icons.restaurant_outlined);
    expect(CategoryTheme.iconFor('unknown_icon'), Icons.storefront_outlined);
    expect(
      CategoryTheme.accentColor('#E53935'),
      const Color(0xFFE53935),
    );
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
}
