import 'dart:io';

import 'package:localsend_app/provider/clipboard_sync_provider.dart';
import 'package:test/test.dart';

void main() {
  test('uses first local interfaces for background TCP fallback when no peers are known', () {
    final subnets = selectBackgroundDiscoverySubnets(
      localIps: const ['10.0.0.2', '172.16.0.4', '192.168.1.8'],
      onlineDeviceCount: 0,
      tick: 0,
    );

    expect(subnets, const ['10.0.0.2', '172.16.0.4']);
  });

  test('does not run TCP fallback every discovery tick when peers are already known', () {
    final subnets = selectBackgroundDiscoverySubnets(
      localIps: const ['10.0.0.2'],
      onlineDeviceCount: 1,
      tick: 1,
    );

    expect(subnets, isEmpty);
  });

  test('periodically revalidates known peers to recover from stale discovery state', () {
    final subnets = selectBackgroundDiscoverySubnets(
      localIps: const ['10.0.0.2'],
      onlineDeviceCount: 1,
      tick: 4,
    );

    expect(subnets, const ['10.0.0.2']);
  });

  test('background TCP discovery wakes pending clipboard after registering peers', () {
    final source = File('lib/provider/clipboard_sync_provider.dart').readAsStringSync();
    final scannerIndex = source.indexOf('void _startBackgroundTcpFallback()');
    final dispatchIndex = source.indexOf('dispatchAsync(StartLegacySubnetScan(subnets: subnets))', scannerIndex);
    final wakeIndex = source.indexOf('notifyDeviceRegistered()', dispatchIndex);

    expect(scannerIndex, isNonNegative);
    expect(dispatchIndex, isNonNegative);
    expect(wakeIndex, isNonNegative);
  });
}
