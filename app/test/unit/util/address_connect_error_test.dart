import 'dart:io';

import 'package:localsend_app/util/address_connect_error.dart';
import 'package:test/test.dart';

void main() {
  test('maps socket failures to an actionable Chinese message', () {
    final message = describeAddressConnectError(const SocketException('connection refused'));
    expect(message, contains('连不上对方'));
    expect(message, contains('同一 Wi-Fi'));
  });

  test('maps dns failures to an address hint', () {
    final message = describeAddressConnectError(const SocketException('Failed host lookup: foo.local'));
    expect(message, contains('地址无法解析'));
  });

  test('maps tls failures to a certificate hint', () {
    final message = describeAddressConnectError(Exception('Handshake error in client'));
    expect(message, contains('安全连接失败'));
  });

  test('unknown errors keep the original message plus a fallback hint', () {
    final message = describeAddressConnectError(Exception('weird failure'));
    expect(message, contains('weird failure'));
    expect(message, contains('连接失败'));
  });
}
