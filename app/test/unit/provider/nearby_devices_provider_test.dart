import 'dart:io';

import 'package:common/model/device.dart';
import 'package:localsend_app/model/state/nearby_devices_state.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:test/test.dart';

void main() {
  test('does not register the local device discovered by multicast echo', () {
    final ownDevice = _device(ip: '10.0.0.2', fingerprint: 'self');

    expect(shouldRegisterNearbyDevice(ownDevice, ownFingerprint: 'self'), isFalse);
  });

  test('does not register local device when fingerprint differs but IP is local', () {
    final ownDevice = _device(ip: '10.0.0.2', fingerprint: 'rotated-cert');

    expect(
      shouldRegisterNearbyDevice(
        ownDevice,
        ownFingerprint: 'self',
        localIps: const ['10.0.0.2', '192.168.31.8'],
      ),
      isFalse,
    );
  });

  test('registers another reachable device', () {
    final peer = _device(ip: '10.0.0.3', fingerprint: 'phone');

    expect(shouldRegisterNearbyDevice(peer, ownFingerprint: 'self'), isTrue);
  });

  test('device registration wakes clipboard sync for every discovery path', () {
    final previous = NearbyDevicesState(
      runningFavoriteScan: false,
      runningIps: const {},
      devices: const {},
      signalingDevices: const {},
    );
    final next = previous.copyWith(
      devices: {
        '10.0.0.3': _device(ip: '10.0.0.3', fingerprint: 'phone'),
      },
    );

    expect(shouldWakeClipboardAfterNearbyDevicesChange(previous, next), isTrue);

    final source = File('lib/provider/clipboard_sync_provider.dart').readAsStringSync();
    expect(source, contains('_ref.stream(nearbyDevicesProvider)'));
    expect(source, contains('shouldWakeClipboardAfterNearbyDevicesChange(event.prev, event.next)'));
    expect(source, contains('notifyDeviceRegistered()'));
  });

  test('device endpoint updates wake clipboard sync even when device count is unchanged', () {
    final previousDevice = _device(ip: '10.0.0.3', fingerprint: 'phone');
    final nextDevice = Device(
      signalingId: previousDevice.signalingId,
      ip: previousDevice.ip,
      version: previousDevice.version,
      port: 53318,
      https: previousDevice.https,
      fingerprint: previousDevice.fingerprint,
      alias: previousDevice.alias,
      deviceModel: previousDevice.deviceModel,
      deviceType: previousDevice.deviceType,
      download: previousDevice.download,
      discoveryMethods: previousDevice.discoveryMethods,
    );
    final previous = NearbyDevicesState(
      runningFavoriteScan: false,
      runningIps: const {},
      devices: {
        previousDevice.ip!: previousDevice,
      },
      signalingDevices: const {},
    );
    final next = previous.copyWith(
      devices: {
        nextDevice.ip!: nextDevice,
      },
    );

    expect(previous.devices.length, next.devices.length);
    expect(shouldWakeClipboardAfterNearbyDevicesChange(previous, next), isTrue);
    expect(shouldWakeClipboardAfterNearbyDevicesChange(next, next), isFalse);
  });

  test('clearing devices for a refresh does not wake clipboard retry early', () {
    final device = _device(ip: '10.0.0.3', fingerprint: 'phone');
    final previous = NearbyDevicesState(
      runningFavoriteScan: false,
      runningIps: const {},
      devices: {
        device.ip!: device,
      },
      signalingDevices: const {},
    );
    final next = previous.copyWith(devices: const {});

    expect(shouldWakeClipboardAfterNearbyDevicesChange(previous, next), isFalse);
  });

  test('rejects devices without a usable IP address', () {
    final peer = _device(ip: null, fingerprint: 'phone');

    expect(shouldRegisterNearbyDevice(peer, ownFingerprint: 'self'), isFalse);
  });

  test('merged device list keeps reachable HTTP endpoint when relay discovery has the same fingerprint', () {
    final state = NearbyDevicesState(
      runningFavoriteScan: false,
      runningIps: const {},
      devices: {
        '10.0.0.3': _device(ip: '10.0.0.3', fingerprint: 'phone'),
      },
      signalingDevices: {
        'phone': {
          _device(ip: null, fingerprint: 'phone'),
        },
      },
    );

    final devices = state.allDevices.values.toList();

    expect(devices, hasLength(1));
    expect(devices.single.ip, '10.0.0.3');
  });

  test('merged device list prefers the newest reachable IP for the same fingerprint', () {
    final oldDevice = Device(
      signalingId: null,
      ip: '10.0.0.2',
      version: '2.1',
      port: 53317,
      https: false,
      fingerprint: 'same-fingerprint',
      alias: 'Flux Phone',
      deviceModel: 'Android',
      deviceType: DeviceType.mobile,
      download: false,
      discoveryMethods: {HttpDiscovery(ip: '10.0.0.2')},
    );
    final newDevice = Device(
      signalingId: null,
      ip: '10.0.0.3',
      version: '2.1',
      port: 53318,
      https: false,
      fingerprint: 'same-fingerprint',
      alias: 'Flux Phone',
      deviceModel: 'Android',
      deviceType: DeviceType.mobile,
      download: false,
      discoveryMethods: {HttpDiscovery(ip: '10.0.0.3')},
    );

    final state = NearbyDevicesState(
      runningFavoriteScan: false,
      runningIps: const {},
      devices: {
        oldDevice.ip!: oldDevice,
        newDevice.ip!: newDevice,
      },
      signalingDevices: const {},
    );

    final merged = state.allDevices.values.single;

    expect(merged.ip, '10.0.0.3');
    expect(merged.port, 53318);
  });
}

Device _device({
  required String? ip,
  required String fingerprint,
}) {
  return Device(
    signalingId: null,
    ip: ip,
    version: '2.0',
    port: 25565,
    https: true,
    fingerprint: fingerprint,
    alias: fingerprint,
    deviceModel: 'test',
    deviceType: DeviceType.desktop,
    download: false,
    discoveryMethods: const {},
  );
}
