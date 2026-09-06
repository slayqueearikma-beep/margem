import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/city_model.dart';

/// City center coordinates — API-backed with Casablanca fallback.
class CityCoordinates {
  CityCoordinates._();

  static const LatLng casablanca = LatLng(33.5731, -7.5898);

  static final Map<String, LatLng> _byName = {
    'casablanca': casablanca,
  };

  static void cacheCities(List<CityModel> cities) {
    for (final city in cities) {
      final center = LatLng(city.latitude, city.longitude);
      _byName[city.slug] = center;
      _byName[city.nameEn.toLowerCase()] = center;
      if (city.nameFr.isNotEmpty) {
        _byName[city.nameFr.toLowerCase()] = center;
      }
      if (city.nameAr.isNotEmpty) {
        _byName[city.nameAr] = center;
      }
    }
  }

  static LatLng centerFor(String city) {
    final key = city.trim().toLowerCase();
    return _byName[key] ?? _byName[city.trim()] ?? casablanca;
  }
}
