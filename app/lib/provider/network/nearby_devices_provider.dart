import 'dart:async';

import 'package:collection/collection.dart';
import 'package:common/isolate.dart';
import 'package:common/model/device.dart';
import 'package:localsend_app/model/persistence/favorite_device.dart';
import 'package:localsend_app/model/state/nearby_devices_state.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/logging/discovery_logs_provider.dart';
import 'package:localsend_app/provider/security_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

const _clipboardEndpointSetEquality = SetEquality<String>();

/// This provider is responsible for:
/// - Scanning the network for other LocalSend instances
/// - Keeping track of all found devices (they are only stored in RAM)
///
/// Use [scanProvider] to have a high-level API to perform discovery operations.
final nearbyDevicesProvider = ReduxProvider<NearbyDevicesService, NearbyDevicesState>((ref) {
  return NearbyDevicesService(
    isolateController: ref.notifier(parentIsolateProvider),
    favoriteService: ref.notifier(favoritesProvider),
    discoveryLogs: ref.notifier(discoveryLoggerProvider),
    ownFingerprint: () => ref.read(securityProvider).certificateHash,
    localIps: () => ref.read(localIpProvider).localIps,
  );
});

class NearbyDevicesService extends ReduxNotifier<NearbyDevicesState> {
  final IsolateController _isolateController;
  final FavoritesService _favoriteService;
  final DiscoveryLogger _discoveryLogger;
  final String Function() _ownFingerprint;
  final List<String> Function() _localIps;

  NearbyDevicesService({
    required IsolateController isolateController,
    required FavoritesService favoriteService,
    required DiscoveryLogger discoveryLogs,
    required String Function() ownFingerprint,
    required List<String> Function() localIps,
  }) : _discoveryLogger = discoveryLogs,
       _isolateController = isolateController,
       _favoriteService = favoriteService,
       _ownFingerprint = ownFingerprint,
       _localIps = localIps;

  @override
  NearbyDevicesState init() => const NearbyDevicesState(
    runningFavoriteScan: false,
    runningIps: {},
    devices: {},
    signalingDevices: {},
  );
}

/// Binds the UDP port and listens for incoming announcements.
/// This should run forever as long as the app is running.
class StartMulticastListener extends AsyncReduxAction<NearbyDevicesService, NearbyDevicesState> {
  @override
  Future<NearbyDevicesState> reduce() async {
    await for (final device in notifier._isolateController.state.multicastDiscovery!.receiveFromIsolate) {
      await dispatchAsync(RegisterDeviceAction(device));
      notifier._discoveryLogger.addLog(describeMulticastDeviceDiscovered(device));
    }
    return state;
  }
}

/// Removes all found devices from the state.
class ClearFoundDevicesAction extends ReduxAction<NearbyDevicesService, NearbyDevicesState> {
  @override
  NearbyDevicesState reduce() {
    return state.copyWith(
      devices: {},
    );
  }
}

/// Registers a device in the state.
/// It will override any existing device with the same IP.
class RegisterDeviceAction extends AsyncReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final Device device;

  RegisterDeviceAction(this.device);

  @override
  bool get trackOrigin => false;

  @override
  Future<NearbyDevicesState> reduce() async {
    if (!shouldRegisterNearbyDevice(
      device,
      ownFingerprint: notifier._ownFingerprint(),
      localIps: notifier._localIps(),
    )) {
      await Future.microtask(() {});
      return state;
    }

    final favoriteDevice = notifier._favoriteService.state.firstWhereOrNull((e) => e.fingerprint == device.fingerprint);
    if (favoriteDevice != null && !favoriteDevice.customAlias) {
      // Update existing favorite with new alias
      await external(notifier._favoriteService).dispatchAsync(UpdateFavoriteAction(favoriteDevice.copyWith(alias: device.alias)));
    } else {
      await Future.microtask(() {});
    }
    return state.copyWith(
      devices: {...state.devices}..update(device.ip!, (_) => device, ifAbsent: () => device),
    );
  }
}

bool shouldRegisterNearbyDevice(
  Device device, {
  required String ownFingerprint,
  List<String> localIps = const [],
}) {
  final ip = device.ip;
  if (ip == null || ip.isEmpty) {
    return false;
  }
  if (localIps.contains(ip)) {
    return false;
  }
  return device.fingerprint != ownFingerprint;
}

bool shouldWakeClipboardAfterNearbyDevicesChange(
  NearbyDevicesState previous,
  NearbyDevicesState next,
) {
  final previousEndpoints = _clipboardReachableEndpoints(previous);
  final currentEndpoints = _clipboardReachableEndpoints(next);
  if (currentEndpoints.isEmpty) {
    return false;
  }
  return !_clipboardEndpointSetEquality.equals(
    previousEndpoints,
    currentEndpoints,
  );
}

Set<String> _clipboardReachableEndpoints(NearbyDevicesState state) {
  return {
    for (final device in state.allDevices.values)
      if (device.ip != null) '${device.fingerprint}|${device.ip}|${device.port}|${device.https}',
  };
}

String describeLegacyScanStart({
  required String localIp,
  required int port,
}) {
  return '[发现/TCP] 正在扫描 $localIp:$port';
}

String describeFavoriteScanStart({
  required int favoriteCount,
}) {
  return '[发现/TCP] 正在扫描 $favoriteCount 台收藏设备';
}

String describeMulticastDeviceDiscovered(Device device) {
  return '[发现/UDP] 找到 ${device.alias}（${device.ip ?? '未知 IP'}，型号：${device.deviceModel ?? '未知'}）';
}

String describeRegisterRequestReceived({
  required String alias,
  required String ip,
}) {
  return '[发现/TCP] 收到 $alias 的注册请求（$ip）';
}

String describeLegacyScanFinished({
  required String localIp,
  required int port,
  required int foundCount,
}) {
  if (foundCount <= 0) {
    return '[发现/TCP] $localIp:$port 扫描完成，未发现设备';
  }
  return '[发现/TCP] $localIp:$port 扫描完成，发现 $foundCount 台设备';
}

String describeLegacyScanFailed({
  required String localIp,
  required int port,
  required Object error,
}) {
  return '[发现/TCP] $localIp:$port 扫描失败：$error';
}

/// Registers a new device found via signaling.
class RegisterSignalingDeviceAction extends ReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final Device device;

  RegisterSignalingDeviceAction(this.device);

  @override
  NearbyDevicesState reduce() {
    final Set<Device> existingDevices = state.signalingDevices[device.fingerprint]?.toSet() ?? {};
    final existingDevice = existingDevices.firstWhereOrNull((e) => e.signalingId == device.signalingId);
    if (existingDevice != null) {
      existingDevices.remove(existingDevice);
    }
    existingDevices.add(device);

    return state.copyWith(
      signalingDevices: {
        ...state.signalingDevices,
        device.fingerprint: existingDevices,
      },
    );
  }
}

class UnregisterSignalingDeviceAction extends ReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final String signalingId;

  UnregisterSignalingDeviceAction(this.signalingId);

  @override
  NearbyDevicesState reduce() {
    return state.copyWith(
      signalingDevices: {
        for (final entry in state.signalingDevices.entries) entry.key: entry.value.where((e) => e.signalingId != signalingId).toSet(),
      },
    );
  }
}

/// It does not really "scan".
/// It just sends an announcement which will cause a response on every other LocalSend member of the network.
class StartMulticastScan extends ReduxAction<NearbyDevicesService, NearbyDevicesState> {
  @override
  NearbyDevicesState reduce() {
    external(notifier._isolateController).dispatch(IsolateSendMulticastAnnouncementAction());
    return state;
  }
}

/// Scans one particular subnet with traditional HTTP/TCP discovery.
/// This method awaits until the scan is finished.
class StartLegacyScan extends AsyncReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final int port;
  final String localIp;
  final bool https;

  StartLegacyScan({
    required this.port,
    required this.localIp,
    required this.https,
  });

  @override
  Future<NearbyDevicesState> reduce() async {
    if (state.runningIps.contains(localIp)) {
      // already running for the same localIp
      await Future.microtask(() {});
      return state;
    }

    notifier._discoveryLogger.addLog(describeLegacyScanStart(localIp: localIp, port: port));
    dispatch(_SetRunningIpsAction({...state.runningIps, localIp}));

    var foundCount = 0;
    var failed = false;
    try {
      final stream = external(notifier._isolateController).dispatchTakeResult(
        IsolateInterfaceHttpDiscoveryAction(
          networkInterface: localIp,
          port: port,
          https: https,
        ),
      );

      await for (final device in stream) {
        foundCount++;
        notifier._discoveryLogger.addLog('[发现/TCP] 找到 ${device.alias}（${device.ip}，型号：${device.deviceModel}）');
        await dispatchAsync(RegisterDeviceAction(device));
      }
    } catch (e) {
      failed = true;
      notifier._discoveryLogger.addLog(describeLegacyScanFailed(localIp: localIp, port: port, error: e));
      rethrow;
    } finally {
      if (!failed) {
        notifier._discoveryLogger.addLog(describeLegacyScanFinished(localIp: localIp, port: port, foundCount: foundCount));
      }
      dispatch(_SetRunningIpsAction(state.runningIps.where((ip) => ip != localIp).toSet()));
    }

    return state;
  }
}

class StartFavoriteScan extends AsyncReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final List<FavoriteDevice> devices;
  final bool https;

  StartFavoriteScan({
    required this.devices,
    required this.https,
  });

  @override
  Future<NearbyDevicesState> reduce() async {
    if (devices.isEmpty) {
      return state;
    }
    notifier._discoveryLogger.addLog(describeFavoriteScanStart(favoriteCount: devices.length));
    dispatch(_SetRunningFavoriteScanAction(true));

    try {
      final stream = external(notifier._isolateController).dispatchTakeResult(
        IsolateFavoriteHttpDiscoveryAction(
          favorites: devices.map((e) => (e.ip, e.port)).toList(),
          https: https,
        ),
      );

      await for (final device in stream) {
        notifier._discoveryLogger.addLog('[发现/TCP] 收藏设备在线：${device.alias}（${device.ip}，型号：${device.deviceModel}）');
        await dispatchAsync(RegisterDeviceAction(device));
      }
    } finally {
      dispatch(_SetRunningFavoriteScanAction(false));
    }

    return state;
  }
}

class _SetRunningIpsAction extends ReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final Set<String> runningIps;

  _SetRunningIpsAction(this.runningIps);

  @override
  NearbyDevicesState reduce() {
    return state.copyWith(
      runningIps: runningIps,
    );
  }
}

class _SetRunningFavoriteScanAction extends ReduxAction<NearbyDevicesService, NearbyDevicesState> {
  final bool running;

  _SetRunningFavoriteScanAction(this.running);

  @override
  NearbyDevicesState reduce() {
    return state.copyWith(
      runningFavoriteScan: running,
    );
  }
}
