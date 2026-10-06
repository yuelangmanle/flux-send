import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('copyable text uses localized snackbar copy feedback', () {
    final source = File('lib/widget/copyable_text.dart').readAsStringSync();

    expect(source, contains('t.display.copiedToClipboard'));
    expect(source, isNot(contains('Copied ')));
    expect(source, isNot(contains(' to clipboard!')));
  });
}
