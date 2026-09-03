import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../models/auth_models.dart';
import '../navigation/post_auth_navigation.dart';
import '../providers/subscription_providers.dart';
import '../services/api_service.dart';
import '../services/app_storage.dart';
import '../services/auth_service.dart';
import '../services/legal_acceptance_service.dart';
import '../../l10n/app_localizations.dart';

/// Shared post-authentication session setup used by email and Google sign-in.
Future<void> completeAuthenticatedSession({
  required WidgetRef ref,
  required AuthSession session,
  required AppStrings l10n,
  required void Function(String route) navigate,
  String? postAuthRouteOverride,
  bool markOnboardingComplete = false,
}) async {
  final auth = ref.read(authServiceProvider);
  final prefs = await ref.read(sharedPreferencesProvider.future);
  await auth.persistToken(prefs);

  final storage = ref.read(appStorageProvider);
  if (storage == null) {
    throw ApiException('App storage is not ready. Please restart the app.');
  }

  final existing = storage.getSession();
  var userSession = UserSession(
    name: session.user.displayName.isNotEmpty
        ? session.user.displayName
        : l10n.returningUser,
    email: session.user.email,
    accountType: session.user.canSell ? AccountType.seller : AccountType.buyer,
    city: AppConfig.launchCity,
    businessName: existing?.businessName,
    sellerId: existing?.sellerId,
  );

  if (session.user.canSell || session.user.hasSellerProfile) {
    try {
      final seller = await apiServiceProvider.fetchMySeller();
      userSession = userSession.copyWith(
        accountType: AccountType.seller,
        sellerId: seller.id,
        businessName: seller.businessName,
        city: seller.city,
      );
    } on ApiException {
      // Seller may still need to complete onboarding profile creation.
    }
  }

  final guestItems = guestFavoritesMigrationPayload(storage);
  if (guestItems.isNotEmpty) {
    await apiServiceProvider.migrateGuestFavorites(guestItems);
    await storage.clearGuestFavorites();
  }

  if (markOnboardingComplete) {
    await storage.completeOnboarding();
  }

  await storage.saveSession(userSession);
  if (userSession.hasSellerProfile &&
      storage.getAppMode(session: userSession) == AppMode.buyer &&
      session.user.accountType == 'seller') {
    await storage.saveAppMode(AppMode.seller);
  }
  ref.read(userSessionProvider.notifier).state = userSession;
  ref.read(authSessionProvider.notifier).state = session;
  invalidateEntitlementProviders(ref);
  syncLegalAcceptanceFromAuthUser(ref, session.user);

  navigate(
    postAuthRouteOverride ??
        await resolveAuthenticatedDestination(ref, storage, userSession),
  );
}

Future<void> completeAuthenticatedSessionFromContext({
  required WidgetRef ref,
  required BuildContext context,
  required AuthSession session,
  String? postAuthRouteOverride,
  bool markOnboardingComplete = false,
}) async {
  if (!context.mounted) return;
  await completeAuthenticatedSession(
    ref: ref,
    session: session,
    l10n: context.l10n,
    postAuthRouteOverride: postAuthRouteOverride,
    markOnboardingComplete: markOnboardingComplete,
    navigate: (route) {
      if (context.mounted) context.go(route);
    },
  );
}
