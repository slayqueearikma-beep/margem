import '../../l10n/strings/app_strings.dart';

class CountryModel {
  const CountryModel({
    required this.id,
    required this.code,
    required this.nameEn,
    this.nameAr = '',
    this.nameFr = '',
    this.isActive = true,
  });

  final String id;
  final String code;
  final String nameEn;
  final String nameAr;
  final String nameFr;
  final bool isActive;

  factory CountryModel.fromJson(Map<String, dynamic> json) {
    return CountryModel(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      nameAr: json['name_ar'] as String? ?? '',
      nameFr: json['name_fr'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class CityModel {
  const CityModel({
    required this.id,
    required this.slug,
    required this.nameEn,
    this.nameAr = '',
    this.nameFr = '',
    this.region = '',
    required this.latitude,
    required this.longitude,
    this.isActive = true,
    this.sortOrder = 0,
    this.country,
  });

  final String id;
  final String slug;
  final String nameEn;
  final String nameAr;
  final String nameFr;
  final String region;
  final double latitude;
  final double longitude;
  final bool isActive;
  final int sortOrder;
  final CountryModel? country;

  String localizedName(String languageCode) {
    switch (languageCode) {
      case 'fr':
        return nameFr.isNotEmpty ? nameFr : nameEn;
      case 'ar':
        return nameAr.isNotEmpty ? nameAr : nameEn;
      default:
        return nameEn;
    }
  }

  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return nameEn.toLowerCase().contains(q) ||
        nameFr.toLowerCase().contains(q) ||
        nameAr.contains(query.trim()) ||
        slug.toLowerCase().contains(q);
  }

  factory CityModel.fromJson(Map<String, dynamic> json) {
    return CityModel(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      nameAr: json['name_ar'] as String? ?? '',
      nameFr: json['name_fr'] as String? ?? '',
      region: json['region'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      country: json['country'] is Map<String, dynamic>
          ? CountryModel.fromJson(json['country'] as Map<String, dynamic>)
          : null,
    );
  }
}
