import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_models.dart';
import '../models/legal_acceptance_models.dart';
import 'api_service.dart';
import 'auth_service.dart';

final legalAcceptanceStatusProvider =
    StateProvider<LegalAcceptanceStatus?>((ref) => null);

class LegalAcceptanceService {
  LegalAcceptanceService(this._api);

  final ApiService _api;

  Future<LegalAcceptanceStatus> fetchStatus() async {
    final data = await _api.getJson('/legal/accept/status', auth: true);
    return LegalAcceptanceStatus.fromJson(data);
  }

  Future<LegalAcceptanceStatus> accept({
    required List<String> policyIds,
    required String language,
  }) async {
    final data = await _api.postJson(
      '/legal/accept',
      {
        'policies': policyIds.map((id) => {'policy_id': id}).toList(),
        'language': language,
        'acknowledged': true,
      },
      auth: true,
    );
    return LegalAcceptanceStatus.fromJson(data);
  }
}

final legalAcceptanceServiceProvider = Provider<LegalAcceptanceService>((ref) {
  return LegalAcceptanceService(apiServiceProvider);
});

Future<LegalAcceptanceStatus> refreshLegalAcceptanceStatus(WidgetRef ref) async {
  final status = await ref.read(legalAcceptanceServiceProvider).fetchStatus();
  ref.read(legalAcceptanceStatusProvider.notifier).state = status;
  return status;
}

void syncLegalAcceptanceFromAuthUser(WidgetRef ref, AuthUser user) {
  ref.read(legalAcceptanceStatusProvider.notifier).state = LegalAcceptanceStatus(
    required: const [],
    pending: user.pendingLegalPolicies,
    accepted: const [],
    complete: user.legalAcceptanceComplete,
  );
}
