import 'dart:io';

import 'package:localsend_app/provider/connection_mode_provider.dart';
import 'package:test/test.dart';

void main() {
  test('local network mode describes real LAN discovery transport', () {
    final details = describeFluxConnectionMode(
      FluxConnectionMode.localNetwork,
      onlineDeviceCount: 2,
      clipboardEnabled: true,
    );

    expect(details.title, '局域网');
    expect(details.status, contains('UDP 多播'));
    expect(details.status, contains('HTTP/TCP'));
    expect(details.status, contains('2 台'));
    expect(details.bluetoothPairingRequired, isFalse);
    expect(details.clipboardAvailableNow, isTrue);
  });

  test('hotspot mode explains that one device opens hotspot and the other joins it', () {
    final details = describeFluxConnectionMode(
      FluxConnectionMode.hotspot,
      onlineDeviceCount: 0,
      clipboardEnabled: true,
    );

    expect(details.title, '热点直连');
    expect(details.status, contains('一台设备开启热点'));
    expect(details.status, contains('另一台设备连接这个热点'));
    expect(details.status, contains('同一套局域网发现链路'));
    expect(details.clipboardAvailableNow, isTrue);
  });

  test('classic bluetooth mode describes the real RFCOMM clipboard link', () {
    final details = describeFluxConnectionMode(
      FluxConnectionMode.classicBluetooth,
      onlineDeviceCount: 0,
      clipboardEnabled: true,
    );

    expect(details.title, '经典蓝牙');
    expect(details.status, contains('需要先在系统蓝牙设置中完成配对'));
    expect(details.status, contains('RFCOMM 常驻通道'));
    expect(details.status, contains('剪切板走蓝牙实时同步'));
    expect(details.bluetoothPairingRequired, isTrue);
    expect(details.clipboardAvailableNow, isTrue);
  });

  test('classic bluetooth switch is only persisted after native listener starts', () {
    final source = File('lib/provider/connection_mode_provider.dart').readAsStringSync();
    final functionIndex = source.indexOf('Future<FluxConnectionModeDetails> switchFluxConnectionMode');
    final bluetoothBranch = source.indexOf('if (mode == FluxConnectionMode.classicBluetooth)', functionIndex);
    final volatileIndex = source.indexOf('setModeVolatile(mode)', bluetoothBranch);
    final startIndex = source.indexOf('startListening()', bluetoothBranch);
    final persistIndex = source.indexOf('persistMode(mode)', bluetoothBranch);
    final revertIndex = source.indexOf('setMode(previousMode)', bluetoothBranch);

    expect(functionIndex, isNonNegative);
    expect(bluetoothBranch, isNonNegative);
    expect(volatileIndex, isNonNegative);
    expect(startIndex, isNonNegative);
    expect(persistIndex, isNonNegative);
    expect(revertIndex, isNonNegative);
    expect(volatileIndex, lessThan(startIndex));
    expect(startIndex, lessThan(persistIndex));
    expect(revertIndex, lessThan(persistIndex));
  });
}
