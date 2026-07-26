import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('send provider updates local session with remote session id without shadowing local key', () {
    final source = File('lib/provider/network/send_provider.dart').readAsStringSync();

    expect(source, isNot(contains('final sessionId = response.response!.sessionId;')));
    expect(source, contains('final remoteSessionId = response.response!.sessionId;'));
    expect(source, contains('remoteSessionId: remoteSessionId'));
  });
}
