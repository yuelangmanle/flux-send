import 'dart:io';

import 'package:localsend_app/provider/classic_bluetooth_provider.dart';
import 'package:test/test.dart';

void main() {
  test('classic Bluetooth provider owns paired devices, server listening, and connect actions', () {
    final source = File('lib/provider/classic_bluetooth_provider.dart').readAsStringSync();

    expect(source, contains('classicBluetoothProvider'));
    expect(source, contains('ClassicBluetoothState'));
    expect(source, contains('refreshPairedDevices'));
    expect(source, contains('startClassicBluetoothServer'));
    expect(source, contains('connectClassicBluetoothDevice'));
    expect(source, contains('sendClassicBluetoothClipboard'));
  });

  test('classic Bluetooth provider init does not auto-touch native Bluetooth hardware', () {
    final source = File('lib/provider/classic_bluetooth_provider.dart').readAsStringSync();
    final initIndex = source.indexOf('  ClassicBluetoothState init()');
    final refreshMethodIndex = source.indexOf('  Future<void> refreshPairedDevices()', initIndex);
    final initBody = source.substring(initIndex, refreshMethodIndex);

    expect(initIndex, isNonNegative);
    expect(refreshMethodIndex, isNonNegative);
    expect(initBody, contains('classicBluetoothEvents.listen'));
    expect(initBody, isNot(contains('startListening()')));
    expect(initBody, isNot(contains('refreshPairedDevices()')));
    expect(initBody, contains('经典蓝牙待命'));
  });

  test('classic Bluetooth provider only reports sent after native ACK', () {
    final source = File('lib/provider/classic_bluetooth_provider.dart').readAsStringSync();

    expect(source, contains('final sent = await sendClassicBluetoothClipboard(text)'));
    expect(source, contains('if (!sent)'));
    expect(source, contains('经典蓝牙发送未确认'));
  });

  test('classic Bluetooth state preserves previous error unless explicitly cleared', () {
    final state = const ClassicBluetoothState(lastError: '旧错误').copyWith(statusMessage: '新状态');

    expect(state.lastError, '旧错误');
    expect(state.copyWith(clearLastError: true).lastError, isNull);
  });

  test('classic Bluetooth send errors do not imply the active link disconnected', () {
    expect(
      shouldTreatClassicBluetoothErrorAsDisconnect(connecting: true, connected: false),
      isTrue,
    );
    expect(
      shouldTreatClassicBluetoothErrorAsDisconnect(connecting: false, connected: true),
      isFalse,
    );
  });

  test('classic Bluetooth socket errors mark the active link disconnected', () {
    expect(
      shouldTreatClassicBluetoothErrorAsDisconnect(
        connecting: false,
        connected: true,
        message: '经典蓝牙发送失败：Broken pipe',
      ),
      isTrue,
    );
    expect(
      shouldTreatClassicBluetoothErrorAsDisconnect(
        connecting: false,
        connected: true,
        message: '经典蓝牙发送失败：socket closed',
      ),
      isTrue,
    );
    expect(
      shouldTreatClassicBluetoothErrorAsDisconnect(
        connecting: false,
        connected: true,
        message: '经典蓝牙发送失败：3758097084',
      ),
      isTrue,
    );
    expect(
      shouldTreatClassicBluetoothErrorAsDisconnect(
        connecting: false,
        connected: true,
        message: '临时发送未确认',
      ),
      isFalse,
    );
  });

  test('classic Bluetooth send failure handler clears stale connected state on socket errors', () {
    final state = applyClassicBluetoothSendFailure(
      const ClassicBluetoothState(
        connected: true,
        connectedAddress: 'AA:BB:CC',
        statusMessage: '经典蓝牙已连接',
      ),
      '经典蓝牙发送失败：Broken pipe',
    );

    expect(state.connected, isFalse);
    expect(state.connectedAddress, isNull);
    expect(state.lastError, '经典蓝牙发送失败：Broken pipe');
  });

  test('classic Bluetooth native negative send result clears stale connected state immediately', () {
    final state = applyClassicBluetoothSendFailure(
      const ClassicBluetoothState(
        connected: true,
        connectedAddress: 'AA:BB:CC',
        statusMessage: '经典蓝牙已连接',
      ),
      '经典蓝牙发送未确认',
    );

    expect(state.connected, isFalse);
    expect(state.connectedAddress, isNull);
    expect(state.lastError, '经典蓝牙发送未确认');
  });

  test('classic Bluetooth connect waits for native connected event or timeout', () {
    final source = File('lib/provider/classic_bluetooth_provider.dart').readAsStringSync();

    expect(source, contains('_connectionTimeout'));
    expect(source, contains('等待经典蓝牙握手确认'));
    expect(source, contains('经典蓝牙连接超时'));
    expect(
      source,
      contains(
        'await connectClassicBluetoothDevice(device.address);\n      if (!state.connecting || state.connected || state.connectedAddress != device.address)',
      ),
    );
    expect(source, isNot(contains('已发起经典蓝牙连接')));
  });

  test('classic Bluetooth connection timeout and method-channel failures enter auto reconnect queue', () {
    final source = File('lib/provider/classic_bluetooth_provider.dart').readAsStringSync();
    final timeoutIndex = source.indexOf('经典蓝牙连接超时：请确认两端已在系统蓝牙设置配对');
    final catchIndex = source.indexOf('Connecting classic Bluetooth device failed');
    final connectMethodEnd = source.indexOf('  Future<bool> sendClipboard', catchIndex);

    expect(timeoutIndex, isNonNegative);
    expect(catchIndex, isNonNegative);
    expect(connectMethodEnd, isNonNegative);
    expect(
      source.substring(timeoutIndex, connectMethodEnd),
      contains('_scheduleReconnectIfNeeded();'),
    );
    expect(
      source.substring(catchIndex, connectMethodEnd),
      contains('_scheduleReconnectIfNeeded();'),
    );
  });

  test('classic Bluetooth listener errors clear the listening state', () {
    final source = File('lib/provider/classic_bluetooth_provider.dart').readAsStringSync();

    expect(source, contains("message.contains('服务') || message.contains('监听')"));
    expect(source, contains('listening: listenerFailed ? false : state.listening'));
  });

  test('classic Bluetooth manual stop does not restart listener from late disconnect event', () {
    expect(
      shouldRestartClassicBluetoothListenerOnDisconnect(manualStopRequested: false, disposed: false),
      isTrue,
    );
    expect(
      shouldRestartClassicBluetoothListenerOnDisconnect(manualStopRequested: true, disposed: false),
      isFalse,
    );
    expect(
      shouldRestartClassicBluetoothListenerOnDisconnect(manualStopRequested: false, disposed: true),
      isFalse,
    );
  });

  test('classic Bluetooth auto reconnects only after unexpected disconnect with a remembered peer', () {
    expect(
      shouldAutoReconnectClassicBluetooth(
        manualStopRequested: false,
        disposed: false,
        connecting: false,
        connected: false,
        lastConnectedAddress: 'AA:BB:CC:DD:EE:FF',
      ),
      isTrue,
    );
    expect(
      shouldAutoReconnectClassicBluetooth(
        manualStopRequested: true,
        disposed: false,
        connecting: false,
        connected: false,
        lastConnectedAddress: 'AA:BB:CC:DD:EE:FF',
      ),
      isFalse,
    );
    expect(
      shouldAutoReconnectClassicBluetooth(
        manualStopRequested: false,
        disposed: false,
        connecting: true,
        connected: false,
        lastConnectedAddress: 'AA:BB:CC:DD:EE:FF',
      ),
      isFalse,
    );
    expect(
      shouldAutoReconnectClassicBluetooth(
        manualStopRequested: false,
        disposed: false,
        connecting: false,
        connected: false,
        lastConnectedAddress: null,
      ),
      isFalse,
    );
  });

  test('classic Bluetooth reconnect delay uses bounded backoff', () {
    expect(classicBluetoothReconnectDelay(0), const Duration(seconds: 2));
    expect(classicBluetoothReconnectDelay(1), const Duration(seconds: 5));
    expect(classicBluetoothReconnectDelay(2), const Duration(seconds: 10));
    expect(classicBluetoothReconnectDelay(99), const Duration(seconds: 15));
  });

  test('classic Bluetooth auto-reconnect stops after repeated handshake failures', () {
    expect(isClassicBluetoothHandshakeFailureMessage('经典蓝牙连接的对端不是 Flux，已断开'), isTrue);
    expect(isClassicBluetoothHandshakeFailureMessage('经典蓝牙握手未完成，已拒绝未验证数据'), isTrue);
    expect(isClassicBluetoothHandshakeFailureMessage('经典蓝牙握手发送失败'), isTrue);
    expect(isClassicBluetoothHandshakeFailureMessage('经典蓝牙握手确认发送失败'), isTrue);
    expect(isClassicBluetoothHandshakeFailureMessage('经典蓝牙连接已断开'), isFalse);
    expect(isClassicBluetoothHandshakeFailureMessage(''), isFalse);

    expect(shouldStopClassicBluetoothAutoReconnect(handshakeFailureStreak: 0), isFalse);
    expect(shouldStopClassicBluetoothAutoReconnect(handshakeFailureStreak: 2), isFalse);
    expect(shouldStopClassicBluetoothAutoReconnect(handshakeFailureStreak: 3), isTrue);
    expect(shouldStopClassicBluetoothAutoReconnect(handshakeFailureStreak: 5), isTrue);
  });

  test('classic Bluetooth provider resets handshake failure streak on manual connect and success', () {
    final source = File('lib/provider/classic_bluetooth_provider.dart').readAsStringSync();
    final connectIndex = source.indexOf('Future<void> connect(ClassicBluetoothDevice device, {bool automatic = false})');
    final manualResetIndex = source.indexOf('_handshakeFailureStreak = 0;', connectIndex);
    final connectedIndex = source.indexOf("case 'connected':");
    final connectedResetIndex = source.indexOf('_handshakeFailureStreak = 0;', connectedIndex);
    final disconnectedIndex = source.indexOf("case 'disconnected':");
    final stopIndex = source.indexOf('shouldStopClassicBluetoothAutoReconnect(handshakeFailureStreak: _handshakeFailureStreak)', disconnectedIndex);
    final guardIndex = source.indexOf('if (!stopReconnect)', stopIndex);

    expect(manualResetIndex, greaterThan(connectIndex));
    expect(connectedResetIndex, greaterThan(connectedIndex));
    expect(stopIndex, isNonNegative);
    expect(guardIndex, isNonNegative);
    expect(guardIndex, greaterThan(stopIndex));
  });

  test('classic Bluetooth connect does not overwrite earlier native terminal event', () {
    final source = File('lib/provider/classic_bluetooth_provider.dart').readAsStringSync();

    expect(source, contains('if (!state.connecting || state.connected || state.connectedAddress != device.address)'));
    expect(source, contains('return;'));
  });

  test('classic Bluetooth provider forwards incoming clipboard events into clipboard sync service', () {
    final source = File('lib/provider/classic_bluetooth_provider.dart').readAsStringSync();

    expect(source, contains('classicBluetoothEvents.listen'));
    expect(source, contains('handleIncomingClipboard'));
    expect(source, contains("event['type'] == 'clipboard'"));
  });

  test('classic Bluetooth connected event wakes pending clipboard retry', () {
    final source = File('lib/provider/classic_bluetooth_provider.dart').readAsStringSync();
    final connectedIndex = source.indexOf("case 'connected':");
    final notifyIndex = source.indexOf('notifyDeviceRegistered()', connectedIndex);

    expect(connectedIndex, isNonNegative);
    expect(notifyIndex, isNonNegative);
  });

  test('classic Bluetooth incoming clipboard status waits for clipboard write result', () {
    final source = File('lib/provider/classic_bluetooth_provider.dart').readAsStringSync();
    final clipboardIndex = source.indexOf("event['type'] == 'clipboard'");
    final switchIndex = source.indexOf('switch (type)', clipboardIndex);
    final handlerIndex = source.indexOf('_handleIncomingClipboardEvent(text)', clipboardIndex);
    final directStatusIndex = source.indexOf('经典蓝牙已接收剪切板（\${text.length} 字符）', clipboardIndex);

    expect(clipboardIndex, isNonNegative);
    expect(switchIndex, isNonNegative);
    expect(handlerIndex, isNonNegative);
    expect(handlerIndex, lessThan(switchIndex));
    expect(directStatusIndex, greaterThan(switchIndex));
    expect(source, contains('Future<void> _handleIncomingClipboardEvent(String text) async'));
    expect(source, contains('final accepted = await _ref.notifier(clipboardSyncProvider).handleIncomingClipboard(text);'));
    expect(source, contains('经典蓝牙剪切板已拒收'));
  });

  test('connection mode no longer says classic Bluetooth RFCOMM is unfinished', () {
    final source = File('lib/provider/connection_mode_provider.dart').readAsStringSync();

    expect(source, contains('RFCOMM 常驻通道'));
    expect(source, isNot(contains('正在补经典蓝牙 RFCOMM')));
    expect(source, isNot(contains('RFCOMM 通道完成前')));
  });

  test('status card exposes paired Bluetooth devices and connect controls', () {
    final source = File('lib/widget/flux_connection_status_card.dart').readAsStringSync();

    expect(source, contains('classicBluetoothProvider'));
    expect(source, contains('刷新蓝牙设备'));
    expect(source, contains('连接'));
    expect(source, contains('经典蓝牙已连接'));
  });

  test('classic Bluetooth file transfer uses RFCOMM frames and does not fall back to LAN devices', () {
    final provider = File('lib/provider/classic_bluetooth_provider.dart').readAsStringSync();
    final bridge = File('lib/util/native/classic_bluetooth_bridge.dart').readAsStringSync();
    final card = File('lib/widget/flux_connection_status_card.dart').readAsStringSync();
    final sendVm = File('lib/pages/tabs/send_tab_vm.dart').readAsStringSync();

    expect(provider, contains('Future<bool> sendFiles(List<CrossFile> files)'));
    expect(provider, contains('fluxBluetoothFileBegin'));
    expect(provider, contains('fluxBluetoothFileChunk'));
    expect(provider, contains('fluxBluetoothFileEnd'));
    expect(bridge, contains("const fluxBluetoothFileBegin = 'flux.bluetooth.file.begin.v1'"));
    expect(bridge, contains("const fluxBluetoothFileChunk = 'flux.bluetooth.file.chunk.v1'"));
    expect(bridge, contains("const fluxBluetoothFileEnd = 'flux.bluetooth.file.end.v1'"));
    expect(provider, contains('saveFile('));
    expect(bridge, contains('sendClassicBluetoothFrame'));
    expect(card, contains('通过蓝牙发送'));
    expect(sendVm, contains('connectionModeProvider'));
    expect(sendVm, contains('usingClassicBluetooth ? const <Device>[]'));
    expect(sendVm, contains('FluxConnectionMode.classicBluetooth'));
    expect(sendVm, contains('const <FavoriteDevice>[]'));
    expect(sendVm, contains('经典蓝牙模式不会使用手动 IP'));
    expect(sendVm, contains('经典蓝牙模式不会使用收藏的局域网设备'));
    expect(sendVm, contains('SendTabInitAction'));
    expect(sendVm, contains('return;'));
  });

  test('switching away from classic Bluetooth stops the native RFCOMM listener', () {
    final source = File('lib/provider/connection_mode_provider.dart').readAsStringSync();
    final functionIndex = source.indexOf('Future<FluxConnectionModeDetails> switchFluxConnectionMode');
    final nonBluetoothModeSet = source.indexOf('await ref.notifier(connectionModeProvider).setMode(mode);', functionIndex);
    final nonBluetoothBranch = source.indexOf('ref.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction())', nonBluetoothModeSet);
    final stopIndex = source.indexOf('ref.notifier(classicBluetoothProvider).stop()', functionIndex);

    expect(functionIndex, isNonNegative);
    expect(nonBluetoothModeSet, isNonNegative);
    expect(nonBluetoothBranch, isNonNegative);
    expect(stopIndex, isNonNegative);
    expect(stopIndex, lessThan(nonBluetoothBranch));
  });
}
