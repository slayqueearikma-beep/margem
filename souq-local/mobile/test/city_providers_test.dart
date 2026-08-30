import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/models/city_model.dart';
import 'package:souq_local/core/providers/city_providers.dart';

void main() {
  group('findCityByName', () {
    const cities = [
      CityModel(
        id: '1',
        slug: 'casablanca',
        nameEn: 'Casablanca',
        nameFr: 'Casablanca',
        nameAr: 'الدار البيضاء',
        latitude: 33.57,
        longitude: -7.59,
      ),
      CityModel(
        id: '2',
        slug: 'rabat',
        nameEn: 'Rabat',
        nameFr: 'Rabat',
        nameAr: 'الرباط',
        latitude: 34.02,
        longitude: -6.83,
      ),
    ];

    test('matches English name', () {
      expect(findCityByName(cities, 'Casablanca')?.slug, 'casablanca');
    });

    test('matches slug', () {
      expect(findCityByName(cities, 'rabat')?.nameEn, 'Rabat');
    });

    test('returns null when city is unknown', () {
      expect(findCityByName(cities, 'Marrakech'), isNull);
    });
  });
}
