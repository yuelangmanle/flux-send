import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:common/model/device.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/model/state/nearby_devices_state.dart';
import 'package:localsend_app/provider/classic_bluetooth_provider.dart';
import 'package:localsend_app/provider/clipboard_timeline_provider.dart';
import 'package:localsend_app/provider/connection_mode_provider.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/scan_facade.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_app/provider/security_provider.dart';
import 'package:localsend_app/util/security_helper.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('ClipboardSync');

/// 剪切板同步 Provider
final clipboardSyncProvider = NotifierProvider<ClipboardSyncService, ClipboardSyncState>((ref) {
  return ClipboardSyncService(ref);
});

List<Device> selectClipboardSyncTargets(
  NearbyDevicesState nearbyState, {
  String? ownFingerprint,
  List<String> localIps = const [],
}) {
  final targetsByFingerprint = <String, Device>{};

  for (final device in nearbyState.allDevices.values) {
    if (device.ip == null) {
      continue;
    }

    if (localIps.contains(device.ip)) {
      continue;
    }

    if (ownFingerprint != null && device.fingerprint == ownFingerprint) {
      continue;
    }

    targetsByFingerprint.putIfAbsent(device.fingerprint, () => device);
  }

  return targetsByFingerprint.values.toList(growable: false);
}

List<String> selectBackgroundDiscoverySubnets({
  required List<String> localIps,
  required int onlineDeviceCount,
  required int tick,
}) {
  if (localIps.isEmpty) {
    return const [];
  }

  if (onlineDeviceCount > 0 && tick % 4 != 0) {
    return const [];
  }

  return localIps.take(2).toList(growable: false);
}

String resolvePendingClipboardAfterSuccessfulSend({
  required String sentText,
  required String pendingText,
}) {
  return pendingText == sentText ? '' : pendingText;
}

String resolvePendingClipboardAfterSendAttempt({
  required String sentText,
  required String pendingText,
  required int attemptedCount,
  required int successCount,
}) {
  if (attemptedCount <= 0 || successCount < attemptedCount) {
    return pendingText;
  }

  return resolvePendingClipboardAfterSuccessfulSend(
    sentText: sentText,
    pendingText: pendingText,
  );
}

bool shouldRetryPendingClipboardAfterSend({
  required bool enabled,
  required String pendingText,
  required String sentText,
  required bool retryQueuedDuringSend,
}) {
  return enabled && pendingText.isNotEmpty && (retryQueuedDuringSend || pendingText != sentText);
}

bool shouldClearRemoteClipboardEchoSuppression({
  required bool suppressNext,
  required String clipboardText,
  required String lastRemoteText,
}) {
  return suppressNext && clipboardText != lastRemoteText;
}

bool shouldRunNetworkClipboardDiscovery(FluxConnectionMode mode) {
  return mode != FluxConnectionMode.classicBluetooth;
}

bool shouldWriteIncomingClipboard({
  required String incomingText,
  required String lastRemoteText,
  required String lastLocalText,
}) {
  if (incomingText.isEmpty) {
    return false;
  }

  // 与上次已接收的远端文本相同：要么是重复内容，要么是失败重试——
  // 用户本机可能已复制了新内容，重试不得把它洗掉，一律不再写入。
  // 与本机当前文本相同：内容已就位，无需重复写入。
  return incomingText != lastRemoteText && incomingText != lastLocalText;
}

const pendingClipboardRetryTtl = Duration(minutes: 2);

bool shouldDropStalePendingClipboard({
  required DateTime? pendingSince,
  required DateTime now,
  Duration ttl = pendingClipboardRetryTtl,
}) {
  final since = pendingSince;
  if (since == null) {
    return false;
  }
  return now.difference(since) > ttl;
}

String describeIncomingClipboardStatus(String text) {
  return '已接收远端剪切板（${text.length} 字符）';
}

String describeClipboardPeerSendFailure({
  required String alias,
  required String ip,
  required Object error,
}) {
  final name = alias.trim().isEmpty ? ip : alias.trim();
  return '$name ($ip)：${_normalizeClipboardSendError(error)}';
}

String describeClipboardSyncFailureSummary(List<String> failures) {
  if (failures.isEmpty) {
    return '未能同步到任何设备';
  }

  final visibleFailures = failures.take(3).join('；');
  final remainingCount = failures.length - 3;
  if (remainingCount <= 0) {
    return '未能同步到任何设备：$visibleFailures';
  }

  return '未能同步到任何设备：$visibleFailures；另有 $remainingCount 台失败';
}

String _normalizeClipboardSendError(Object error) {
  var message = error.toString().trim();
  for (final prefix in const ['HttpException: ', 'Exception: ']) {
    if (message.startsWith(prefix)) {
      message = message.substring(prefix.length).trim();
    }
  }
  return message.isEmpty ? '未知错误' : message;
}

Future<String> readClipboardSyncFailureMessage(HttpClientResponse response) async {
  final body = await response.transform(utf8.decoder).join();
  if (body.isEmpty) {
    return 'HTTP ${response.statusCode}';
  }

  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['message'] is String && (decoded['message'] as String).isNotEmpty) {
      return decoded['message'] as String;
    }
  } catch (_) {}

  return 'HTTP ${response.statusCode}: $body';
}

String? extractClipboardTextFromRequestBody({
  required String body,
  required String? contentType,
}) {
  if (body.isEmpty) {
    return null;
  }

  final mimeType = contentType?.split(';').first.trim().toLowerCase();
  if (mimeType == 'application/json') {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['text'] is String) {
      return decoded['text'] as String;
    }
    return null;
  }

  return body;
}

Uri buildClipboardSyncUri({
  required String ip,
  required int port,
  required bool https,
}) {
  return Uri(
    scheme: https ? 'https' : 'http',
    host: ip,
    port: port,
    path: '/api/clipboard',
  );
}

class ClipboardSyncState {
  final bool enabled;
  final String? lastSyncedText;
  final DateTime? lastSyncTime;
  final int syncCount;
  final String? lastError;
  final String statusMessage;
  final int onlineDeviceCount;

  const ClipboardSyncState({
    this.enabled = false,
    this.lastSyncedText,
    this.lastSyncTime,
    this.syncCount = 0,
    this.lastError,
    this.statusMessage = '剪切板同步未启动',
    this.onlineDeviceCount = 0,
  });

  ClipboardSyncState copyWith({
    bool? enabled,
    String? lastSyncedText,
    DateTime? lastSyncTime,
    int? syncCount,
    String? lastError,
    String? statusMessage,
    int? onlineDeviceCount,
  }) {
    return ClipboardSyncState(
      enabled: enabled ?? this.enabled,
      lastSyncedText: lastSyncedText ?? this.lastSyncedText,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      syncCount: syncCount ?? this.syncCount,
      lastError: lastError,
      statusMessage: statusMessage ?? this.statusMessage,
      onlineDeviceCount: onlineDeviceCount ?? this.onlineDeviceCount,
    );
  }
}

class ClipboardSyncService extends Notifier<ClipboardSyncState> {
  final Ref _ref;
  Timer? _pollTimer;
  Timer? _discoveryTimer;
  StreamSubscription? _nearbyDevicesSubscription;
  String _lastLocalText = '';
  // ignore: prefer_final_fields
  String _lastRemoteText = '';
  String _pendingText = '';
  DateTime? _pendingSince;
  bool _suppressNext = false;
  bool _syncing = false;
  bool _retryAfterCurrentSync = false;
  bool _backgroundScanRunning = false;
  int _discoveryTick = 0;

  ClipboardSyncService(this._ref);

  @override
  ClipboardSyncState init() {
    _nearbyDevicesSubscription = _ref.stream(nearbyDevicesProvider).listen((event) {
      if (shouldWakeClipboardAfterNearbyDevicesChange(event.prev, event.next)) {
        notifyDeviceRegistered();
      }
    });
    return const ClipboardSyncState();
  }

  void enable() {
    if (state.enabled) return;
    unawaited(_ref.read(persistenceProvider).setClipboardSyncEnabled(true));
    state = state.copyWith(
      enabled: true,
      statusMessage: '剪切板同步常驻运行中，正在发现附近设备',
      lastError: null,
    );
    _startPolling();
    _startDiscovery();
    _logger.info('Clipboard sync enabled');
  }

  void disable() {
    if (!state.enabled) return;
    unawaited(_ref.read(persistenceProvider).setClipboardSyncEnabled(false));
    _stopPolling();
    _stopDiscovery();
    _pendingText = '';
    _pendingSince = null;
    state = state.copyWith(
      enabled: false,
      statusMessage: '剪切板同步已关闭',
      lastError: null,
    );
    _logger.info('Clipboard sync disabled');
  }

  /// 启动时按持久化状态恢复“已暂停”，避免重启后静默恢复同步。
  void markPausedOnStartup() {
    if (state.enabled) return;
    state = state.copyWith(
      statusMessage: '剪切板同步已暂停，可在此重新开启',
    );
  }

  void toggle() {
    state.enabled ? disable() : enable();
  }

  void notifyDeviceRegistered() {
    if (!state.enabled) {
      return;
    }

    _refreshOnlineDeviceCount();
    if (_pendingText.isNotEmpty) {
      if (_dropStalePendingIfNeeded()) {
        return;
      }
      if (_syncing) {
        _retryAfterCurrentSync = true;
        state = state.copyWith(
          statusMessage: '已发现新设备，当前同步结束后会立即重试剪切板',
          lastError: state.lastError,
        );
        return;
      }
      unawaited(_sendToAllPeers(_pendingText));
    }
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      unawaited(_checkClipboard());
    });
    unawaited(_checkClipboard());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _startDiscovery() {
    _stopDiscovery();
    _announcePresence();
    _discoveryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _announcePresence();
      _retryPendingText();
    });
  }

  void _stopDiscovery() {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
  }

  void _announcePresence() {
    try {
      final mode = _ref.read(connectionModeProvider);
      if (!shouldRunNetworkClipboardDiscovery(mode)) {
        final bluetooth = _ref.read(classicBluetoothProvider);
        state = state.copyWith(
          onlineDeviceCount: bluetooth.connected ? 1 : 0,
          statusMessage: bluetooth.connected ? '经典蓝牙已连接，复制后将通过 RFCOMM 同步' : '经典蓝牙模式：等待 RFCOMM 常驻连接',
          lastError: state.lastError,
        );
        return;
      }

      _ref.redux(nearbyDevicesProvider).dispatch(StartMulticastScan());
      _refreshOnlineDeviceCount();
      _startBackgroundTcpFallback();
    } catch (e) {
      state = state.copyWith(
        lastError: '自动发现失败：$e',
        statusMessage: '自动发现失败，仍会继续重试',
      );
      _logger.warning('Clipboard discovery announcement failed', e);
    }
  }

  void _startBackgroundTcpFallback() {
    if (_backgroundScanRunning) {
      return;
    }

    final subnets = selectBackgroundDiscoverySubnets(
      localIps: _ref.read(localIpProvider).localIps,
      onlineDeviceCount: state.onlineDeviceCount,
      tick: _discoveryTick++,
    );
    if (subnets.isEmpty) {
      return;
    }

    _backgroundScanRunning = true;
    state = state.copyWith(
      statusMessage: '正在后台扫描局域网 / 热点设备',
      lastError: state.lastError,
    );
    unawaited(
      _ref.global
          .dispatchAsync(StartLegacySubnetScan(subnets: subnets))
          .catchError((e, st) {
            _logger.warning('Background TCP discovery failed', e, st);
            state = state.copyWith(
              lastError: '后台 TCP 扫描失败：$e',
              statusMessage: '后台扫描失败，稍后自动重试',
            );
          })
          .whenComplete(() {
            _backgroundScanRunning = false;
            _refreshOnlineDeviceCount();
            notifyDeviceRegistered();
          }),
    );
  }

  void _refreshOnlineDeviceCount() {
    try {
      final nearbyState = _ref.read(nearbyDevicesProvider);
      final ownFingerprint = _ref.read(securityProvider).certificateHash;
      final devices = selectClipboardSyncTargets(
        nearbyState,
        ownFingerprint: ownFingerprint,
        localIps: _ref.read(localIpProvider).localIps,
      );
      state = state.copyWith(
        onlineDeviceCount: devices.length,
        statusMessage: devices.isEmpty ? '正在后台扫描附近设备' : '已发现 ${devices.length} 台可同步设备',
        lastError: state.lastError,
      );
    } catch (_) {
      // Provider 初始化早期可能还不可读，下一轮定时器会恢复。
    }
  }

  /// 待同步文本超过 TTL 仍未成功时放弃自动重试，避免远端稍后被旧内容覆盖。
  bool _dropStalePendingIfNeeded() {
    if (_pendingText.isEmpty) {
      return false;
    }
    if (!shouldDropStalePendingClipboard(pendingSince: _pendingSince, now: DateTime.now())) {
      return false;
    }
    _pendingText = '';
    _pendingSince = null;
    state = state.copyWith(
      statusMessage: '剪切板超过 2 分钟未同步成功，已放弃自动重试',
      lastError: state.lastError,
    );
    _logger.info('Dropped stale pending clipboard text');
    return true;
  }

  void _retryPendingText() {
    if (_pendingText.isEmpty) {
      return;
    }
    if (_dropStalePendingIfNeeded()) {
      return;
    }
    _sendToAllPeers(_pendingText); // ignore: discarded_futures
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text == null || text.isEmpty || text == _lastLocalText) return;

      if (_suppressNext && text == _lastRemoteText) {
        _suppressNext = false;
        _lastLocalText = text;
        return;
      }
      if (shouldClearRemoteClipboardEchoSuppression(
        suppressNext: _suppressNext,
        clipboardText: text,
        lastRemoteText: _lastRemoteText,
      )) {
        _suppressNext = false;
      }

      _lastLocalText = text;
      _pendingText = text;
      _pendingSince = DateTime.now();
      _logger.info('Local clipboard changed, syncing...');
      await _sendToAllPeers(text);
    } catch (e) {
      state = state.copyWith(
        lastError: '读取剪切板失败：$e',
        statusMessage: '剪切板读取失败，请检查系统权限',
      );
      // 平台可能不支持
    }
  }

  Future<void> _sendToAllPeers(String text) async {
    if (!state.enabled) {
      return;
    }

    if (_syncing) {
      _retryAfterCurrentSync = true;
      return;
    }

    _syncing = true;
    try {
      if (_ref.read(connectionModeProvider) == FluxConnectionMode.classicBluetooth) {
        final sent = await _ref.notifier(classicBluetoothProvider).sendClipboard(text);
        if (sent) {
          _pendingText = resolvePendingClipboardAfterSuccessfulSend(
            sentText: text,
            pendingText: _pendingText,
          );
          if (_pendingText.isEmpty) {
            _pendingSince = null;
          }
          state = state.copyWith(
            lastSyncedText: text,
            lastSyncTime: DateTime.now(),
            syncCount: state.syncCount + 1,
            onlineDeviceCount: _ref.read(classicBluetoothProvider).connected ? 1 : 0,
            statusMessage: '已通过经典蓝牙同步到已连接设备',
            lastError: null,
          );
          unawaited(_ref.notifier(clipboardTimelineProvider).add(text: text, sent: true, peerAlias: '经典蓝牙'));
        } else {
          state = state.copyWith(
            onlineDeviceCount: _ref.read(classicBluetoothProvider).connected ? 1 : 0,
            statusMessage: '经典蓝牙尚未连接，已保留本次剪切板并等待重试',
            lastError: _ref.read(classicBluetoothProvider).lastError ?? '经典蓝牙未连接',
          );
        }
        return;
      }

      final nearbyState = _ref.read(nearbyDevicesProvider);
      final ownFingerprint = _ref.read(securityProvider).certificateHash;
      final devices = selectClipboardSyncTargets(
        nearbyState,
        ownFingerprint: ownFingerprint,
        localIps: _ref.read(localIpProvider).localIps,
      );
      state = state.copyWith(
        onlineDeviceCount: devices.length,
        lastError: state.lastError,
      );
      if (devices.isEmpty) {
        _logger.info('No nearby devices found, skipping clipboard sync');
        state = state.copyWith(
          statusMessage: '没有发现可同步设备，已保留本次剪切板并继续扫描',
          onlineDeviceCount: 0,
          lastError: null,
        );
        return;
      }

      int successCount = 0;
      final failures = <String>[];
      for (final device in devices) {
        final ip = device.ip!;

        try {
          await _sendToDevice(ip, device.port, device.https, text, expectedFingerprint: device.fingerprint);
          successCount++;
        } catch (e) {
          _logger.warning('Failed to send clipboard to $ip: $e');
          failures.add(
            describeClipboardPeerSendFailure(
              alias: device.alias,
              ip: ip,
              error: e,
            ),
          );
        }
      }

      if (successCount > 0) {
        _pendingText = resolvePendingClipboardAfterSendAttempt(
          sentText: text,
          pendingText: _pendingText,
          attemptedCount: devices.length,
          successCount: successCount,
        );
        if (_pendingText.isEmpty) {
          _pendingSince = null;
        }
        state = state.copyWith(
          lastSyncedText: text,
          lastSyncTime: DateTime.now(),
          syncCount: state.syncCount + 1,
          onlineDeviceCount: devices.length,
          statusMessage: successCount == devices.length ? '已同步到 $successCount 台设备' : '已同步到 $successCount/${devices.length} 台设备，失败设备稍后自动重试',
          lastError: failures.isEmpty ? null : describeClipboardSyncFailureSummary(failures),
        );
        unawaited(_ref.notifier(clipboardTimelineProvider).add(text: text, sent: true, peerAlias: '$successCount 台设备'));
        _logger.info('Clipboard synced to $successCount device(s)');
      } else {
        final failureSummary = describeClipboardSyncFailureSummary(failures);
        state = state.copyWith(
          statusMessage: '同步发送失败，稍后自动重试',
          lastError: failureSummary,
        );
      }
    } catch (e) {
      _logger.warning('Clipboard sync error: $e');
      state = state.copyWith(
        lastError: e.toString(),
        statusMessage: '剪切板同步异常，稍后自动重试',
      );
    } finally {
      _syncing = false;
      final retryQueuedDuringSend = _retryAfterCurrentSync;
      _retryAfterCurrentSync = false;
      final retryDue = shouldRetryPendingClipboardAfterSend(
        enabled: state.enabled,
        pendingText: _pendingText,
        sentText: text,
        retryQueuedDuringSend: retryQueuedDuringSend,
      );
      if (retryDue && !_dropStalePendingIfNeeded()) {
        unawaited(_sendToAllPeers(_pendingText));
      }
    }
  }

  Future<void> _sendToDevice(
    String ip,
    int port,
    bool https,
    String text, {
    String? expectedFingerprint,
  }) async {
    final url = buildClipboardSyncUri(ip: ip, port: port, https: https);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3)
      ..badCertificateCallback = (cert, host, port) {
        // 自签证书体系下以“证书指纹 == 对端设备指纹”作为身份校验，防止中间人截获剪切板。
        final matches = matchesCertificateBytes(der: cert.der, expectedFingerprint: expectedFingerprint ?? '');
        if (!matches) {
          _logger.warning('Clipboard TLS certificate fingerprint mismatch for $host:$port');
        }
        return matches;
      };
    try {
      final request = await client.postUrl(url);
      request.headers.set('Content-Type', 'text/plain; charset=utf-8');
      request.write(text);
      final response = await request.close().timeout(const Duration(seconds: 3));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final failureMessage = await readClipboardSyncFailureMessage(response);
        throw HttpException('剪切板同步失败：$failureMessage');
      }
      await response.drain();
    } finally {
      client.close();
    }
  }

  /// 接收远端剪切板（由 server 路由调用）
  Future<bool> handleIncomingClipboard(String text) async {
    if (text.isEmpty) return true;

    if (!state.enabled) {
      state = state.copyWith(
        statusMessage: '远端剪切板已拒收：本机剪切板同步已暂停',
        lastError: '远端剪切板已拒收：本机剪切板同步已暂停',
      );
      return false;
    }

    if (!shouldWriteIncomingClipboard(
      incomingText: text,
      lastRemoteText: _lastRemoteText,
      lastLocalText: _lastLocalText,
    )) {
      return true;
    }

    _logger.info('Received remote clipboard (${text.length} chars)');

    try {
      await Clipboard.setData(ClipboardData(text: text));
      _lastRemoteText = text;
      _lastLocalText = text;
      _suppressNext = true;
      state = state.copyWith(
        lastSyncedText: text,
        lastSyncTime: DateTime.now(),
        syncCount: state.syncCount + 1,
        statusMessage: describeIncomingClipboardStatus(text),
        lastError: null,
      );
      unawaited(
        _ref.notifier(clipboardTimelineProvider).add(text: text, sent: false, peerAlias: '远端设备'),
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        statusMessage: '写入系统剪切板失败',
        lastError: '写入系统剪切板失败：$e',
      );
      return false;
    }
  }

  @override
  void dispose() {
    _stopPolling();
    _stopDiscovery();
    unawaited(_nearbyDevicesSubscription?.cancel());
    super.dispose();
  }
}
