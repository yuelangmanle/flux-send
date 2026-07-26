import 'dart:io';
import 'package:common/model/device.dart';
import 'package:localsend_app/model/state/nearby_devices_state.dart';
import 'package:localsend_app/provider/clipboard_sync_provider.dart';
import 'package:localsend_app/provider/connection_mode_provider.dart';
import 'package:test/test.dart';

void main() {
  test('selects only reachable non-self devices for clipboard sync', () {
    final state = NearbyDevicesState(
      runningFavoriteScan: false,
      runningIps: const {},
      devices: {
        '10.0.0.2': _device(ip: '10.0.0.2', fingerprint: 'self'),
        '10.0.0.3': _device(ip: '10.0.0.3', fingerprint: 'phone'),
      },
      signalingDevices: {
        'relay-only': {
          _device(ip: null, fingerprint: 'relay-only'),
        },
      },
    );

    final targets = selectClipboardSyncTargets(state, ownFingerprint: 'self');

    expect(targets.map((d) => d.ip), ['10.0.0.3']);
  });

  test('clipboard sync targets exclude local IP even when fingerprint differs', () {
    final state = NearbyDevicesState(
      runningFavoriteScan: false,
      runningIps: const {},
      devices: {
        '10.0.0.2': _device(ip: '10.0.0.2', fingerprint: 'rotated-cert'),
        '10.0.0.3': _device(ip: '10.0.0.3', fingerprint: 'phone'),
      },
      signalingDevices: const {},
    );

    final targets = selectClipboardSyncTargets(
      state,
      ownFingerprint: 'self',
      localIps: const ['10.0.0.2'],
    );

    expect(targets.map((d) => d.ip), ['10.0.0.3']);
  });

  test('deduplicates devices by fingerprint and keeps reachable endpoint', () {
    final state = NearbyDevicesState(
      runningFavoriteScan: false,
      runningIps: const {},
      devices: {
        '10.0.0.4': _device(ip: '10.0.0.4', fingerprint: 'mac'),
      },
      signalingDevices: {
        'mac': {
          _device(ip: null, fingerprint: 'mac'),
        },
      },
    );

    final targets = selectClipboardSyncTargets(state);

    expect(targets, hasLength(1));
    expect(targets.single.ip, '10.0.0.4');
  });

  test('keeps newer pending clipboard text when an older send succeeds', () {
    final pending = resolvePendingClipboardAfterSuccessfulSend(
      sentText: 'older clipboard',
      pendingText: 'newer clipboard',
    );

    expect(pending, 'newer clipboard');
  });

  test('clears pending clipboard text only when the sent text is still current', () {
    final pending = resolvePendingClipboardAfterSuccessfulSend(
      sentText: 'current clipboard',
      pendingText: 'current clipboard',
    );

    expect(pending, isEmpty);
  });

  test('keeps pending clipboard text when only some devices receive it', () {
    expect(
      resolvePendingClipboardAfterSendAttempt(
        sentText: 'current clipboard',
        pendingText: 'current clipboard',
        attemptedCount: 2,
        successCount: 1,
      ),
      'current clipboard',
    );
    expect(
      resolvePendingClipboardAfterSendAttempt(
        sentText: 'current clipboard',
        pendingText: 'current clipboard',
        attemptedCount: 2,
        successCount: 2,
      ),
      isEmpty,
    );
  });

  test('does not retry pending clipboard after sync has been paused', () {
    expect(
      shouldRetryPendingClipboardAfterSend(
        enabled: true,
        pendingText: 'new clipboard',
        sentText: 'old clipboard',
        retryQueuedDuringSend: false,
      ),
      isTrue,
    );
    expect(
      shouldRetryPendingClipboardAfterSend(
        enabled: false,
        pendingText: 'new clipboard',
        sentText: 'old clipboard',
        retryQueuedDuringSend: false,
      ),
      isFalse,
    );
    expect(
      shouldRetryPendingClipboardAfterSend(
        enabled: true,
        pendingText: 'old clipboard',
        sentText: 'old clipboard',
        retryQueuedDuringSend: false,
      ),
      isFalse,
    );
    expect(
      shouldRetryPendingClipboardAfterSend(
        enabled: true,
        pendingText: 'old clipboard',
        sentText: 'old clipboard',
        retryQueuedDuringSend: true,
      ),
      isTrue,
    );
  });

  test('clears remote clipboard echo suppression when the next local clipboard is different', () {
    expect(
      shouldClearRemoteClipboardEchoSuppression(
        suppressNext: true,
        clipboardText: 'local follow-up',
        lastRemoteText: 'remote clipboard',
      ),
      isTrue,
    );
    expect(
      shouldClearRemoteClipboardEchoSuppression(
        suppressNext: true,
        clipboardText: 'remote clipboard',
        lastRemoteText: 'remote clipboard',
      ),
      isFalse,
    );
    expect(
      shouldClearRemoteClipboardEchoSuppression(
        suppressNext: false,
        clipboardText: 'local follow-up',
        lastRemoteText: 'remote clipboard',
      ),
      isFalse,
    );
  });

  test('describes incoming clipboard receive status with text length', () {
    expect(describeIncomingClipboardStatus('hello'), '已接收远端剪切板（5 字符）');
  });

  test('accepts repeated remote clipboard text after the local clipboard diverged', () {
    expect(
      shouldWriteIncomingClipboard(
        incomingText: 'remote clipboard',
        lastRemoteText: 'remote clipboard',
        lastLocalText: 'local follow-up',
      ),
      isTrue,
    );
    expect(
      shouldWriteIncomingClipboard(
        incomingText: 'remote clipboard',
        lastRemoteText: 'remote clipboard',
        lastLocalText: 'remote clipboard',
      ),
      isFalse,
    );
    expect(
      shouldWriteIncomingClipboard(
        incomingText: 'new remote clipboard',
        lastRemoteText: 'old remote clipboard',
        lastLocalText: 'old remote clipboard',
      ),
      isTrue,
    );
  });

  test('incoming clipboard writes are ignored when sync is paused', () {
    final source = File('lib/provider/clipboard_sync_provider.dart').readAsStringSync();
    final handlerIndex = source.indexOf('Future<bool> handleIncomingClipboard(String text) async');
    final emptyCheckIndex = source.indexOf('if (text.isEmpty) return true;', handlerIndex);
    final disabledCheckIndex = source.indexOf('if (!state.enabled)', handlerIndex);
    final setDataIndex = source.indexOf('Clipboard.setData', handlerIndex);

    expect(handlerIndex, isNonNegative);
    expect(disabledCheckIndex, isNonNegative);
    expect(emptyCheckIndex, isNonNegative);
    expect(setDataIndex, isNonNegative);
    expect(disabledCheckIndex, greaterThan(emptyCheckIndex));
    expect(disabledCheckIndex, lessThan(setDataIndex));
    expect(source, contains('远端剪切板已拒收：本机剪切板同步已暂停'));
  });

  test('incoming duplicate clipboard is still rejected while sync is paused', () {
    final source = File('lib/provider/clipboard_sync_provider.dart').readAsStringSync();
    final handlerIndex = source.indexOf('Future<bool> handleIncomingClipboard(String text) async');
    final emptyCheckIndex = source.indexOf('if (text.isEmpty)', handlerIndex);
    final disabledCheckIndex = source.indexOf('if (!state.enabled)', handlerIndex);
    final duplicateCheckIndex = source.indexOf('shouldWriteIncomingClipboard', handlerIndex);

    expect(handlerIndex, isNonNegative);
    expect(emptyCheckIndex, isNonNegative);
    expect(disabledCheckIndex, isNonNegative);
    expect(duplicateCheckIndex, isNonNegative);
    expect(emptyCheckIndex, lessThan(disabledCheckIndex));
    expect(disabledCheckIndex, lessThan(duplicateCheckIndex));
  });

  test('incoming clipboard handler reports receive status and write failures', () {
    final source = File('lib/provider/clipboard_sync_provider.dart').readAsStringSync();

    expect(source, contains('statusMessage: describeIncomingClipboardStatus(text)'));
    expect(source, contains('写入系统剪切板失败'));
  });

  test('clipboard sender includes receiver error message from non-success responses', () {
    final source = File('lib/provider/clipboard_sync_provider.dart').readAsStringSync();

    expect(source, contains('Future<String> readClipboardSyncFailureMessage'));
    expect(source, contains('jsonDecode(body)'));
    expect(source, contains("decoded['message']"));
    expect(source, contains('await readClipboardSyncFailureMessage(response)'));
    expect(source, contains('剪切板同步失败：'));
  });

  test('clipboard sender builds valid URIs for IPv4 hostnames and IPv6 addresses', () {
    expect(
      buildClipboardSyncUri(ip: '10.0.0.23', port: 53317, https: false).toString(),
      'http://10.0.0.23:53317/api/clipboard',
    );
    expect(
      buildClipboardSyncUri(ip: 'my-mac.local', port: 53317, https: true).toString(),
      'https://my-mac.local:53317/api/clipboard',
    );
    expect(
      buildClipboardSyncUri(ip: 'fe80::1', port: 53317, https: false).toString(),
      'http://[fe80::1]:53317/api/clipboard',
    );
  });

  test('clipboard HTTP payload keeps plain text and only unpacks legacy JSON content type', () {
    expect(
      extractClipboardTextFromRequestBody(
        body: '{"text":"不要被拆"}',
        contentType: 'text/plain; charset=utf-8',
      ),
      '{"text":"不要被拆"}',
    );
    expect(
      extractClipboardTextFromRequestBody(
        body: '{"text":"兼容旧包"}',
        contentType: 'application/json',
      ),
      '兼容旧包',
    );
    expect(
      extractClipboardTextFromRequestBody(
        body: '普通剪切板',
        contentType: null,
      ),
      '普通剪切板',
    );
  });

  test('clipboard sender posts text/plain instead of JSON to avoid writing JSON as clipboard text', () {
    final source = File('lib/provider/clipboard_sync_provider.dart').readAsStringSync();
    final sendIndex = source.indexOf('Future<void> _sendToDevice');
    final sendBody = source.substring(sendIndex);

    expect(sendIndex, isNonNegative);
    expect(sendBody, contains("request.headers.set('Content-Type', 'text/plain; charset=utf-8')"));
    expect(sendBody, contains('request.write(text)'));
    expect(sendBody, isNot(contains("request.write(jsonEncode({'text': text}))")));
  });

  test('clipboard sync failure summary keeps per-device receiver reasons', () {
    final summary = describeClipboardSyncFailureSummary([
      describeClipboardPeerSendFailure(
        alias: 'Pixel 8',
        ip: '10.0.0.23',
        error: const HttpException('剪切板同步失败：远端剪切板已拒收：本机剪切板同步已暂停'),
      ),
    ]);

    expect(summary, contains('Pixel 8'));
    expect(summary, contains('10.0.0.23'));
    expect(summary, contains('远端剪切板已拒收：本机剪切板同步已暂停'));
    expect(summary, isNot('未能同步到任何设备'));
  });

  test('routes clipboard sync through classic Bluetooth when that mode is selected', () {
    final source = File('lib/provider/clipboard_sync_provider.dart').readAsStringSync();

    expect(source, contains('connectionModeProvider'));
    expect(source, contains('FluxConnectionMode.classicBluetooth'));
    expect(source, contains('classicBluetoothProvider'));
    expect(source, contains('sendClipboard(text)'));
  });

  test('device registration wakeup queues retry while a clipboard send is already running', () {
    final source = File('lib/provider/clipboard_sync_provider.dart').readAsStringSync();

    expect(source, contains('_retryAfterCurrentSync'));
    expect(source, contains('if (_syncing)'));
    expect(source, contains('_retryAfterCurrentSync = true'));
    expect(source, contains('final retryQueuedDuringSend = _retryAfterCurrentSync'));
    expect(source, contains('retryQueuedDuringSend: retryQueuedDuringSend'));
  });

  test('network clipboard discovery is disabled in classic Bluetooth mode', () {
    expect(shouldRunNetworkClipboardDiscovery(FluxConnectionMode.localNetwork), isTrue);
    expect(shouldRunNetworkClipboardDiscovery(FluxConnectionMode.hotspot), isTrue);
    expect(shouldRunNetworkClipboardDiscovery(FluxConnectionMode.classicBluetooth), isFalse);
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
