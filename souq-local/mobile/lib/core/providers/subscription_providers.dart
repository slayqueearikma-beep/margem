import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/app_storage.dart';

final myEntitlementsProvider =
    FutureProvider.autoDispose<EntitlementsBundleModel>((ref) {
  final session = ref.watch(userSessionProvider);
  if (session == null || session.isGuest) {
    return Future.value(
      const EntitlementsBundleModel(
        buyer: BuyerEntitlementsModel(),
      ),
    );
  }
  return apiServiceProvider.fetchEntitlements();
});

final monetizationStatusProvider =
    FutureProvider.autoDispose<MonetizationStatusModel>((ref) {
  return apiServiceProvider.fetchMonetizationStatus();
});

void invalidateEntitlementProviders(WidgetRef ref) {
  ref.invalidate(myEntitlementsProvider);
  ref.invalidate(monetizationStatusProvider);
}

bool hasPromotionalAdsSuppressed(EntitlementsBundleModel? entitlements) {
  return entitlements?.promotionalAdsSuppressed ?? false;
}

bool shouldShowPromotionalAds(EntitlementsBundleModel? entitlements) {
  if (entitlements == null) return true;
  return entitlements.adsEnabled && !entitlements.promotionalAdsSuppressed;
}
