import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_storage.dart';

const _marketingKey = 'privacy_marketing_opt_in';
const _personalizedRecsKey = 'privacy_personalized_recommendations';

class PrivacyPreferences {
  PrivacyPreferences(this._prefs);

  final SharedPreferences _prefs;

  bool get marketingOptIn => _prefs.getBool(_marketingKey) ?? false;

  bool get personalizedRecommendations =>
      _prefs.getBool(_personalizedRecsKey) ?? false;

  Future<void> setMarketingOptIn(bool value) =>
      _prefs.setBool(_marketingKey, value);

  Future<void> setPersonalizedRecommendations(bool value) =>
      _prefs.setBool(_personalizedRecsKey, value);
}

final privacyPreferencesProvider = Provider<PrivacyPreferences?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.maybeWhen(data: PrivacyPreferences.new, orElse: () => null);
});
