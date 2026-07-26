import 'dart:io';

import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:test/test.dart';

void main() {
  group('Flux server port fallback', () {
    test('detects address-in-use socket exceptions', () {
      final exception = SocketException(
        'Failed to create server socket (OS Error: Address already in use, errno = 48)',
        osError: const OSError('Address already in use', 48),
        port: 53317,
      );

      expect(isAddressAlreadyInUse(exception), isTrue);
    });

    test('does not treat unrelated socket errors as address-in-use', () {
      final exception = SocketException(
        'Network is unreachable',
        osError: const OSError('Network is unreachable', 51),
        port: 53317,
      );

      expect(isAddressAlreadyInUse(exception), isFalse);
    });

    test('builds bounded fallback port candidates from preferred port', () {
      expect(serverPortCandidates(53317, fallbackCount: 4), [53317, 53318, 53319, 53320, 53321]);
    });

    test('wraps fallback candidates at the end of valid user ports', () {
      expect(serverPortCandidates(65534, fallbackCount: 3), [65534, 65535, 1024, 1025]);
    });

    test('reports when server starts on a fallback port', () {
      final message = describeServerPortFallback(preferredPort: 53317, actualPort: 53318);

      expect(message, '默认端口 53317 被占用，Flux 已自动切换到 53318。');
    });

    test('keeps normal startup message empty when preferred port is used', () {
      expect(describeServerPortFallback(preferredPort: 53317, actualPort: 53317), isNull);
    });

    test('requires multicast listener restart when effective server port changes', () {
      expect(shouldRestartMulticastListener(previousPort: null, nextPort: 53317), isFalse);
      expect(shouldRestartMulticastListener(previousPort: 53317, nextPort: 53317), isFalse);
      expect(shouldRestartMulticastListener(previousPort: 53317, nextPort: 53318), isTrue);
    });
  });
}
