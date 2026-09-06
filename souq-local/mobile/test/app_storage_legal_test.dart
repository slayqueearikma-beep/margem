import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:souq_local/core/services/app_storage.dart';

void main() {
  test('legal acceptance persistence is cleared on logout', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = AppStorage(prefs);

    await storage.setLegalAcceptanceComplete(true);
    expect(storage.getLegalAcceptanceComplete(), isTrue);

    await storage.logout();
    expect(storage.getLegalAcceptanceComplete(), isFalse);
  });

  test('legal acceptance defaults to false for new installs', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = AppStorage(prefs);

    expect(storage.getLegalAcceptanceComplete(), isFalse);
  });
}
