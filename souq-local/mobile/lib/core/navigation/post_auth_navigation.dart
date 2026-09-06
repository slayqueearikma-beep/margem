import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_storage.dart';
import '../services/auth_service.dart';
import '../services/legal_acceptance_service.dart';

/// Resolve the first authenticated route after login, registration, or splash.
Future<String> resolveAuthenticatedDestination(
  WidgetRef ref,
  AppStorage storage,
  UserSession session,
) async {
  try {
    final status = await refreshLegalAcceptanceStatus(ref);
    await storage.setLegalAcceptanceComplete(status.complete);
    if (!status.complete) {
      return '/legal/accept';
    }
    return storage.homeRouteFor(session);
  } catch (_) {
    if (!storage.getLegalAcceptanceComplete()) {
      return '/legal/accept';
    }
    final cached = ref.read(legalAcceptanceStatusProvider);
    if (cached != null && !cached.complete) {
      return '/legal/accept';
    }
    final authUser = ref.read(authSessionProvider)?.user;
    if (authUser != null && !authUser.legalAcceptanceComplete) {
      return '/legal/accept';
    }
  }
  return storage.homeRouteFor(session);
}
