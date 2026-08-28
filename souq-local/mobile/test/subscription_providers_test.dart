import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/models/models.dart';
import 'package:souq_local/core/providers/subscription_providers.dart';
import 'package:souq_local/core/services/app_storage.dart';

void main() {
  group('filterPlansForSession', () {
    final plans = <SubscriptionPlanModel>[
      const SubscriptionPlanModel(
        id: 'plan-buyer',
        code: 'buyer_premium',
        name: 'Dribex Plus',
        description: 'Buyer premium',
        priceMad: 49,
        billingPeriodDays: 30,
        features: ['priority_support'],
        isActive: true,
      ),
      const SubscriptionPlanModel(
        id: 'plan-seller',
        code: 'seller_pro',
        name: 'Dribex Pro',
        description: 'Seller premium',
        priceMad: 149,
        billingPeriodDays: 30,
        features: ['unlimited_videos'],
        isActive: true,
      ),
    ];

    test('plan display names are user-facing', () {
      expect(plans.first.displayName, 'Dribex Plus+');
      expect(plans.last.displayName, 'DriverPro');
    });

    test('buyer sees buyer plan only', () {
      const session = UserSession(
        name: 'Buyer',
        email: 'buyer@example.com',
        accountType: AccountType.buyer,
      );
      final filtered = filterPlansForSession(plans, session);
      expect(filtered.map((p) => p.code), ['buyer_premium']);
    });

    test('seller sees seller plan only', () {
      const session = UserSession(
        name: 'Seller',
        email: 'seller@example.com',
        accountType: AccountType.seller,
        sellerId: 'seller-1',
      );
      final filtered = filterPlansForSession(plans, session);
      expect(filtered.map((p) => p.code), ['seller_pro']);
    });

    test('guest sees all plans', () {
      const session = UserSession(
        name: 'Guest',
        email: '',
        accountType: AccountType.guest,
      );
      final filtered = filterPlansForSession(plans, session);
      expect(filtered.length, 2);
    });
  });
}
