import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.apiBaseUrl}$path').replace(queryParameters: query);
  }

  Future<List<SellerModel>> fetchSellers({
    String? city,
    String? category,
    String? query,
  }) async {
    final params = <String, String>{};
    if (city != null && city.isNotEmpty) params['city'] = city;
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (query != null && query.isNotEmpty) params['q'] = query;

    final response = await _client.get(_uri('/sellers', params.isEmpty ? null : params));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => SellerModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SellerModel> fetchSeller(String id) async {
    final response = await _client.get(_uri('/sellers/$id'));
    _ensureSuccess(response);
    return SellerModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<MapPinModel>> fetchMapPins({String? city, String? category}) async {
    final params = <String, String>{};
    if (city != null && city.isNotEmpty) params['city'] = city;
    if (category != null && category.isNotEmpty) params['category'] = category;

    final response = await _client.get(_uri('/sellers/map', params.isEmpty ? null : params));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => MapPinModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CategoryModel>> fetchCategories() async {
    final response = await _client.get(_uri('/categories'));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<WarningZoneModel>> fetchWarningZones({String? city}) async {
    final params = city != null ? {'city': city} : null;
    final response = await _client.get(_uri('/warning-zones', params));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => WarningZoneModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ReviewModel>> fetchReviews(String sellerId) async {
    final response = await _client.get(_uri('/sellers/$sellerId/reviews'));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => ReviewModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> submitReview(String sellerId, {required int rating, String comment = ''}) async {
    final response = await _client.post(
      _uri('/sellers/$sellerId/reviews'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'rating': rating, 'comment': comment}),
    );
    _ensureSuccess(response);
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw ApiException(
      'Request failed (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }
}

final apiServiceProvider = ApiService();
