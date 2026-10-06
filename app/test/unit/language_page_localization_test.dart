import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('language page uses language title and Chinese loading fallback', () {
    final source = File('lib/pages/language_page.dart').readAsStringSync();

    expect(source, contains('t.settingsTab.general.language'));
    expect(source, contains('t.display.loading'));
    expect(source, isNot(contains('t.sendTab.selection.title')));
    expect(source, isNot(contains("'Loading'")));
  });
}
