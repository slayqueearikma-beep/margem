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

final subscriptionPlansProvider =
    FutureProvider.autoDispose<List<SubscriptionPlanModel>>((ref) {
  final session = ref.watch(userSessionProvider);
  final audience = _planAudienceForSession(session);
  return apiServiceProvider.fetchSubscriptionPlans(audience: audience);
});

final mySubscriptionProvider =
    FutureProvider.autoDispose<SubscriptionModel?>((ref) {
  final session = ref.watch(userSessionProvider);
  if (session == null || session.isGuest) return Future.value(null);
  return apiServiceProvider.fetchMySubscription();
});

final billingStatusProvider = FutureProvider.autoDispose<BillingStatusModel>((ref) {
  return apiServiceProvider.fetchBillingStatus();
});

final myPlatformPaymentsProvider =
    FutureProvider.autoDispose<List<PlatformPaymentModel>>((ref) {
  final session = ref.watch(userSessionProvider);
  if (session == null || session.isGuest) return Future.value(const []);
  return apiServiceProvider.fetchMyPlatformPayments();
});

String? _planAudienceForSession(UserSession? session) {
  if (session == null || session.isGuest) return null;
  if (session.accountType == AccountType.seller) return 'seller';
  if (session.accountType == AccountType.buyer) return 'buyer';
  return null;
}

List<SubscriptionPlanModel> filterPlansForSession(
  List<SubscriptionPlanModel> plans,
  UserSession? session,
) {
  if (session == null || session.isGuest) return plans;
  return plans.where((plan) {
    if (plan.code == 'seller_pro') {
      return session.accountType == AccountType.seller;
    }
    if (plan.code == 'buyer_premium') {
      return session.accountType == AccountType.buyer;
    }
    return true;
  }).toList();
}

void invalidateSubscriptionProviders(WidgetRef ref) {
  ref.invalidate(subscriptionPlansProvider);
  ref.invalidate(mySubscriptionProvider);
  ref.invalidate(myEntitlementsProvider);
  ref.invalidate(billingStatusProvider);
  ref.invalidate(myPlatformPaymentsProvider);
}

bool hasBuyerPremiumSubscription(SubscriptionModel? subscription) {
  if (subscription == null) return false;
  if (subscription.status != 'active') return false;
  return subscription.plan.code == 'buyer_premium';
}

bool hasPlusPlusEntitlement(EntitlementsBundleModel? entitlements) {
  return entitlements?.buyer.plusPlusActive ?? false;
}

bool hasPromotionalAdsSuppressed(EntitlementsBundleModel? entitlements) {
  return entitlements?.promotionalAdsSuppressed ?? false;
}

bool hasDriverProEntitlement(EntitlementsBundleModel? entitlements) {
  return entitlements?.seller?.driverProActive ?? false;
}
