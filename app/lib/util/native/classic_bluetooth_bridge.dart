import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

const _androidChannel = MethodChannel('org.localsend.localsend_app/localsend');
const _macosChannel = MethodChannel('main-delegate-channel');
const _eventChannel = EventChannel('org.localsend.localsend_app/classic_bluetooth_events');

MethodChannel get _channel {
  if (Platform.isMacOS) {
    return _macosChannel;
  }
  return _androidChannel;
}

Stream<Map<String, dynamic>>? _classicBluetoothEvents;

Stream<Map<String, dynamic>> get classicBluetoothEvents {
  return _classicBluetoothEvents ??= _eventChannel.receiveBroadcastStream().map((event) {
    return (event as Map).cast<String, dynamic>();
  });
}

const fluxBluetoothMessage = 'flux.bluetooth.message.v1';
const fluxBluetoothFileBegin = 'flux.bluetooth.file.begin.v1';
const fluxBluetoothFileChunk = 'flux.bluetooth.file.chunk.v1';
const fluxBluetoothFileEnd = 'flux.bluetooth.file.end.v1';

Future<List<ClassicBluetoothDevice>> listClassicBluetoothPairedDevices() async {
  final result = await _channel.invokeMethod<List>('listClassicBluetoothPairedDevices');
  return (result ?? const []).map((item) => ClassicBluetoothDevice.fromJson((item as Map).cast<String, dynamic>())).toList(growable: false);
}

Future<bool> startClassicBluetoothServer() async {
  final listening = await _channel.invokeMethod<bool>('startClassicBluetoothServer');
  return listening ?? false;
}

Future<void> stopClassicBluetooth() async {
  await _channel.invokeMethod('stopClassicBluetooth');
}

Future<void> connectClassicBluetoothDevice(String address) async {
  await _channel.invokeMethod('connectClassicBluetoothDevice', {
    'address': address,
  });
}

Future<bool> sendClassicBluetoothClipboard(String text) async {
  final sent = await _channel.invokeMethod<bool>('sendClassicBluetoothClipboard', {
    'type': fluxBluetoothMessage,
    'text': text,
  });
  return sent ?? false;
}

Future<bool> sendClassicBluetoothFrame(String payload) async {
  final sent = await _channel.invokeMethod<bool>('sendClassicBluetoothFrame', {
    'payload': payload,
  });
  return sent ?? false;
}

class ClassicBluetoothDevice {
  final String address;
  final String name;

  const ClassicBluetoothDevice({
    required this.address,
    required this.name,
  });

  factory ClassicBluetoothDevice.fromJson(Map<String, dynamic> json) {
    return ClassicBluetoothDevice(
      address: json['address'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}
