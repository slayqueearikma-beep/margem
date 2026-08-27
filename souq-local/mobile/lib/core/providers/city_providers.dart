import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/app_config.dart';
import '../data/city_coordinates.dart';
import '../models/city_model.dart';
import '../services/api_service.dart';
import '../services/app_storage.dart';
import '../services/location_service.dart';

final citiesProvider = FutureProvider<List<CityModel>>((ref) async {
  return apiServiceProvider.fetchCities();
});

CityModel? findCityByName(List<CityModel> cities, String name) {
  final target = name.trim().toLowerCase();
  for (final city in cities) {
    if (city.nameEn.toLowerCase() == target ||
        city.slug == target ||
        city.nameFr.toLowerCase() == target ||
        city.nameAr == name.trim()) {
      return city;
    }
  }
  return null;
}

class BuyerCityNotifier extends StateNotifier<String> {
  BuyerCityNotifier(this._ref) : super(AppConfig.launchCity) {
    _initialize();
  }

  final Ref _ref;

  Future<void> _initialize() async {
    try {
      final cities = await _ref.read(citiesProvider.future);
      CityCoordinates.cacheCities(cities);
      final storage = _ref.read(appStorageProvider);
      final saved =
          storage?.getSelectedCity() ?? _ref.read(userSessionProvider)?.city;
      state = _resolveCityName(saved, cities);
    } on Object {
      // Keep launch city fallback when API is unavailable.
    }
  }

  String _resolveCityName(String? value, List<CityModel> cities) {
    // Casablanca-only launch: keep buyer discovery aligned with backend filters.
    return findCityByName(cities, AppConfig.launchCity)?.nameEn ?? AppConfig.launchCity;
  }

  Future<void> setCity(CityModel city) async {
    state = city.nameEn;
    final storage = _ref.read(appStorageProvider);
    await storage?.saveSelectedCity(city.nameEn);
    final session = _ref.read(userSessionProvider);
    if (session != null) {
      final updated = session.copyWith(city: city.nameEn);
      await storage?.saveSession(updated);
      _ref.read(userSessionProvider.notifier).state = updated;
    }
  }
}

final buyerCityProvider =
    StateNotifierProvider<BuyerCityNotifier, String>((ref) {
  return BuyerCityNotifier(ref);
});

final buyerCityModelProvider = Provider<CityModel?>((ref) {
  final name = ref.watch(buyerCityProvider);
  final cities = ref.watch(citiesProvider).valueOrNull ?? const <CityModel>[];
  return findCityByName(cities, name);
});

final buyerSearchLocationProvider =
    FutureProvider.autoDispose<LatLng>((ref) async {
  final position = await LocationService.getCurrentPosition();
  if (position != null) {
    return LatLng(position.latitude, position.longitude);
  }
  final city = ref.watch(buyerCityModelProvider);
  if (city != null) {
    return LatLng(city.latitude, city.longitude);
  }
  return CityCoordinates.centerFor(ref.watch(buyerCityProvider));
});
