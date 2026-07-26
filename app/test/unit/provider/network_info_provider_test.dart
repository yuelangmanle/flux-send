import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:test/test.dart';

void main() {
  group('rankIpAddresses', () {
    test('should only sort list if no primary', () {
      expect(rankIpAddresses(['123.456', '222.1', '321.222'], null), ['123.456', '321.222', '222.1']);
    });

    test('should only take primary', () {
      expect(rankIpAddresses([], '123.123'), ['123.123']);
    });

    test('should sort primary first', () {
      expect(rankIpAddresses(['123.456', '222.1', '321.222'], '123.123'), ['123.123', '123.456', '321.222', '222.1']);
    });

    test('should sort primary first and remove duplicates', () {
      expect(rankIpAddresses(['123.456', '123.123', '222.1', '222.1', '321.222'], '123.123'), ['123.123', '123.456', '321.222', '222.1']);
    });

    test('keeps hotspot gateway addresses in the scan list', () {
      expect(rankIpAddresses(['172.20.10.1', '172.20.10.3'], '172.20.10.3'), ['172.20.10.3', '172.20.10.1']);
    });

    test('filters loopback and VPN-like addresses from automatic discovery candidates', () {
      expect(
        discoveryCandidateIps([
          '127.0.0.1',
          '198.18.0.1',
          '10.113.15.240',
          '172.20.10.1',
          '192.168.1.25',
        ]),
        ['10.113.15.240', '172.20.10.1', '192.168.1.25'],
      );
    });
  });
}
