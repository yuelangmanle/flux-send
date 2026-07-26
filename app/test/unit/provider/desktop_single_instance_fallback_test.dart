import 'package:common/constants.dart';
import 'package:localsend_app/config/init.dart';
import 'package:test/test.dart';

void main() {
  test('desktop single-instance probe includes fallback server ports', () {
    final ports = fluxDesktopShowProbePorts(53317);

    expect(ports.take(4), [53317, 53318, 53319, 53320]);
    expect(ports, contains(defaultPort));
  });

  test('desktop single-instance probe de-duplicates invalid preferred port fallback', () {
    final ports = fluxDesktopShowProbePorts(-1);

    expect(ports.first, defaultPort);
    expect(ports.where((port) => port == defaultPort), hasLength(1));
  });
}
