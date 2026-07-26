import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('incoming clipboard marks remote text only after system clipboard write succeeds', () {
    final source = File('lib/provider/clipboard_sync_provider.dart').readAsStringSync();
    final methodStart = source.indexOf('Future<bool> handleIncomingClipboard');
    final writeIndex = source.indexOf('await Clipboard.setData', methodStart);
    final markRemoteIndex = source.indexOf('_lastRemoteText = text;', methodStart);

    expect(methodStart, isNonNegative);
    expect(writeIndex, isNonNegative);
    expect(markRemoteIndex, isNonNegative);
    expect(markRemoteIndex, greaterThan(writeIndex));
  });
}
