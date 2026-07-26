import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('copyable text uses Chinese snackbar copy feedback', () {
    final source = File('lib/widget/copyable_text.dart').readAsStringSync();

    expect(source, contains('已复制'));
    expect(source, contains('到剪切板'));
    expect(source, isNot(contains('Copied ')));
    expect(source, isNot(contains(' to clipboard!')));
  });
}
