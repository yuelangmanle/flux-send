import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('generated device certificates use Flux subject branding', () {
    final source = File('lib/util/security_helper.dart').readAsStringSync();

    expect(source, contains("'CN': 'Flux User'"));
    expect(source, isNot(contains("'CN': 'LocalSend User'")));
  });

  test('Windows autostart registry value uses Flux branding', () {
    final source = File('lib/util/native/autostart_helper.dart').readAsStringSync();

    expect(source, contains("const _windowsRegistryKeyValue = 'Flux'"));
    expect(source, isNot(contains("const _windowsRegistryKeyValue = 'LocalSend'")));
  });

  test('Windows SendTo context menu shortcut uses Flux branding', () {
    final source = File('lib/util/native/context_menu_helper.dart').readAsStringSync();

    expect(source, contains("const _windowsFileName = 'Flux'"));
    expect(source, isNot(contains("const _windowsFileName = 'LocalSend'")));
  });
}
