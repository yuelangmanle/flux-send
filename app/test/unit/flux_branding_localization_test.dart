import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('startup error page uses Flux branding and Chinese error labels', () {
    final source = File('lib/config/init_error.dart').readAsStringSync();

    expect(source, contains('Flux'));
    expect(source, contains('错误'));
    expect(source, isNot(contains('LocalSend: Error')));
    expect(source, isNot(contains('LocalSend \${info.version}')));
  });

  test('troubleshoot firewall commands use Flux rule names', () {
    final source = File('lib/pages/troubleshoot_page.dart').readAsStringSync();

    expect(source, contains('name="Flux"'));
    expect(source, isNot(contains('name="LocalSend"')));
  });
}
