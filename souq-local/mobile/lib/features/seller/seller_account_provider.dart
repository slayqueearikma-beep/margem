import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';

/// Loads and caches the authenticated seller's profile + dashboard stats.
final sellerAccountProvider = FutureProvider.autoDispose<SellerAccountData>((ref) async {
  final session = ref.watch(userSessionProvider);
  if (session == null || session.accountType != AccountType.seller) {
    throw ApiException('Seller session required');
  }

  final api = apiServiceProvider;
  final profile = await api.fetchMySeller();
  final stats = await api.fetchMySellerDashboard();

  final storage = ref.read(appStorageProvider);
  if (storage != null) {
    final updated = session.copyWith(
      sellerId: profile.id,
      businessName: profile.businessName,
      city: profile.city,
    );
    await storage.saveSession(updated);
    ref.read(userSessionProvider.notifier).state = updated;
  }

  return SellerAccountData(profile: profile, stats: stats);
});

class SellerAccountData {
  const SellerAccountData({required this.profile, required this.stats});

  final SellerModel profile;
  final SellerDashboardStats stats;
}
