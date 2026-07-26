import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('macOS app should be a visible foreground app by default', () {
    final infoPlist = File('macos/Runner/Info.plist').readAsStringSync();

    expect(infoPlist, isNot(contains('<key>LSUIElement</key>\n\t<true/>')));
    expect(infoPlist, isNot(contains('<key>LSUIElement</key>\n    <true/>')));
  });

  test('macOS app declares Bluetooth privacy usage before RFCOMM access', () {
    final infoPlist = File('macos/Runner/Info.plist').readAsStringSync();

    expect(infoPlist, contains('<key>NSBluetoothAlwaysUsageDescription</key>'));
    expect(infoPlist, contains('经典蓝牙'));
    expect(infoPlist, contains('剪切板'));
  });

  test('macOS Bluetooth bridge guards native access with privacy declaration check', () {
    final source = File('macos/Runner/ClassicBluetoothBridge.swift').readAsStringSync();

    expect(source, contains('private var hasBluetoothUsageDescription: Bool'));
    expect(source, contains('NSBluetoothAlwaysUsageDescription'));
    expect(source, contains('guard hasBluetoothUsageDescription else'));
    expect(source, contains('BLUETOOTH_USAGE_DESCRIPTION_MISSING'));
  });

  test('macOS sandbox entitlements allow Bluetooth device access', () {
    final releaseEntitlements = File('macos/Runner/Release.entitlements').readAsStringSync();
    final debugEntitlements = File('macos/Runner/DebugProfile.entitlements').readAsStringSync();

    for (final entitlements in [releaseEntitlements, debugEntitlements]) {
      expect(entitlements, contains('<key>com.apple.security.device.bluetooth</key>'));
      expect(entitlements, contains('<true/>'));
    }
  });
}
