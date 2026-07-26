import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('Android declares and wires multicast lock for reliable LAN discovery', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final mainActivity = File('android/app/src/main/kotlin/org/localsend/localsend_app/MainActivity.kt').readAsStringSync();
    final androidChannel = File('lib/util/native/channel/android_channel.dart').readAsStringSync();

    expect(manifest, contains('android.permission.ACCESS_WIFI_STATE'));
    expect(manifest, contains('android.permission.CHANGE_WIFI_MULTICAST_STATE'));
    expect(mainActivity, contains('acquireMulticastLock'));
    expect(mainActivity, contains('WifiManager'));
    expect(androidChannel, contains('acquireMulticastLockAndroid'));
  });

  test('Android declares LAN, hotspot, and classic Bluetooth permissions', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('android.permission.ACCESS_NETWORK_STATE'));
    expect(manifest, contains('android.permission.ACCESS_FINE_LOCATION'));
    expect(manifest, contains('android.permission.NEARBY_WIFI_DEVICES'));
    expect(manifest, contains('android.permission.BLUETOOTH"'));
    expect(manifest, contains('android.permission.BLUETOOTH_ADMIN'));
    expect(manifest, contains('android.permission.BLUETOOTH_SCAN'));
    expect(manifest, contains('android.permission.BLUETOOTH_CONNECT'));
    expect(manifest, contains('android.permission.BLUETOOTH_ADVERTISE'));
  });

  test('Android requests runtime network permissions before discovery starts', () {
    final initSource = File('lib/config/init.dart').readAsStringSync();

    expect(initSource, contains('requestAndroidNetworkPermissions'));
    expect(initSource, contains('Permission.nearbyWifiDevices.request'));
    expect(initSource, contains('Permission.locationWhenInUse.request'));
    expect(initSource, contains('Permission.bluetoothConnect.request'));
    expect(initSource, contains('Permission.bluetoothAdvertise.request'));
  });

  test('Android classic Bluetooth server checks advertise permission before listening', () {
    final bridgeSource = File('android/app/src/main/kotlin/org/localsend/localsend_app/ClassicBluetoothBridge.kt').readAsStringSync();
    final startServerIndex = bridgeSource.indexOf('private fun startServer(): Boolean');
    final advertiseCheckIndex = bridgeSource.indexOf('hasBluetoothAdvertisePermission()', startServerIndex);
    final listenIndex = bridgeSource.indexOf('listenUsingRfcommWithServiceRecord', startServerIndex);

    expect(startServerIndex, isNonNegative);
    expect(advertiseCheckIndex, isNonNegative);
    expect(listenIndex, isNonNegative);
    expect(advertiseCheckIndex, lessThan(listenIndex));
    expect(bridgeSource, contains('private fun hasBluetoothAdvertisePermission()'));
  });
}
