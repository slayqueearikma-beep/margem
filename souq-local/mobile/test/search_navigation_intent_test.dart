import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/features/search/search_filters.dart';
import 'package:souq_local/features/search/search_navigation_intent.dart';

void main() {
  test('home category intent applies filter to products when search mode was services', () {
    const filters = {
      'products': SearchFilters(),
      'services': SearchFilters(category: 'food'),
      'providers': SearchFilters(),
    };

    final application = applySearchNavigationIntent(
      intent: const SearchNavigationIntent(
        mode: 'products',
        categorySlug: 'phones',
      ),
      currentMode: 'services',
      filtersByMode: filters,
    );

    expect(application.mode, 'products');
    expect(application.resolvedCategory, 'electronics');
    expect(application.filtersByMode['products']?.category, 'electronics');
    expect(application.filtersByMode['services']?.category, 'food');
  });
}
