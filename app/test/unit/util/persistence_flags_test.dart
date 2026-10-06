import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('onboarding flag defaults to not shown and persists once set', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = PersistenceService.forTesting(prefs);

    expect(service.isOnboardingShown(), isFalse);
    await service.setOnboardingShown();
    expect(service.isOnboardingShown(), isTrue);
  });

  test('clipboard sync flag defaults to enabled and persists toggles', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = PersistenceService.forTesting(prefs);

    expect(service.isClipboardSyncEnabled(), isTrue);
    await service.setClipboardSyncEnabled(false);
    expect(service.isClipboardSyncEnabled(), isFalse);
  });
}
