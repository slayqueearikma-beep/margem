import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_storage.dart';
import '../services/auth_service.dart';

/// Notifies [GoRouter] when auth/session state changes so redirects re-run.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(this._ref) {
    _ref.listen(userSessionProvider, (_, __) => notifyListeners());
    _ref.listen(authSessionProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}

final routerRefreshNotifierProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});
