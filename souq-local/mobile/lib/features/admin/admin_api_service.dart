import '../../core/services/api_service.dart';
import 'admin_models.dart';

/// HTTP client for MarGem administration endpoints (`/admin/*`).
class AdminApiService {
  AdminApiService(this._api);

  final ApiService _api;

  Future<StaffMe> fetchMe() async {
    final json = await _api.getJson('/admin/me', auth: true);
    return StaffMe.fromJson(json);
  }

  Future<AdminDashboard> fetchDashboard() async {
    final json = await _api.getJson('/admin/dashboard', auth: true);
    return AdminDashboard.fromJson(json);
  }

  Future<AdminUserPage> fetchUsers({
    String? query,
    String? status,
    String? role,
    int limit = 50,
    int offset = 0,
  }) async {
    final json = await _api.getJson(
      '/admin/users',
      auth: true,
      query: {
        if (query != null && query.isNotEmpty) 'q': query,
        if (status != null && status.isNotEmpty) 'status': status,
        if (role != null && role.isNotEmpty) 'role': role,
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    return AdminUserPage.fromJson(json);
  }

  Future<AdminUserDetail> fetchUser(String userId) async {
    final json = await _api.getJson('/admin/users/$userId', auth: true);
    return AdminUserDetail.fromJson(json);
  }

  Future<void> setUserStatus(String userId, String status) async {
    await _api.patchJson(
      '/admin/users/$userId/status',
      {},
      auth: true,
      query: {'status': status},
    );
  }

  Future<void> triggerPasswordReset(String userId) async {
    await _api.postVoid('/admin/users/$userId/reset-password', {}, auth: true);
  }

  Future<List<AdminSessionInfo>> fetchUserSessions(String userId) async {
    final list = await _api.getJsonList('/admin/users/$userId/sessions', auth: true);
    return list
        .map((e) => AdminSessionInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AdminSellerPage> fetchSellers({
    String? query,
    String? verification,
    int limit = 50,
    int offset = 0,
  }) async {
    final json = await _api.getJson(
      '/admin/sellers',
      auth: true,
      query: {
        if (query != null && query.isNotEmpty) 'q': query,
        if (verification != null && verification.isNotEmpty)
          'verification': verification,
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    return AdminSellerPage.fromJson(
      json,
      (items) => items
          .map((e) => AdminSellerSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<AdminSellerPage> fetchPendingSellers({
    int limit = 50,
    int offset = 0,
  }) async {
    final json = await _api.getJson(
      '/admin/sellers/pending',
      auth: true,
      query: {
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    return AdminSellerPage.fromJson(
      json,
      (items) => items
          .map((e) => AdminSellerSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> verifySeller(String sellerId, {required bool approve}) async {
    await _api.postVoid(
      '/admin/sellers/$sellerId/verify',
      {},
      auth: true,
      query: {'approve': approve ? 'true' : 'false'},
    );
  }

  Future<void> setSellerActive(String sellerId, {required bool active}) async {
    await _api.patchJson(
      '/admin/sellers/$sellerId/active',
      {},
      auth: true,
      query: {'active': active ? 'true' : 'false'},
    );
  }

  Future<AdminProductPage> fetchProducts({
    String? query,
    bool? hidden,
    bool? featured,
    int limit = 50,
    int offset = 0,
  }) async {
    final json = await _api.getJson(
      '/admin/products',
      auth: true,
      query: {
        if (query != null && query.isNotEmpty) 'q': query,
        if (hidden != null) 'hidden': hidden.toString(),
        if (featured != null) 'featured': featured.toString(),
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    return AdminProductPage.fromJson(json);
  }

  Future<AdminProductSummary> moderateProduct(
    String productId, {
    bool? isHidden,
    bool? isFeatured,
    bool? isPaused,
    bool? isAvailable,
  }) async {
    final json = await _api.patchJson(
      '/admin/products/$productId',
      {
        if (isHidden != null) 'is_hidden': isHidden,
        if (isFeatured != null) 'is_featured': isFeatured,
        if (isPaused != null) 'is_paused': isPaused,
        if (isAvailable != null) 'is_available': isAvailable,
      },
      auth: true,
    );
    return AdminProductSummary.fromJson(json);
  }

  Future<AdminReportPage> fetchReports({
    String status = 'open',
    int limit = 50,
    int offset = 0,
  }) async {
    final json = await _api.getJson(
      '/admin/reports',
      auth: true,
      query: {
        'status': status,
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    return AdminReportPage.fromJson(json);
  }

  Future<void> updateReport(String reportId, String status, {String note = ''}) async {
    await _api.patchJson(
      '/admin/reports/$reportId',
      {'status': status, 'note': note},
      auth: true,
    );
  }

  Future<List<AdminCategoryItem>> fetchCategories() async {
    final list = await _api.getJsonList('/admin/categories', auth: true);
    return list
        .map((e) => AdminCategoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AdminCategoryItem> createCategory({
    required String slug,
    required String nameEn,
    String nameFr = '',
    String nameAr = '',
    String icon = 'store',
    String accentColor = '#5B6CFF',
    int sortOrder = 0,
  }) async {
    final json = await _api.postJson(
      '/admin/categories',
      {
        'slug': slug,
        'name_en': nameEn,
        'name_fr': nameFr,
        'name_ar': nameAr,
        'icon': icon,
        'accent_color': accentColor,
        'sort_order': sortOrder,
      },
      auth: true,
    );
    return AdminCategoryItem.fromJson(json);
  }

  Future<void> reorderCategories(List<String> orderedIds) async {
    await _api.postVoid(
      '/admin/categories/reorder',
      {'ordered_ids': orderedIds},
      auth: true,
    );
  }

  Future<void> revokeUserSessions(String userId) async {
    await _api.deletePath('/admin/users/$userId/sessions', auth: true);
  }

  Future<void> grantPremium(String userId, String planCode, int days) async {
    await _api.postJson(
      '/admin/users/$userId/premium',
      {'plan_code': planCode, 'days': days},
      auth: true,
    );
  }

  Future<void> revokePremium(String userId) async {
    await _api.deleteJson('/admin/users/$userId/premium', {}, auth: true);
  }

  Future<AdminAnalytics> fetchAnalytics() async {
    final json = await _api.getJson('/admin/analytics', auth: true);
    return AdminAnalytics.fromJson(json);
  }

  Future<int> sendAnnouncement({
    required String title,
    required String body,
    String audience = 'all',
  }) async {
    final data = await _api.postJson(
      '/admin/announcements',
      {'title': title, 'body': body, 'audience': audience},
      auth: true,
    );
    return (data['sent'] as num?)?.toInt() ?? 0;
  }

  Future<AdminAuditPage> fetchAuditLogs({
    String? action,
    int limit = 50,
    int offset = 0,
  }) async {
    final json = await _api.getJson(
      '/admin/audit-logs',
      auth: true,
      query: {
        if (action != null && action.isNotEmpty) 'action': action,
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    return AdminAuditPage.fromJson(json);
  }
}
