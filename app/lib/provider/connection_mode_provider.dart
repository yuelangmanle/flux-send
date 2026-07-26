import 'dart:async';

import 'package:localsend_app/provider/classic_bluetooth_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/scan_facade.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

enum FluxConnectionMode {
  localNetwork,
  hotspot,
  classicBluetooth,
}

class FluxConnectionModeDetails {
  final String title;
  final String subtitle;
  final String status;
  final String actionHint;
  final bool bluetoothPairingRequired;
  final bool clipboardAvailableNow;
  final bool activationSucceeded;
  final String? failureMessage;

  const FluxConnectionModeDetails({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.actionHint,
    required this.bluetoothPairingRequired,
    required this.clipboardAvailableNow,
    this.activationSucceeded = true,
    this.failureMessage,
  });

  FluxConnectionModeDetails copyWith({
    bool? activationSucceeded,
    String? failureMessage,
  }) {
    return FluxConnectionModeDetails(
      title: title,
      subtitle: subtitle,
      status: status,
      actionHint: actionHint,
      bluetoothPairingRequired: bluetoothPairingRequired,
      clipboardAvailableNow: clipboardAvailableNow,
      activationSucceeded: activationSucceeded ?? this.activationSucceeded,
      failureMessage: failureMessage ?? this.failureMessage,
    );
  }
}

final connectionModeProvider = NotifierProvider<ConnectionModeService, FluxConnectionMode>((ref) {
  return ConnectionModeService(ref.read(persistenceProvider));
});

class ConnectionModeService extends PureNotifier<FluxConnectionMode> {
  final PersistenceService _persistence;

  ConnectionModeService(this._persistence);

  @override
  FluxConnectionMode init() => parseFluxConnectionMode(_persistence.getFluxConnectionModeName());

  void setModeVolatile(FluxConnectionMode mode) {
    state = mode;
  }

  Future<void> persistMode(FluxConnectionMode mode) async {
    await _persistence.setFluxConnectionModeName(mode.name);
  }

  Future<void> setMode(FluxConnectionMode mode) async {
    await persistMode(mode);
    setModeVolatile(mode);
  }
}

Future<FluxConnectionModeDetails> switchFluxConnectionMode(
  Ref ref,
  FluxConnectionMode mode, {
  required int onlineDeviceCount,
  required bool clipboardEnabled,
}) async {
  final previousMode = ref.read(connectionModeProvider);
  final details = describeFluxConnectionMode(
    mode,
    onlineDeviceCount: onlineDeviceCount,
    clipboardEnabled: clipboardEnabled,
  );

  if (mode == FluxConnectionMode.classicBluetooth) {
    ref.notifier(connectionModeProvider).setModeVolatile(mode);
    ref.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
    final bluetooth = ref.notifier(classicBluetoothProvider);
    final listening = await bluetooth.startListening();
    if (!listening) {
      await ref.notifier(connectionModeProvider).setMode(previousMode);
      final previousDetails = describeFluxConnectionMode(
        previousMode,
        onlineDeviceCount: onlineDeviceCount,
        clipboardEnabled: clipboardEnabled,
      );
      return previousDetails.copyWith(
        activationSucceeded: false,
        failureMessage: ref.read(classicBluetoothProvider).lastError ?? '经典蓝牙监听启动失败，已回到${previousDetails.title}模式。',
      );
    }
    await ref.notifier(connectionModeProvider).persistMode(mode);
    unawaited(ref.notifier(classicBluetoothProvider).refreshPairedDevices());
    return details;
  }

  await ref.notifier(connectionModeProvider).setMode(mode);
  if (previousMode == FluxConnectionMode.classicBluetooth && ref.container.exists(classicBluetoothProvider)) {
    unawaited(ref.notifier(classicBluetoothProvider).stop());
  }
  ref.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
  unawaited(ref.global.dispatchAsync(StartSmartScan(forceLegacy: true)));
  return details;
}

FluxConnectionMode parseFluxConnectionMode(String? name) {
  return FluxConnectionMode.values.firstWhere(
    (mode) => mode.name == name,
    orElse: () => FluxConnectionMode.localNetwork,
  );
}

FluxConnectionModeDetails describeFluxConnectionMode(
  FluxConnectionMode mode, {
  required int onlineDeviceCount,
  required bool clipboardEnabled,
}) {
  final clipboardState = clipboardEnabled ? '剪切板常驻同步已开启' : '剪切板常驻同步未开启';

  return switch (mode) {
    FluxConnectionMode.localNetwork => FluxConnectionModeDetails(
      title: '局域网',
      subtitle: '同一个 Wi‑Fi / 有线网络内自动发现',
      status: '使用 UDP 多播发现设备，实际传输走 HTTP/TCP；当前发现 $onlineDeviceCount 台可同步设备，$clipboardState。',
      actionHint: '如果扫描不到，请确认两端在同一网络，且路由器没有开启 AP 隔离。',
      bluetoothPairingRequired: false,
      clipboardAvailableNow: clipboardEnabled,
    ),
    FluxConnectionMode.hotspot => FluxConnectionModeDetails(
      title: '热点直连',
      subtitle: '一台设备开热点，另一台设备连接这个热点',
      status: '一台设备开启热点，另一台设备连接这个热点；热点直连使用同一套局域网发现链路：UDP 多播发现，HTTP/TCP 传输；当前发现 $onlineDeviceCount 台可同步设备，$clipboardState。',
      actionHint: '先让一台设备开启个人热点，再让另一台设备加入该热点；无需互联网。',
      bluetoothPairingRequired: false,
      clipboardAvailableNow: clipboardEnabled,
    ),
    FluxConnectionMode.classicBluetooth => FluxConnectionModeDetails(
      title: '经典蓝牙',
      subtitle: '面向无 Wi‑Fi 场景的常驻蓝牙链路',
      status: '需要先在系统蓝牙设置中完成配对；Flux 会启动经典蓝牙 RFCOMM 常驻通道，连接成功后剪切板走蓝牙实时同步。',
      actionHint: 'Android 与 macOS 请先在系统设置里互相配对，再回到 Flux 刷新蓝牙设备并点连接。',
      bluetoothPairingRequired: true,
      clipboardAvailableNow: clipboardEnabled,
    ),
  };
}
