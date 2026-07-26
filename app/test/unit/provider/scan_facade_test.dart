import 'package:localsend_app/provider/network/scan_facade.dart';
import 'package:test/test.dart';

void main() {
  group('Flux discovery port selection', () {
    test('uses the running server port when it differs from settings after fallback', () {
      expect(resolveDiscoveryPort(settingsPort: 53317, runningServerPort: 53318), 53318);
    });

    test('uses settings port before the server state is available', () {
      expect(resolveDiscoveryPort(settingsPort: 53317, runningServerPort: null), 53317);
    });

    test('scans default, running, and nearby fallback ports so peers on fallback are still found', () {
      expect(resolveDiscoveryPorts(settingsPort: 53317, runningServerPort: 53319), [53317, 53318, 53319, 53320]);
    });
  });
}
