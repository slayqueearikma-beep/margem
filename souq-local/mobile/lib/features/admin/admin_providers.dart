import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/api_service.dart';
import 'admin_api_service.dart';
import 'admin_models.dart';

final adminApiProvider = Provider<AdminApiService>(
  (ref) => AdminApiService(apiServiceProvider),
);

final staffMeProvider = FutureProvider<StaffMe>((ref) async {
  return ref.watch(adminApiProvider).fetchMe();
});

final adminDashboardProvider = FutureProvider<AdminDashboard>((ref) async {
  return ref.watch(adminApiProvider).fetchDashboard();
});

final adminAnalyticsProvider = FutureProvider<AdminAnalytics>((ref) async {
  return ref.watch(adminApiProvider).fetchAnalytics();
});

final adminUsersProvider =
    FutureProvider.family<AdminUserPage, AdminUserQuery>((ref, query) async {
  return ref.watch(adminApiProvider).fetchUsers(
        query: query.search,
        status: query.status,
        role: query.role,
        limit: query.limit,
        offset: query.offset,
      );
});

class AdminUserQuery {
  const AdminUserQuery({
    this.search,
    this.status,
    this.role,
    this.limit = 50,
    this.offset = 0,
  });

  final String? search;
  final String? status;
  final String? role;
  final int limit;
  final int offset;

  @override
  bool operator ==(Object other) =>
      other is AdminUserQuery &&
      other.search == search &&
      other.status == status &&
      other.role == role &&
      other.limit == limit &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(search, status, role, limit, offset);
}

final adminSellersProvider =
    FutureProvider.family<AdminSellerPage, String?>((ref, query) async {
  return ref.watch(adminApiProvider).fetchSellers(query: query);
});

final adminPendingSellersProvider =
    FutureProvider<AdminSellerPage>((ref) async {
  return ref.watch(adminApiProvider).fetchPendingSellers();
});

final adminProductsProvider =
    FutureProvider.family<AdminProductPage, String?>((ref, query) async {
  return ref.watch(adminApiProvider).fetchProducts(query: query);
});

final adminReportsProvider =
    FutureProvider.family<AdminReportPage, String>((ref, status) async {
  return ref.watch(adminApiProvider).fetchReports(status: status);
});

final adminCategoriesProvider = FutureProvider<List<AdminCategoryItem>>((ref) async {
  return ref.watch(adminApiProvider).fetchCategories();
});

final adminAuditProvider = FutureProvider<AdminAuditPage>((ref) async {
  return ref.watch(adminApiProvider).fetchAuditLogs();
});
