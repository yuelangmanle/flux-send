import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:common/model/file_type.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/provider/clipboard_sync_provider.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/provider/receive_history_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/native/classic_bluetooth_bridge.dart';
import 'package:localsend_app/util/native/directories.dart';
import 'package:localsend_app/util/native/file_saver.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:uri_content/uri_content.dart';
import 'package:uuid/uuid.dart';

final _logger = Logger('ClassicBluetooth');
const _uuid = Uuid();
const _bluetoothFileChunkBytes = 24 * 1024;

final classicBluetoothProvider = NotifierProvider<ClassicBluetoothService, ClassicBluetoothState>((ref) {
  return ClassicBluetoothService(ref);
});

class ClassicBluetoothState {
  final List<ClassicBluetoothDevice> pairedDevices;
  final bool listening;
  final bool connected;
  final bool refreshing;
  final bool connecting;
  final String? connectedAddress;
  final String statusMessage;
  final String? lastError;

  const ClassicBluetoothState({
    this.pairedDevices = const [],
    this.listening = false,
    this.connected = false,
    this.refreshing = false,
    this.connecting = false,
    this.connectedAddress,
    this.statusMessage = '经典蓝牙未启动',
    this.lastError,
  });

  ClassicBluetoothState copyWith({
    List<ClassicBluetoothDevice>? pairedDevices,
    bool? listening,
    bool? connected,
    bool? refreshing,
    bool? connecting,
    String? connectedAddress,
    bool clearConnectedAddress = false,
    String? statusMessage,
    String? lastError,
    bool clearLastError = false,
  }) {
    return ClassicBluetoothState(
      pairedDevices: pairedDevices ?? this.pairedDevices,
      listening: listening ?? this.listening,
      connected: connected ?? this.connected,
      refreshing: refreshing ?? this.refreshing,
      connecting: connecting ?? this.connecting,
      connectedAddress: clearConnectedAddress ? null : (connectedAddress ?? this.connectedAddress),
      statusMessage: statusMessage ?? this.statusMessage,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}

class _IncomingBluetoothFile {
  final String id;
  final String fileName;
  final FileType fileType;
  final int expectedSize;
  final File partFile;
  final IOSink sink;
  int receivedBytes = 0;
  DateTime lastProgressUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  bool _failed = false;

  _IncomingBluetoothFile({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.expectedSize,
  }) : partFile = File('${Directory.systemTemp.path}/flux_bt_$id.part'),
       sink = File('${Directory.systemTemp.path}/flux_bt_$id.part').openWrite();

  /// 追加一块数据；返回 false 表示该传输已失败，应忽略后续块。
  bool addChunk(Uint8List chunk) {
    if (_failed) {
      return false;
    }
    try {
      sink.add(chunk);
      receivedBytes += chunk.length;
      return true;
    } catch (e) {
      _failed = true;
      _logger.warning('Writing Bluetooth chunk failed for $fileName', e);
      return false;
    }
  }

  Future<void> discard() async {
    _failed = true;
    try {
      await sink.flush();
      await sink.close();
    } catch (_) {}
    try {
      await partFile.delete();
    } catch (_) {}
  }
}

bool shouldTreatClassicBluetoothErrorAsDisconnect({
  required bool connecting,
  required bool connected,
  String message = '',
}) {
  if (connecting && !connected) {
    return true;
  }
  if (!connected) {
    return false;
  }

  final normalizedMessage = message.toLowerCase();
  return normalizedMessage.contains('broken pipe') ||
      normalizedMessage.contains('socket closed') ||
      normalizedMessage.contains('connection reset') ||
      normalizedMessage.contains('software caused connection abort') ||
      normalizedMessage.contains('connection refused') ||
      normalizedMessage.contains('not connected') ||
      normalizedMessage.contains('经典蓝牙发送未确认') ||
      normalizedMessage.contains('经典蓝牙未连接') ||
      normalizedMessage.contains('无法发送剪切板') ||
      RegExp(r'发送失败[:：]\s*\d+').hasMatch(normalizedMessage);
}

bool shouldRestartClassicBluetoothListenerOnDisconnect({
  required bool manualStopRequested,
  required bool disposed,
}) {
  return !manualStopRequested && !disposed;
}

bool shouldAutoReconnectClassicBluetooth({
  required bool manualStopRequested,
  required bool disposed,
  required bool connecting,
  required bool connected,
  required String? lastConnectedAddress,
}) {
  return !manualStopRequested && !disposed && !connecting && !connected && lastConnectedAddress != null && lastConnectedAddress.trim().isNotEmpty;
}

Duration classicBluetoothReconnectDelay(int attempt) {
  if (attempt <= 0) {
    return const Duration(seconds: 2);
  }
  if (attempt == 1) {
    return const Duration(seconds: 5);
  }
  if (attempt == 2) {
    return const Duration(seconds: 10);
  }
  return const Duration(seconds: 15);
}

/// 连续握手失败达到该次数后停止自动重连：对端大概率不是 Flux 或版本过旧，
/// 继续重连只会无限循环。
const classicBluetoothHandshakeFailureReconnectLimit = 3;

/// 与原生桥约定的结构化断开代码（Kotlin/Swift 同步维护）。
const classicBluetoothCodeHandshakeSendFailed = 'HANDSHAKE_SEND_FAILED';
const classicBluetoothCodeHandshakeAckSendFailed = 'HANDSHAKE_ACK_SEND_FAILED';
const classicBluetoothCodeHandshakeIncomplete = 'HANDSHAKE_INCOMPLETE';
const classicBluetoothCodePeerNotFlux = 'PEER_NOT_FLUX';

bool isClassicBluetoothHandshakeFailureCode(String? code) {
  return code == classicBluetoothCodeHandshakeSendFailed ||
      code == classicBluetoothCodeHandshakeAckSendFailed ||
      code == classicBluetoothCodeHandshakeIncomplete ||
      code == classicBluetoothCodePeerNotFlux;
}

bool isClassicBluetoothHandshakeFailureMessage(String message) {
  return message.contains('对端不是 Flux') || message.contains('握手未完成') || message.contains('握手发送失败') || message.contains('握手确认发送失败');
}

bool shouldStopClassicBluetoothAutoReconnect({required int handshakeFailureStreak}) {
  return handshakeFailureStreak >= classicBluetoothHandshakeFailureReconnectLimit;
}

ClassicBluetoothState applyClassicBluetoothSendFailure(
  ClassicBluetoothState state,
  String message,
) {
  final disconnected = shouldTreatClassicBluetoothErrorAsDisconnect(
    connecting: state.connecting,
    connected: state.connected,
    message: message,
  );
  return state.copyWith(
    connected: disconnected ? false : state.connected,
    connecting: false,
    clearConnectedAddress: disconnected,
    lastError: message,
    statusMessage: message.isEmpty ? '经典蓝牙剪切板发送失败' : message,
  );
}

class ClassicBluetoothService extends Notifier<ClassicBluetoothState> {
  static const _connectionTimeoutDuration = Duration(seconds: 18);
  final Ref _ref;
  StreamSubscription<Map<String, dynamic>>? _events;
  Timer? _connectionTimeout;
  Timer? _reconnectTimer;
  final Map<String, _IncomingBluetoothFile> _incomingFiles = {};
  final Set<String> _createdBluetoothDirectories = {};
  ClassicBluetoothDevice? _lastConnectedDevice;
  int _reconnectAttempt = 0;
  int _handshakeFailureStreak = 0;
  bool _manualStopRequested = false;
  bool _disposed = false;

  ClassicBluetoothService(this._ref);

  @override
  ClassicBluetoothState init() {
    unawaited(
      Future.microtask(() {
        _events = classicBluetoothEvents.listen(
          _handleEvent,
          onError: (Object error, StackTrace stackTrace) {
            _logger.warning('Classic Bluetooth event stream failed', error, stackTrace);
            state = state.copyWith(
              lastError: '经典蓝牙事件通道异常：$error',
              statusMessage: '经典蓝牙事件通道异常',
            );
          },
        );
      }),
    );
    return const ClassicBluetoothState(statusMessage: '经典蓝牙待命：切换到蓝牙或点击刷新后启动 RFCOMM 常驻通道');
  }

  Future<void> refreshPairedDevices() async {
    state = state.copyWith(refreshing: true, clearLastError: true, statusMessage: '正在读取系统已配对蓝牙设备');
    try {
      final devices = await listClassicBluetoothPairedDevices();
      state = state.copyWith(
        pairedDevices: devices,
        refreshing: false,
        statusMessage: devices.isEmpty ? '未发现已配对蓝牙设备，请先在系统蓝牙设置中配对' : '已读取 ${devices.length} 台已配对蓝牙设备',
        clearLastError: true,
      );
    } catch (e, st) {
      _logger.warning('Reading paired Bluetooth devices failed', e, st);
      state = state.copyWith(
        refreshing: false,
        lastError: '读取已配对蓝牙设备失败：$e',
        statusMessage: '读取已配对蓝牙设备失败',
      );
    }
  }

  Future<bool> startListening() async {
    if (_disposed) {
      return false;
    }
    _manualStopRequested = false;
    try {
      final listening = await startClassicBluetoothServer();
      if (_disposed || _manualStopRequested) {
        return false;
      }
      if (!listening) {
        state = state.copyWith(
          listening: false,
          lastError: '经典蓝牙监听启动失败：原生服务未确认监听成功',
          statusMessage: '经典蓝牙监听启动失败，请检查蓝牙权限和系统蓝牙状态',
        );
        return false;
      }
      state = state.copyWith(
        listening: true,
        statusMessage: '经典蓝牙 RFCOMM 常驻通道监听中，等待已配对设备连接',
        clearLastError: true,
      );
      return true;
    } catch (e, st) {
      _logger.warning('Starting classic Bluetooth server failed', e, st);
      state = state.copyWith(
        listening: false,
        lastError: '经典蓝牙监听启动失败：$e',
        statusMessage: '经典蓝牙监听启动失败',
      );
      return false;
    }
  }

  Future<void> connect(ClassicBluetoothDevice device, {bool automatic = false}) async {
    if (_disposed) {
      return;
    }
    _manualStopRequested = false;
    _connectionTimeout?.cancel();
    _reconnectTimer?.cancel();
    _lastConnectedDevice = device;
    if (!automatic) {
      _reconnectAttempt = 0;
      _handshakeFailureStreak = 0;
    }
    state = state.copyWith(
      connecting: true,
      connected: false,
      connectedAddress: device.address,
      statusMessage: automatic ? '正在自动重连经典蓝牙设备：${device.displayName}' : '正在连接经典蓝牙设备：${device.displayName}',
      clearLastError: true,
    );
    _connectionTimeout = Timer(_connectionTimeoutDuration, () {
      if (!state.connecting || state.connected || state.connectedAddress != device.address) {
        return;
      }
      state = state.copyWith(
        connecting: false,
        connected: false,
        clearConnectedAddress: true,
        lastError: '经典蓝牙连接超时：请确认两端已在系统蓝牙设置配对、蓝牙已开启，并让另一端 Flux 保持打开。',
        statusMessage: '经典蓝牙连接超时，已进入自动重连队列',
      );
      _scheduleReconnectIfNeeded();
    });
    try {
      await connectClassicBluetoothDevice(device.address);
      if (!state.connecting || state.connected || state.connectedAddress != device.address) {
        return;
      }
      state = state.copyWith(
        connectedAddress: device.address,
        statusMessage: '等待经典蓝牙握手确认：${device.displayName}',
        clearLastError: true,
      );
    } catch (e, st) {
      _connectionTimeout?.cancel();
      _logger.warning('Connecting classic Bluetooth device failed', e, st);
      state = state.copyWith(
        connecting: false,
        connected: false,
        clearConnectedAddress: true,
        lastError: '经典蓝牙连接失败：$e',
        statusMessage: '经典蓝牙连接失败',
      );
      _scheduleReconnectIfNeeded();
    }
  }

  Future<bool> sendClipboard(String text) async {
    if (!state.connected) {
      return false;
    }

    try {
      final sent = await sendClassicBluetoothClipboard(text);
      if (!sent) {
        state = applyClassicBluetoothSendFailure(
          state,
          '经典蓝牙发送未确认',
        );
        _scheduleReconnectIfNeeded();
        return false;
      }
      state = state.copyWith(statusMessage: '经典蓝牙剪切板已发送', clearLastError: true);
      return true;
    } catch (e, st) {
      _logger.warning('Sending classic Bluetooth clipboard failed', e, st);
      state = applyClassicBluetoothSendFailure(
        state,
        '经典蓝牙剪切板发送失败：$e',
      );
      _scheduleReconnectIfNeeded();
      return false;
    }
  }

  Future<bool> sendFiles(List<CrossFile> files) async {
    if (!state.connected) {
      state = state.copyWith(
        lastError: '经典蓝牙未连接，无法发送文件',
        statusMessage: '经典蓝牙未连接，文件不会回退到局域网发送',
      );
      return false;
    }

    if (files.isEmpty) {
      return true;
    }

    try {
      for (final file in files) {
        final sent = await _sendFile(file);
        if (!sent) {
          state = applyClassicBluetoothSendFailure(state, '经典蓝牙文件发送未确认');
          _scheduleReconnectIfNeeded();
          return false;
        }
      }
      state = state.copyWith(statusMessage: '已通过经典蓝牙发送 ${files.length} 个文件', clearLastError: true);
      return true;
    } catch (e, st) {
      _logger.warning('Sending classic Bluetooth files failed', e, st);
      state = applyClassicBluetoothSendFailure(
        state,
        '经典蓝牙文件发送失败：$e',
      );
      _scheduleReconnectIfNeeded();
      return false;
    }
  }

  Future<bool> _sendFile(CrossFile file) async {
    final id = _uuid.v4();
    final begin = jsonEncode({
      'type': fluxBluetoothFileBegin,
      'id': id,
      'name': file.name,
      'size': file.size,
      'fileType': file.fileType.name,
    });
    if (!await sendClassicBluetoothFrame(begin)) {
      return false;
    }

    var sentBytes = 0;
    await for (final chunk in _openCrossFileStream(file)) {
      var offset = 0;
      while (offset < chunk.length) {
        final end = offset + _bluetoothFileChunkBytes < chunk.length ? offset + _bluetoothFileChunkBytes : chunk.length;
        final slice = Uint8List.fromList(chunk.sublist(offset, end));
        final payload = jsonEncode({
          'type': fluxBluetoothFileChunk,
          'id': id,
          'data': base64Encode(slice),
        });
        if (!await sendClassicBluetoothFrame(payload)) {
          return false;
        }
        sentBytes += slice.length;
        offset = end;
        state = state.copyWith(
          statusMessage: '经典蓝牙正在发送 ${file.name}：$sentBytes/${file.size} B',
          clearLastError: true,
        );
      }
    }

    return await sendClassicBluetoothFrame(
      jsonEncode({
        'type': fluxBluetoothFileEnd,
        'id': id,
      }),
    );
  }

  Stream<Uint8List> _openCrossFileStream(CrossFile file) async* {
    if (file.bytes != null) {
      yield Uint8List.fromList(file.bytes!);
      return;
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      throw '文件没有可读取路径：${file.name}';
    }

    final Stream<List<int>> stream = path.startsWith('content://') ? UriContent().getContentStream(Uri.parse(path)) : File(path).openRead();
    await for (final chunk in stream) {
      yield Uint8List.fromList(chunk);
    }
  }

  void _handleEvent(Map<String, dynamic> event) {
    if (_disposed) {
      return;
    }
    final type = event['type']?.toString();
    final message = event['message']?.toString() ?? '';
    final address = event['address']?.toString();
    final code = event['code']?.toString();

    if (event['type'] == 'clipboard') {
      final text = _extractClipboardText(message);
      unawaited(_handleIncomingClipboardEvent(text));
      return;
    }

    if (event['type'] == 'message' && _handleIncomingFileFrame(message)) {
      return;
    }

    switch (type) {
      case 'status':
        state = state.copyWith(statusMessage: message, clearLastError: true);
      case 'listening':
        state = state.copyWith(listening: true, statusMessage: message, clearLastError: true);
      case 'connected':
        _connectionTimeout?.cancel();
        _reconnectTimer?.cancel();
        _reconnectAttempt = 0;
        _handshakeFailureStreak = 0;
        if (address != null && address.isNotEmpty) {
          _lastConnectedDevice = ClassicBluetoothDevice(
            address: address,
            name: event['name']?.toString() ?? _lastConnectedDevice?.name ?? address,
          );
        }
        state = state.copyWith(
          connected: true,
          connecting: false,
          connectedAddress: address == null || address.isEmpty ? state.connectedAddress : address,
          statusMessage: message,
          clearLastError: true,
        );
        _ref.notifier(clipboardSyncProvider).notifyDeviceRegistered();
      case 'sent':
        state = state.copyWith(statusMessage: message, clearLastError: true);
      case 'stopped':
        _connectionTimeout?.cancel();
        _handshakeFailureStreak = 0;
        _discardIncomingFiles();
        state = state.copyWith(
          listening: false,
          connected: false,
          connecting: false,
          clearConnectedAddress: true,
          statusMessage: message,
          clearLastError: true,
        );
      case 'disconnected':
        _connectionTimeout?.cancel();
        _discardIncomingFiles();
        // 优先使用结构化代码判断；旧版本对端的纯文案走 message 匹配 fallback。
        final handshakeFailure = isClassicBluetoothHandshakeFailureCode(code) ||
            (code == null && isClassicBluetoothHandshakeFailureMessage(message));
        if (handshakeFailure) {
          _handshakeFailureStreak += 1;
        } else {
          _handshakeFailureStreak = 0;
        }
        final stopReconnect = shouldStopClassicBluetoothAutoReconnect(handshakeFailureStreak: _handshakeFailureStreak);
        state = state.copyWith(
          connected: false,
          connecting: false,
          clearConnectedAddress: true,
          statusMessage: stopReconnect ? '对方可能不是 Flux 或版本过旧，已停止自动重连；可手动重连或改用局域网' : (message.isEmpty ? '经典蓝牙连接已断开' : message),
          clearLastError: true,
        );
        if (shouldRestartClassicBluetoothListenerOnDisconnect(
          manualStopRequested: _manualStopRequested,
          disposed: _disposed,
        )) {
          unawaited(startListening());
        }
        if (!stopReconnect) {
          _scheduleReconnectIfNeeded();
        }
      case 'error':
        _connectionTimeout?.cancel();
        final disconnected = shouldTreatClassicBluetoothErrorAsDisconnect(
          connecting: state.connecting,
          connected: state.connected,
          message: message,
        );
        final listenerFailed = message.contains('服务') || message.contains('监听');
        state = state.copyWith(
          connecting: false,
          connected: disconnected ? false : state.connected,
          listening: listenerFailed ? false : state.listening,
          clearConnectedAddress: disconnected,
          lastError: message,
          statusMessage: message.isEmpty ? '经典蓝牙异常' : message,
        );
        if (disconnected) {
          _scheduleReconnectIfNeeded();
        }
      default:
        if (message.isNotEmpty) {
          state = state.copyWith(statusMessage: message);
        }
    }
  }

  String _extractClipboardText(String message) {
    try {
      final decoded = jsonDecode(message);
      if (decoded is Map && decoded['text'] is String) {
        return decoded['text'] as String;
      }
    } catch (_) {}
    return message;
  }

  Future<void> _handleIncomingClipboardEvent(String text) async {
    final accepted = await _ref.notifier(clipboardSyncProvider).handleIncomingClipboard(text);
    if (_disposed) {
      return;
    }
    if (accepted) {
      state = state.copyWith(statusMessage: '经典蓝牙已接收剪切板（${text.length} 字符）', clearLastError: true);
      return;
    }
    final clipboardError = _ref.read(clipboardSyncProvider).lastError;
    state = state.copyWith(
      statusMessage: '经典蓝牙剪切板已拒收',
      lastError: clipboardError ?? '经典蓝牙剪切板写入失败',
    );
  }

  bool _handleIncomingFileFrame(String message) {
    final Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(message);
      if (raw is! Map) {
        return false;
      }
      decoded = raw.cast<String, dynamic>();
    } catch (_) {
      return false;
    }

    final type = decoded['type']?.toString();
    final id = decoded['id']?.toString();
    if (id == null || id.isEmpty) {
      return false;
    }

    switch (type) {
      case fluxBluetoothFileBegin:
        final fileName = decoded['name']?.toString() ?? 'bluetooth-file';
        final fileTypeName = decoded['fileType']?.toString();
        final fileType = FileType.values.firstWhere(
          (type) => type.name == fileTypeName,
          orElse: () => FileType.other,
        );
        final size = decoded['size'] is int ? decoded['size'] as int : int.tryParse(decoded['size']?.toString() ?? '') ?? 0;
        try {
          _incomingFiles[id] = _IncomingBluetoothFile(
            id: id,
            fileName: fileName,
            fileType: fileType,
            expectedSize: size,
          );
        } catch (e) {
          _logger.warning('Creating Bluetooth temp file failed', e);
          state = state.copyWith(
            lastError: '经典蓝牙接收文件失败：无法创建临时文件',
            statusMessage: '经典蓝牙接收文件失败',
          );
          return true;
        }
        state = state.copyWith(statusMessage: '经典蓝牙开始接收文件：$fileName', clearLastError: true);
        return true;
      case fluxBluetoothFileChunk:
        final transfer = _incomingFiles[id];
        final data = decoded['data']?.toString();
        if (transfer == null || data == null) {
          return true;
        }
        final bytes = base64Decode(data);
        if (!transfer.addChunk(Uint8List.fromList(bytes))) {
          _incomingFiles.remove(id);
          unawaited(transfer.discard());
          state = state.copyWith(
            lastError: '经典蓝牙接收文件失败：${transfer.fileName} 写入失败',
            statusMessage: '经典蓝牙接收文件失败',
          );
          return true;
        }
        // 进度文案 100ms 节流，避免大文件期间每块都触发整页重建。
        final now = DateTime.now();
        if (now.difference(transfer.lastProgressUpdate) >= const Duration(milliseconds: 100)) {
          transfer.lastProgressUpdate = now;
          state = state.copyWith(
            statusMessage: '经典蓝牙正在接收 ${transfer.fileName}：${transfer.receivedBytes}/${transfer.expectedSize} B',
            clearLastError: true,
          );
        }
        return true;
      case fluxBluetoothFileEnd:
        unawaited(_finishIncomingFile(id));
        return true;
      default:
        return false;
    }
  }

  Future<void> _finishIncomingFile(String id) async {
    final transfer = _incomingFiles.remove(id);
    if (transfer == null) {
      return;
    }

    try {
      await transfer.sink.flush();
      await transfer.sink.close();
      if (transfer.expectedSize > 0 && transfer.receivedBytes != transfer.expectedSize) {
        await transfer.discard();
        state = state.copyWith(
          lastError: '经典蓝牙接收文件失败：${transfer.fileName} 大小不匹配（收到 ${transfer.receivedBytes}，预期 ${transfer.expectedSize}）',
          statusMessage: '经典蓝牙接收文件失败',
        );
        return;
      }
      state = state.copyWith(statusMessage: '经典蓝牙正在保存文件：${transfer.fileName}', clearLastError: true);
      final settings = _ref.read(settingsProvider);
      final destination = settings.destination ?? await getDefaultDestinationDirectory();
      final shouldSaveToGallery = settings.saveToGallery && (transfer.fileType == FileType.image || transfer.fileType == FileType.video);
      final (savedToGallery, filePath) = await saveFile(
        destinationDirectory: destination,
        fileName: transfer.fileName,
        saveToGallery: shouldSaveToGallery,
        isImage: transfer.fileType == FileType.image,
        stream: transfer.partFile.openRead().map(Uint8List.fromList),
        onProgress: (_) {},
        androidSdkInt: _ref.read(deviceInfoProvider).androidSdkInt,
        createdDirectories: _createdBluetoothDirectories,
      );
      await _ref
          .redux(receiveHistoryProvider)
          .dispatchAsync(
            AddHistoryEntryAction(
              entryId: id,
              fileName: transfer.fileName,
              fileType: transfer.fileType,
              path: filePath,
              savedToGallery: savedToGallery,
              isMessage: false,
              fileSize: transfer.receivedBytes,
              senderAlias: '经典蓝牙',
              timestamp: DateTime.now().toUtc(),
            ),
          );
      unawaited(transfer.partFile.delete().then<void>((_) {}, onError: (Object _) {}));
      state = state.copyWith(
        statusMessage: '已通过经典蓝牙接收文件：${transfer.fileName}',
        clearLastError: true,
      );
    } catch (e, st) {
      unawaited(transfer.partFile.delete().then<void>((_) {}, onError: (Object _) {}));
      _logger.warning('Saving incoming Bluetooth file failed', e, st);
      state = state.copyWith(
        lastError: '经典蓝牙文件保存失败：$e',
        statusMessage: '经典蓝牙文件保存失败',
      );
    }
  }

  /// 断连、停止或销毁时清理所有未完成的蓝牙接收（关闭并删除临时文件）。
  void _discardIncomingFiles() {
    for (final transfer in _incomingFiles.values) {
      unawaited(transfer.discard());
    }
    _incomingFiles.clear();
  }

  Future<void> stop() async {
    _manualStopRequested = true;
    _connectionTimeout?.cancel();
    _reconnectTimer?.cancel();
    await stopClassicBluetooth();
    if (_disposed) {
      return;
    }
    state = state.copyWith(
      listening: false,
      connected: false,
      connecting: false,
      clearConnectedAddress: true,
      statusMessage: '经典蓝牙已停止',
      clearLastError: true,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _manualStopRequested = true;
    _connectionTimeout?.cancel();
    _reconnectTimer?.cancel();
    _discardIncomingFiles();
    unawaited(_events?.cancel());
    unawaited(stopClassicBluetooth());
    super.dispose();
  }

  void _scheduleReconnectIfNeeded() {
    final device = _lastConnectedDevice;
    if (!shouldAutoReconnectClassicBluetooth(
      manualStopRequested: _manualStopRequested,
      disposed: _disposed,
      connecting: state.connecting,
      connected: state.connected,
      lastConnectedAddress: device?.address,
    )) {
      return;
    }

    _reconnectTimer?.cancel();
    final delay = classicBluetoothReconnectDelay(_reconnectAttempt++);
    state = state.copyWith(
      statusMessage: '经典蓝牙已断开，${delay.inSeconds} 秒后自动重连：${device!.displayName}',
      lastError: state.lastError,
    );
    _reconnectTimer = Timer(delay, () {
      if (!shouldAutoReconnectClassicBluetooth(
        manualStopRequested: _manualStopRequested,
        disposed: _disposed,
        connecting: state.connecting,
        connected: state.connected,
        lastConnectedAddress: device.address,
      )) {
        return;
      }
      unawaited(connect(device, automatic: true));
    });
  }
}

extension ClassicBluetoothDeviceDisplay on ClassicBluetoothDevice {
  String get displayName => name.isEmpty ? address : name;
}
