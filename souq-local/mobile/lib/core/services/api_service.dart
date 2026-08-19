import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/auth_models.dart';
import '../models/bundle_models.dart';
import '../models/city_model.dart';
import '../models/community_models.dart';
import '../models/marketplace_community_models.dart';
import '../models/models.dart';
import 'secure_http_client.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class SignupOtpSendResult {
  SignupOtpSendResult({
    required this.channel,
    required this.destinationMasked,
  });

  final String channel;
  final String destinationMasked;

  factory SignupOtpSendResult.fromJson(Map<String, dynamic> json) {
    return SignupOtpSendResult(
      channel: json['channel'] as String,
      destinationMasked: json['destination_masked'] as String,
    );
  }
}

typedef TokenRefreshCallback = Future<bool?> Function();
typedef SessionExpiredCallback = Future<void> Function();

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? createSecureHttpClient();

  static const _requestTimeout = Duration(seconds: 15);
  static const _submitTimeout = Duration(seconds: 25);

  final http.Client _client;

  String? Function()? tokenProvider;
  TokenRefreshCallback? onTokenRefresh;
  SessionExpiredCallback? onSessionExpired;

  bool _refreshInProgress = false;

  Map<String, String> get _authHeaders {
    final token = tokenProvider?.call();
    if (token == null || token.isEmpty) return {};
    return {'Authorization': 'Bearer $token'};
  }

  /// Reusable bearer headers for authenticated non-JSON uploads.
  Map<String, String> get authHeaders => Map.unmodifiable(_authHeaders);

  Map<String, String> _jsonHeaders({bool auth = false}) {
    return {
      'Content-Type': 'application/json',
      if (auth) ..._authHeaders,
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.apiBaseUrl}$path')
        .replace(queryParameters: query);
  }

  Future<void> checkHealth() async {
    final response = await _get(_uri('/health'));
    _ensureSuccess(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['database'] == 'error') {
      throw ApiException('API database is unavailable');
    }
  }

  Future<SignupOtpSendResult> sendSignupOtp({
    required String email,
    required String phone,
    required String channel,
  }) async {
    final response = await postJson('/auth/signup/otp/send', {
      'email': email,
      'phone': phone,
      'channel': channel,
    });
    return SignupOtpSendResult.fromJson(response);
  }

  Future<String> verifySignupOtp({
    required String email,
    required String code,
    required String channel,
  }) async {
    final response = await postJson('/auth/signup/otp/verify', {
      'email': email,
      'code': code,
      'channel': channel,
    });
    return response['signup_proof'] as String;
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final response = await _request(
      () => _post(
        _uri(path),
        headers: _jsonHeaders(auth: auth),
        body: jsonEncode(body),
      ),
      auth: auth,
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final response = await _request(
      () => _client.patch(
        _uri(path),
        headers: _jsonHeaders(auth: auth),
        body: jsonEncode(body),
      ),
      auth: auth,
    );
    _ensureSuccess(response);
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final response = await _request(
      () => _client.put(
        _uri(path),
        headers: _jsonHeaders(auth: auth),
        body: jsonEncode(body),
      ),
      auth: auth,
    );
    _ensureSuccess(response);
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getJson(String path, {bool auth = false}) async {
    final response = await _request(
      () => _get(_uri(path), headers: auth ? _authHeaders : null),
      auth: auth,
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getJsonList(String path, {bool auth = false}) async {
    final response = await _request(
      () => _get(_uri(path), headers: auth ? _authHeaders : null),
      auth: auth,
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<void> deleteJson(String path, Map<String, dynamic> body,
      {bool auth = false}) async {
    final response = await _request(
      () => _client.delete(
        _uri(path),
        headers: _jsonHeaders(auth: auth),
        body: jsonEncode(body),
      ),
      auth: auth,
    );
    _ensureSuccess(response);
  }

  Future<void> deletePath(String path, {bool auth = false}) async {
    final response = await _request(
      () => _client.delete(
        _uri(path),
        headers: auth ? _jsonHeaders(auth: true) : _jsonHeaders(),
      ),
      auth: auth,
    );
    _ensureSuccess(response);
  }

  Future<void> postVoid(String path, Map<String, dynamic> body,
      {bool auth = false}) async {
    final response = await _request(
      () => _post(
        _uri(path),
        headers: _jsonHeaders(auth: auth),
        body: jsonEncode(body),
      ),
      auth: auth,
    );
    _ensureSuccess(response);
  }

  Future<Map<String, dynamic>> postEmpty(String path,
      {bool auth = false}) async {
    final response = await _request(
      () => _post(
        _uri(path),
        headers: _jsonHeaders(auth: auth),
      ),
      auth: auth,
    );
    _ensureSuccess(response);
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) {
    return _send(() => _client.get(uri, headers: headers));
  }

  Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _send(() => _client.post(uri, headers: headers, body: body));
  }

  Future<http.Response> _put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _send(() => _client.put(uri, headers: headers, body: body));
  }

  Future<http.Response> _request(
    Future<http.Response> Function() send, {
    required bool auth,
  }) async {
    var response = await _send(send);
    if (auth &&
        response.statusCode == 401 &&
        onTokenRefresh != null &&
        !_refreshInProgress) {
      _refreshInProgress = true;
      try {
        final refreshed = await onTokenRefresh!();
        if (refreshed == true) {
          response = await _send(send);
        } else if (refreshed == false && onSessionExpired != null) {
          await onSessionExpired!();
        }
      } finally {
        _refreshInProgress = false;
      }
    }
    return response;
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    const maxAttempts = 3;
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        final response = await request().timeout(_requestTimeout);
        if (attempt < maxAttempts &&
            (response.statusCode == 502 ||
                response.statusCode == 503 ||
                response.statusCode == 504)) {
          await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
          continue;
        }
        return response;
      } on TimeoutException {
        if (attempt >= maxAttempts) {
          throw ApiException(_connectionErrorMessage);
        }
        await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
      } on SocketException {
        if (attempt >= maxAttempts) {
          throw ApiException(_connectionErrorMessage);
        }
        await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
      } on http.ClientException {
        if (attempt >= maxAttempts) {
          throw ApiException(_connectionErrorMessage);
        }
        await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
      } on ApiException {
        rethrow;
      } on Object {
        if (attempt >= maxAttempts) {
          throw ApiException(_connectionErrorMessage);
        }
        await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
      }
    }
  }

  Future<T> runSubmit<T>(Future<T> Function() action) {
    return action().timeout(
      _submitTimeout,
      onTimeout: () => throw ApiException(
        'Request timed out after ${_submitTimeout.inSeconds}s.\n$_connectionErrorMessage',
      ),
    );
  }

  String get _connectionErrorMessage {
    // Never surface internal API host/IP in release or production builds.
    if (AppConfig.isProduction || kReleaseMode) {
      return 'Cannot reach the server. Check your internet connection and try again.';
    }
    final base = AppConfig.apiBaseUrl;
    final tunnelHint = base.contains('trycloudflare.com')
        ? '\n\nCloudflare quick tunnels expire when you stop cloudflared. '
            'Restart the tunnel and update API_BASE_URL, or use your laptop IP:\n'
            'flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000'
        : '';
    final portTip = RegExp(r':\d+$').hasMatch(base)
        ? ''
        : '\nTip: API_BASE_URL must include a colon before the port, e.g. http://192.168.1.10:8000';
    return 'Cannot reach the API at $base. Check your network connection and API_BASE_URL.$portTip$tunnelHint';
  }

  Future<SellerModel> createSeller(SellerCreatePayload payload) async {
    final data = await postJson('/sellers', payload.toJson(), auth: true);
    return SellerModel.fromJson(data);
  }

  Future<SellerModel> fetchMySeller() async {
    final data = await getJson('/sellers/me', auth: true);
    return SellerModel.fromJson(data);
  }

  Future<SellerDashboardStats> fetchMySellerDashboard() async {
    final data = await getJson('/sellers/me/dashboard', auth: true);
    return SellerDashboardStats.fromJson(data);
  }

  Future<SellerModel> updateSeller(
      String sellerId, SellerUpdatePayload payload) async {
    final data =
        await patchJson('/sellers/$sellerId', payload.toJson(), auth: true);
    return SellerModel.fromJson(data);
  }

  Future<ProductModel> addProduct(
      String sellerId, ProductCreatePayload payload) async {
    final data = await postJson('/sellers/$sellerId/products', payload.toJson(),
        auth: true);
    return ProductModel.fromJson(data);
  }

  Future<ProductModel> updateProduct(
    String sellerId,
    String productId,
    ProductUpdatePayload payload,
  ) async {
    final data = await patchJson(
      '/sellers/$sellerId/products/$productId',
      payload.toJson(),
      auth: true,
    );
    return ProductModel.fromJson(data);
  }

  Future<void> deleteProduct(String sellerId, String productId) async {
    await deletePath('/sellers/$sellerId/products/$productId', auth: true);
  }

  Future<ServiceModel> addService(
    String sellerId,
    ServiceCreatePayload payload,
  ) async {
    final data = await postJson('/sellers/$sellerId/services', payload.toJson(), auth: true);
    return ServiceModel.fromJson(data);
  }

  Future<ServiceModel> updateService(
    String sellerId,
    String serviceId,
    ServiceUpdatePayload payload,
  ) async {
    final data = await patchJson(
      '/sellers/$sellerId/services/$serviceId',
      payload.toJson(),
      auth: true,
    );
    return ServiceModel.fromJson(data);
  }

  Future<void> deleteService(String sellerId, String serviceId) async {
    await deletePath('/sellers/$sellerId/services/$serviceId', auth: true);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _request(
      () => _post(
        _uri('/auth/me/password'),
        headers: _jsonHeaders(auth: true),
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      ),
      auth: true,
    );
    _ensureSuccess(response);
  }

  Future<Map<String, dynamic>> exportMyData() async {
    return getJson('/auth/me/export', auth: true);
  }

  Future<void> updateProfilePhoto(String profilePhotoUrl) async {
    await putJson(
      '/auth/me/profile-photo',
      {'profile_photo_url': profilePhotoUrl},
      auth: true,
    );
  }

  Future<void> deleteProfilePhoto() async {
    await deletePath('/auth/me/profile-photo', auth: true);
  }

  Future<void> updatePrivacyConsent({
    required String consentType,
    required bool granted,
    String language = 'en',
  }) async {
    final response = await _request(
      () => _put(
        _uri('/privacy/consents/$consentType'),
        headers: _jsonHeaders(auth: true),
        body: jsonEncode({'granted': granted, 'language': language}),
      ),
      auth: true,
    );
    _ensureSuccess(response);
  }

  Future<Map<String, dynamic>> submitPrivacyRequest({
    required String requestType,
    String details = '',
  }) async {
    final response = await _request(
      () => _post(
        _uri('/privacy/requests'),
        headers: _jsonHeaders(auth: true),
        body: jsonEncode({'request_type': requestType, 'details': details}),
      ),
      auth: true,
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchPrivacyRequests() async {
    final data = await getJsonList('/privacy/requests', auth: true);
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<AuthDeviceSession>> fetchAuthSessions() async {
    final data = await getJsonList('/auth/sessions', auth: true);
    return data
        .map((item) => AuthDeviceSession.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> revokeAuthSession(String sessionId) {
    return deletePath('/auth/sessions/$sessionId', auth: true);
  }

  Future<String?> categoryIdForSlug(String slug, {String? marketplace}) async {
    final categories = marketplace != null && marketplace.isNotEmpty
        ? await fetchMarketplaceCategories(marketplace)
        : await fetchCategories();
    for (final cat in categories) {
      if (cat.slug == slug) return cat.id;
    }
    return null;
  }

  Future<List<MarketplaceVenueModel>> fetchMarketplaces({String? city}) async {
    final params = <String, String>{'active_only': 'true'};
    if (city != null && city.isNotEmpty) params['city'] = city;
    final response = await _get(_uri('/marketplaces', params));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => MarketplaceVenueModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CategoryModel>> fetchMarketplaceCategories(String marketplaceSlug) async {
    final response = await _get(
      _uri('/marketplaces/$marketplaceSlug/categories', {'active_only': 'true'}),
    );
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SellerModel>> fetchSellers({
    String? city,
    String? category,
    String? marketplace,
    String? query,
  }) async {
    final params = <String, String>{};
    if (city != null && city.isNotEmpty) params['city'] = city;
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (marketplace != null && marketplace.isNotEmpty) {
      params['marketplace'] = marketplace;
    }
    if (query != null && query.isNotEmpty) params['q'] = query;

    final response = await _request(
      () => _get(_uri('/sellers', params.isEmpty ? null : params),
          headers: _authHeaders),
      auth: _authHeaders.isNotEmpty,
    );
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => SellerModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MarketplaceSearchPage> searchMarketplace({
    required String query,
    required String mode,
    String? category,
    String? marketplace,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    bool? deliveryAvailable,
    bool? pickupOnly,
    String sort = 'relevance',
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      return await _searchMarketplaceRequest(
        query: query,
        mode: _normalizeSearchMode(mode),
        category: category,
        marketplace: marketplace,
        minPrice: minPrice,
        maxPrice: maxPrice,
        minRating: minRating,
        deliveryAvailable: deliveryAvailable,
        pickupOnly: pickupOnly,
        sort: sort,
        offset: offset,
        limit: limit,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 422 && mode != 'all') {
        final fallbackMode = _legacySearchMode(mode);
        if (fallbackMode != mode) {
          final page = await _searchMarketplaceRequest(
            query: query,
            mode: fallbackMode,
            category: category,
            marketplace: marketplace,
            minPrice: minPrice,
            maxPrice: maxPrice,
            minRating: minRating,
            deliveryAvailable: deliveryAvailable,
            pickupOnly: pickupOnly,
            sort: sort,
            offset: offset,
            limit: limit,
          );
          return _filterSearchPage(page, mode);
        }
      }
      rethrow;
    }
  }

  String _normalizeSearchMode(String mode) {
    return switch (mode) {
      'providers' => 'sellers',
      _ => mode,
    };
  }

  String _legacySearchMode(String mode) {
    return switch (mode) {
      'providers' => 'sellers',
      'services' => 'all',
      _ => 'all',
    };
  }

  MarketplaceSearchPage _filterSearchPage(MarketplaceSearchPage page, String mode) {
    return switch (mode) {
      'services' => MarketplaceSearchPage(
          products: const [],
          services: page.services,
          sellers: const [],
          totalProducts: 0,
          totalServices: page.services.length,
          totalSellers: 0,
          limit: page.limit,
          offset: page.offset,
          hasMore: page.hasMore,
        ),
      'providers' => MarketplaceSearchPage(
          products: const [],
          services: const [],
          sellers: page.sellers,
          totalProducts: 0,
          totalServices: 0,
          totalSellers: page.sellers.length,
          limit: page.limit,
          offset: page.offset,
          hasMore: page.hasMore,
        ),
      _ => page,
    };
  }

  Future<MarketplaceSearchPage> _searchMarketplaceRequest({
    required String query,
    required String mode,
    String? category,
    String? marketplace,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    bool? deliveryAvailable,
    bool? pickupOnly,
    String sort = 'relevance',
    int offset = 0,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'q': query,
      'mode': mode,
      'sort': sort,
      'offset': '$offset',
      'limit': '$limit',
      if (category != null && category.isNotEmpty) 'category': category,
      if (marketplace != null && marketplace.isNotEmpty) 'marketplace': marketplace,
      if (minPrice != null) 'min_price': '$minPrice',
      if (maxPrice != null) 'max_price': '$maxPrice',
      if (minRating != null) 'min_rating': '$minRating',
      if (deliveryAvailable == true) 'delivery_available': 'true',
      if (pickupOnly == true) 'pickup_only': 'true',
    };
    final response = await _request(
      () => _get(_uri('/search', params), headers: _authHeaders),
      auth: _authHeaders.isNotEmpty,
    );
    _ensureSuccess(response);
    return MarketplaceSearchPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SellerModel> fetchSeller(String id, {bool auth = false}) async {
    final response = await _request(
      () => _get(_uri('/sellers/$id'), headers: auth ? _authHeaders : null),
      auth: auth,
    );
    _ensureSuccess(response);
    return SellerModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<MapPinModel>> fetchMapPins({
    String? city,
    String? category,
    String? marketplace,
  }) async {
    final params = <String, String>{};
    if (city != null && city.isNotEmpty) params['city'] = city;
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (marketplace != null && marketplace.isNotEmpty) {
      params['marketplace'] = marketplace;
    }

    final response =
        await _get(_uri('/sellers/map', params.isEmpty ? null : params));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => MapPinModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CategoryModel>> fetchCategories() async {
    final response = await _get(_uri('/categories'));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CityModel>> fetchCities({String country = 'MA'}) async {
    final response = await _get(_uri('/geography/cities', {'country': country}));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? const [];
    return items
        .map((e) => CityModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<WarningZoneModel>> fetchWarningZones({String? city}) async {
    final params = city != null ? {'city': city} : null;
    final response = await _get(_uri('/warning-zones', params));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => WarningZoneModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ReviewModel>> fetchReviews(String sellerId) async {
    final response = await _get(_uri('/sellers/$sellerId/reviews'));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ReviewEligibilityModel> fetchReviewEligibility(String sellerId) async {
    final response = await _request(
      () => _get(
        _uri('/sellers/$sellerId/reviews/eligibility'),
        headers: _jsonHeaders(auth: true),
      ),
      auth: true,
    );
    _ensureSuccess(response);
    return ReviewEligibilityModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<ReviewModel> submitReview(
    String sellerId, {
    required int productQuality,
    required int customerService,
    required int communication,
    required int trustworthiness,
    String comment = '',
  }) async {
    final response = await _request(
      () => _post(
        _uri('/sellers/$sellerId/reviews'),
        headers: _jsonHeaders(auth: true),
        body: jsonEncode({
          'product_quality': productQuality,
          'customer_service': customerService,
          'communication': communication,
          'trustworthiness': trustworthiness,
          'comment': comment,
        }),
      ),
      auth: true,
    );
    _ensureSuccess(response);
    return ReviewModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<FavoriteItemModel>> fetchFavorites() async {
    final data = await getJsonList('/favorites', auth: true);
    return data
        .map((item) => FavoriteItemModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<FavoriteItemModel> addFavoriteProduct(String productId) async {
    final data = await postEmpty('/favorites/products/$productId', auth: true);
    return FavoriteItemModel.fromJson(data);
  }

  Future<void> removeFavoriteProduct(String productId) {
    return deletePath('/favorites/products/$productId', auth: true);
  }

  Future<FavoriteItemModel> addFavoriteSeller(String sellerId) async {
    final data = await postEmpty('/favorites/sellers/$sellerId', auth: true);
    return FavoriteItemModel.fromJson(data);
  }

  Future<void> removeFavoriteSeller(String sellerId) {
    return deletePath('/favorites/sellers/$sellerId', auth: true);
  }

  Future<List<FavoriteItemModel>> migrateGuestFavorites(
      List<Map<String, dynamic>> items) async {
    final response = await _request(
      () => _post(
        _uri('/favorites/migrate-guest'),
        headers: _jsonHeaders(auth: true),
        body: jsonEncode({'items': items}),
      ),
      auth: true,
    );
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => FavoriteItemModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SellerFollowModel> followSeller(String sellerId) async {
    final data = await postEmpty('/follows/sellers/$sellerId', auth: true);
    return SellerFollowModel.fromJson(data);
  }

  Future<void> unfollowSeller(String sellerId) {
    return deletePath('/follows/sellers/$sellerId', auth: true);
  }

  Future<List<SellerFollowModel>> listFollows() async {
    final data = await getJsonList('/follows', auth: true);
    return data
        .map((item) => SellerFollowModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> createContactEvent({
    required String sellerId,
    required String channel,
  }) {
    return postVoid(
      '/contact-events',
      {'seller_id': sellerId, 'channel': channel},
      auth: true,
    );
  }

  Future<void> createReport({
    String? sellerId,
    String? productId,
    String? reportedUserId,
    required String reason,
    String details = '',
  }) {
    return postVoid(
      '/reports',
      {
        if (sellerId != null) 'seller_id': sellerId,
        if (productId != null) 'product_id': productId,
        if (reportedUserId != null) 'reported_user_id': reportedUserId,
        'reason': reason,
        'details': details,
      },
      auth: _authHeaders.isNotEmpty,
    );
  }

  Future<void> blockUser(String userId) {
    return postVoid('/users/block', {'user_id': userId}, auth: true);
  }

  Future<void> unblockUser(String userId) {
    return deletePath('/users/block/$userId', auth: true);
  }

  Future<void> trackRecentlyViewed({String? sellerId, String? productId}) {
    final params = <String, String>{
      if (sellerId != null) 'seller_id': sellerId,
      if (productId != null) 'product_id': productId,
    };
    return _request(
      () => _post(
        _uri('/recently-viewed', params),
        headers: _jsonHeaders(auth: true),
      ),
      auth: true,
    ).then(_ensureSuccess);
  }

  Future<SellerAnalyticsModel> fetchSellerAnalytics() async {
    final data = await getJson('/seller/analytics', auth: true);
    return SellerAnalyticsModel.fromJson(data);
  }

  Future<List<AppNotificationModel>> fetchNotifications() async {
    final data = await getJsonList('/notifications', auth: true);
    return data
        .map((item) =>
            AppNotificationModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> markNotificationRead(String id) {
    return postVoid('/notifications/$id/read', const {}, auth: true);
  }

  Future<void> markAllNotificationsRead() {
    return postVoid('/notifications/read-all', const {}, auth: true);
  }

  Future<List<ConversationModel>> fetchConversations() async {
    final data = await getJsonList('/messages/conversations', auth: true);
    return data
        .map((item) => ConversationModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ChatMessageModel>> fetchConversationMessages(
      String conversationId) async {
    final data = await getJsonList(
      '/messages/conversations/$conversationId',
      auth: true,
    );
    return data
        .map((item) => ChatMessageModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessageModel> replyToConversation(
    String conversationId,
    String body,
  ) async {
    final data = await postJson(
      '/messages/conversations/$conversationId',
      {'body': body},
      auth: true,
    );
    return ChatMessageModel.fromJson(data);
  }

  Future<ChatMessageModel> startConversationWithSeller(
    String sellerId,
    String body,
  ) async {
    final data = await postJson(
      '/messages/sellers/$sellerId',
      {'body': body},
      auth: true,
    );
    return ChatMessageModel.fromJson(data);
  }

  /// Opens or resumes a storefront conversation without sending a message.
  Future<ConversationModel> openSellerConversation(String sellerId) async {
    final data = await postJson(
      '/messages/sellers/$sellerId/open',
      const {},
      auth: true,
    );
    return ConversationModel.fromJson(data);
  }

  Future<ChatMessageModel> startConversationWithUser(
    String userId,
    String body,
  ) async {
    final data = await postJson(
      '/messages/users/$userId',
      {'body': body},
      auth: true,
    );
    return ChatMessageModel.fromJson(data);
  }

  // ——— City community chat ———

  Future<List<CommunityCityModel>> fetchCommunityCities({bool auth = false}) async {
    final data = await getJsonList('/community/cities', auth: auth);
    return data
        .map((item) =>
            CommunityCityModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CommunityDiscoverModel> fetchCommunityDiscover({bool auth = false}) async {
    final data = await getJson('/community/discover', auth: auth);
    return CommunityDiscoverModel.fromJson(data);
  }

  Future<CommunityCityModel> fetchCommunityCity(String slug, {bool auth = false}) async {
    final data = await getJson('/community/cities/$slug', auth: auth);
    return CommunityCityModel.fromJson(data);
  }

  Future<CommunityCityModel> joinCommunityCity(
    String slug, {
    bool isHomeCity = false,
  }) async {
    final data = await postJson(
      '/community/cities/$slug/join',
      {'is_home_city': isHomeCity},
      auth: true,
    );
    return CommunityCityModel.fromJson(data);
  }

  Future<List<CommunityChannelModel>> fetchCommunityChannels(
    String citySlug, {
    bool auth = false,
  }) async {
    final data =
        await getJsonList('/community/cities/$citySlug/channels', auth: auth);
    return data
        .map((item) =>
            CommunityChannelModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<CommunityMessageModel>> fetchCommunityMessages(
    String channelId, {
    String? beforeId,
    String? query,
    bool verifiedOnly = false,
    bool trustedOnly = false,
  }) async {
    final queryParams = <String, String>{
      if (beforeId != null) 'before_id': beforeId,
      if (query != null && query.isNotEmpty) 'q': query,
      if (verifiedOnly) 'verified_only': 'true',
      if (trustedOnly) 'trusted_only': 'true',
    };
    final data = await getJsonList(
      '/community/channels/$channelId/messages${queryParams.isEmpty ? '' : '?${Uri(queryParameters: queryParams).query}'}',
      auth: true,
    );
    return data
        .map((item) =>
            CommunityMessageModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<String> fetchCommunityWsTicket(String channelId) async {
    final data = await postJson(
      '/community/channels/$channelId/ws-ticket',
      {},
      auth: true,
    );
    return data['ticket'] as String;
  }

  Future<CommunityMessageModel> postCommunityMessage({
    required String channelId,
    required String body,
    String? replyToId,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final data = await postJson(
      '/community/channels/$channelId/messages',
      {
        'body': body,
        if (replyToId != null) 'reply_to_id': replyToId,
        if (attachments.isNotEmpty) 'attachments': attachments,
      },
      auth: true,
    );
    return CommunityMessageModel.fromJson(data);
  }

  Future<CommunityMessageModel> editCommunityMessage(
    String messageId,
    String body,
  ) async {
    final data = await patchJson(
      '/community/messages/$messageId',
      {'body': body},
      auth: true,
    );
    return CommunityMessageModel.fromJson(data);
  }

  Future<void> deleteCommunityMessage(String messageId) {
    return deletePath('/community/messages/$messageId', auth: true);
  }

  Future<List<CommunityReactionModel>> reactCommunityMessage(
    String messageId,
    String emoji,
  ) async {
    final response = await _request(
      () => _post(
        _uri('/community/messages/$messageId/reactions'),
        headers: _jsonHeaders(auth: true),
        body: jsonEncode({'emoji': emoji}),
      ),
      auth: true,
    );
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => CommunityReactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> reportCommunityMessage(
    String messageId, {
    required String reason,
    String details = '',
  }) {
    return postVoid(
      '/community/messages/$messageId/report',
      {'reason': reason, 'details': details},
      auth: true,
    );
  }

  Future<void> blockCommunityUser(String userId) {
    return postVoid('/community/users/block', {'user_id': userId}, auth: true);
  }

  Future<void> muteCommunityUser(String userId) {
    return postVoid('/community/users/mute', {'user_id': userId}, auth: true);
  }

  // ——— Marketplace community (per-venue hubs) ———

  Future<MarketplaceCommunityHubModel> fetchMarketplaceCommunityHub(
    String marketplaceSlug, {
    bool auth = false,
  }) async {
    final data = await getJson('/marketplaces/$marketplaceSlug/community', auth: auth);
    return MarketplaceCommunityHubModel.fromJson(data);
  }

  Future<MarketplaceCommunityHubModel> joinMarketplaceCommunity(
    String marketplaceSlug,
  ) async {
    final data = await postJson(
      '/marketplaces/$marketplaceSlug/community/join',
      {},
      auth: true,
    );
    return MarketplaceCommunityHubModel.fromJson(data);
  }

  Future<List<MarketplaceCommunityChannelModel>> fetchMarketplaceCommunityChannels(
    String marketplaceSlug, {
    bool auth = false,
  }) async {
    final data = await getJsonList(
      '/marketplaces/$marketplaceSlug/community/channels',
      auth: auth,
    );
    return data
        .map((item) =>
            MarketplaceCommunityChannelModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<MarketplaceCommunityMessageModel>> fetchMarketplaceCommunityMessages(
    String channelId, {
    String? beforeId,
  }) async {
    final queryParams = <String, String>{if (beforeId != null) 'before_id': beforeId};
    final path = queryParams.isEmpty
        ? '/marketplaces/community/channels/$channelId/messages'
        : '/marketplaces/community/channels/$channelId/messages?${Uri(queryParameters: queryParams).query}';
    final data = await getJsonList(path, auth: true);
    return data
        .map((item) =>
            MarketplaceCommunityMessageModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<MarketplaceCommunityMessageModel> postMarketplaceCommunityMessage({
    required String channelId,
    required String body,
    String postType = 'general',
    String? replyToId,
  }) async {
    final data = await postJson(
      '/marketplaces/community/channels/$channelId/messages',
      {
        'body': body,
        'post_type': postType,
        if (replyToId != null) 'reply_to_id': replyToId,
      },
      auth: true,
    );
    return MarketplaceCommunityMessageModel.fromJson(data);
  }

  Future<void> reportMarketplaceCommunityMessage({
    required String messageId,
    required String reason,
    String details = '',
  }) {
    return postVoid(
      '/marketplaces/community/messages/$messageId/report',
      {'reason': reason, 'details': details},
      auth: true,
    );
  }

  Future<List<SubscriptionPlanModel>> fetchSubscriptionPlans() async {
    final data = await getJsonList('/subscriptions/plans');
    return data
        .map((item) =>
            SubscriptionPlanModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SubscriptionModel?> fetchMySubscription() async {
    final response = await _request(
      () => _get(_uri('/subscriptions/me'), headers: _authHeaders),
      auth: true,
    );
    _ensureSuccess(response);
    if (response.body.isEmpty || response.body == 'null') return null;
    return SubscriptionModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<SubscriptionModel> subscribe(String planCode) async {
    final data =
        await postEmpty('/subscriptions/subscribe/$planCode', auth: true);
    return SubscriptionModel.fromJson(data);
  }

  Future<BillingStatusModel> fetchBillingStatus() async {
    final data = await getJson('/subscriptions/billing/status', auth: false);
    return BillingStatusModel.fromJson(data);
  }

  Future<BillingCheckoutResult> checkoutSubscription(
    String planCode, {
    required bool subscriptionTermsAccepted,
    String acceptanceLanguage = 'en',
  }) async {
    final data = await postJson(
      '/subscriptions/checkout/$planCode',
      {
        'success_url': 'margem://premium/success',
        'cancel_url': 'margem://premium/cancel',
        'subscription_terms_accepted': subscriptionTermsAccepted,
        'acceptance_language': acceptanceLanguage,
      },
      auth: true,
    );
    return BillingCheckoutResult.fromJson(data);
  }

  Future<List<PlatformPaymentModel>> fetchMyPlatformPayments() async {
    final data = await getJsonList('/billing/payments/me', auth: true);
    return data
        .whereType<Map<String, dynamic>>()
        .map(PlatformPaymentModel.fromJson)
        .toList();
  }

  Future<PlatformPaymentModel> fetchPlatformPayment(String paymentId) async {
    final data = await getJson('/billing/payments/$paymentId', auth: true);
    return PlatformPaymentModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> requestPasswordReset(String email) {
    return postVoid('/auth/password-reset/request', {'email': email},
        auth: false);
  }

  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) {
    return postVoid(
      '/auth/password-reset/confirm',
      {'token': token, 'new_password': newPassword},
      auth: false,
    );
  }

  Future<void> requestEmailVerification() {
    return postVoid('/auth/verify-email/request', const {}, auth: true);
  }

  Future<void> confirmEmailVerification(String token) {
    return postVoid('/auth/verify-email/confirm', {'token': token},
        auth: false);
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw ApiException(
      _messageFromErrorResponse(response),
      statusCode: response.statusCode,
    );
  }

  String _messageFromErrorResponse(http.Response response) {
    if (response.statusCode == 429) {
      return 'Too many requests. Please wait about a minute and try again.';
    }
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final error = body['error'];
        if (error is String && error.isNotEmpty) {
          if (error.toLowerCase().contains('rate limit')) {
            return 'Too many requests. Please wait about a minute and try again.';
          }
          return error;
        }
        final detail = body['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        if (detail is List) {
          final messages = detail
              .map((item) {
                if (item is Map<String, dynamic>) {
                  final msg = item['msg']?.toString();
                  if (msg == null || msg.isEmpty) return null;
                  if (msg.contains('should match pattern') ||
                      msg.contains('validation error')) {
                    return null;
                  }
                  final loc = item['loc'];
                  if (loc is List && loc.isNotEmpty) {
                    return '${loc.last}: $msg';
                  }
                  return msg;
                }
                return item.toString();
              })
              .whereType<String>()
              .toList();
          if (messages.isNotEmpty) return messages.join('\n');
          return 'Request could not be processed.';
        }
      }
    } on Object {
      // Fall through.
    }
    return 'Request failed (${response.statusCode})';
  }

  Future<List<BundleTemplateModel>> fetchBundleTemplates({String? marketplace}) async {
    final params = marketplace != null && marketplace.isNotEmpty
        ? {'marketplace': marketplace}
        : null;
    final response = await _get(_uri('/bundles/templates', params));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => BundleTemplateModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BundleResolveResultModel> resolveBundle({
    required String marketplace,
    required List<BundleSlotTemplateModel> slots,
    String? templateSlug,
    double minSellerRating = 0,
  }) async {
    final response = await _post(
      _uri('/bundles/resolve'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'marketplace': marketplace,
        if (templateSlug != null) 'template_slug': templateSlug,
        'min_seller_rating': minSellerRating,
        'slots': slots.map((slot) => slot.toJson()).toList(),
      }),
    );
    _ensureSuccess(response);
    return BundleResolveResultModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

final apiServiceProvider = ApiService();
