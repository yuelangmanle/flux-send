import 'package:localsend_app/util/address_input_parser.dart';
import 'package:test/test.dart';

void main() {
  test('parses host and port from manual address input', () {
    final target = parseAddressInput('10.113.15.240:25565', fallbackPort: 53317);

    expect(target.host, '10.113.15.240');
    expect(target.port, 25565);
  });

  test('uses fallback port when manual address has no port', () {
    final target = parseAddressInput('10.113.15.240', fallbackPort: 53317);

    expect(target.host, '10.113.15.240');
    expect(target.port, 53317);
  });

  test('accepts pasted http urls', () {
    final target = parseAddressInput('http://10.113.15.240:25565', fallbackPort: 53317);

    expect(target.host, '10.113.15.240');
    expect(target.port, 25565);
  });

  test('parses IPv6 manual address input', () {
    final bracketed = parseAddressInput('[fe80::1]:25565', fallbackPort: 53317);
    final bare = parseAddressInput('fe80::1', fallbackPort: 53317);

    expect(bracketed.host, 'fe80::1');
    expect(bracketed.port, 25565);
    expect(bare.host, 'fe80::1');
    expect(bare.port, 53317);
  });

  test('detects full manual addresses even when the dialog is still in hashtag mode', () {
    expect(looksLikeFullAddressInput('10.113.15.240:25565'), isTrue);
    expect(looksLikeFullAddressInput('http://10.113.15.240:25565'), isTrue);
    expect(looksLikeFullAddressInput('[fe80::1]:25565'), isTrue);
    expect(looksLikeFullAddressInput('fe80::1'), isTrue);
    expect(looksLikeFullAddressInput('10.113.15.240'), isTrue);
    expect(looksLikeFullAddressInput('123'), isFalse);
  });

  test('accepts Chinese colon and accidental spaces in manual address input', () {
    final chineseColon = parseAddressInput('10.113.15.240：25565', fallbackPort: 53317);
    final spaced = parseAddressInput('10.113.15.240 : 25566', fallbackPort: 53317);

    expect(chineseColon.host, '10.113.15.240');
    expect(chineseColon.port, 25565);
    expect(spaced.host, '10.113.15.240');
    expect(spaced.port, 25566);
  });
}
