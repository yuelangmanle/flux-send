import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('Dart exposes classic Bluetooth native bridge methods', () {
    final source = File('lib/util/native/classic_bluetooth_bridge.dart').readAsStringSync();

    expect(source, contains('startClassicBluetoothServer'));
    expect(source, contains('connectClassicBluetoothDevice'));
    expect(source, contains('sendClassicBluetoothClipboard'));
    expect(source, contains('classicBluetoothEvents'));
    expect(source, contains('fluxBluetoothMessage'));
    expect(source, contains('Future<bool> sendClassicBluetoothClipboard'));
  });

  test('Android implements RFCOMM server, client, read loop, and clipboard send', () {
    final source = File('android/app/src/main/kotlin/org/localsend/localsend_app/ClassicBluetoothBridge.kt').readAsStringSync();

    expect(source, contains('00001101-0000-1000-8000-00805F9B34FB'));
    expect(source, contains('listenUsingRfcommWithServiceRecord'));
    expect(source, contains('createRfcommSocketToServiceRecord'));
    expect(source, contains('BluetoothServerSocket'));
    expect(source, contains('BluetoothSocket'));
    expect(source, contains('sendClipboard'));
    expect(source, contains('result.success(sendClipboard(text))'));
    expect(source, contains('private fun sendClipboard(text: String): Boolean'));
    expect(source, contains('private fun closeActiveSocket(activeSocket: BluetoothSocket, message: String, code: String = codeDisconnected)'));
    expect(source, contains('emitDisconnected: Boolean'));
    expect(source, contains('return false'));
    expect(source, contains('return true'));
    expect(source, contains('emit("disconnected"'));
    expect(source, contains('fluxBluetoothMessage'));
    expect(source, contains('Handler(Looper.getMainLooper())'));
  });

  test('macOS implements IOBluetooth RFCOMM bridge and event callbacks', () {
    final source = File('macos/Runner/ClassicBluetoothBridge.swift').readAsStringSync();

    expect(source, contains('import IOBluetooth'));
    expect(source, contains('publishedServiceRecord'));
    expect(source, contains('getRFCOMMChannelID'));
    expect(source, contains('performSDPQuery'));
    expect(source, contains('register('));
    expect(source, contains('forChannelOpenNotifications'));
    expect(source, contains('getServiceRecord(for:'));
    expect(source, contains('openRFCOMMChannelSync'));
    expect(source, contains('rfcommChannelData'));
    expect(source, contains('sendClipboard'));
    expect(source, contains('private var receiveBuffer = ""'));
    expect(source, contains('while let newlineRange = receiveBuffer.range(of: "\\n")'));
    expect(source, contains('private func handleLine(_ line: String, from rfcommChannel: IOBluetoothRFCOMMChannel)'));
    expect(source, contains('private func sendClipboard(_ text: String) -> Bool'));
    expect(source, contains('fluxBluetoothMessage'));
  });

  test('native bridges require Flux hello acknowledgement before reporting a usable connection', () {
    final android = File('android/app/src/main/kotlin/org/localsend/localsend_app/ClassicBluetoothBridge.kt').readAsStringSync();
    final macos = File('macos/Runner/ClassicBluetoothBridge.swift').readAsStringSync();

    expect(android, contains('flux.bluetooth.hello.v1'));
    expect(android, contains('flux.bluetooth.hello.ack.v1'));
    expect(android, contains('confirmHandshake'));
    expect(macos, contains('flux.bluetooth.hello.v1'));
    expect(macos, contains('flux.bluetooth.hello.ack.v1'));
    expect(macos, contains('confirmHandshake'));
    expect(android, contains('codePeerNotFlux = "PEER_NOT_FLUX"'));
    expect(macos, contains('codePeerNotFlux = "PEER_NOT_FLUX"'));
  });

  test('Android only processes frames from the current RFCOMM socket during handshake', () {
    final android = File('android/app/src/main/kotlin/org/localsend/localsend_app/ClassicBluetoothBridge.kt').readAsStringSync();

    expect(android, contains('while (socket === activeSocket)'));
    expect(android, contains('if (socket !== activeSocket)'));
    expect(android, contains('经典蓝牙连接的对端不是 Flux，已断开'));
  });

  test('Android serializes RFCOMM frame writes against concurrent handshake threads', () {
    final android = File('android/app/src/main/kotlin/org/localsend/localsend_app/ClassicBluetoothBridge.kt').readAsStringSync();
    final synchronizedIndex = android.indexOf('@Synchronized');
    final writeFrameIndex = android.indexOf('private fun writeFrame', synchronizedIndex < 0 ? 0 : synchronizedIndex);

    expect(synchronizedIndex, isNonNegative);
    expect(writeFrameIndex, greaterThan(synchronizedIndex));
  });

  test('macOS closes the channel that carried an unverified message instead of the active channel', () {
    final macos = File('macos/Runner/ClassicBluetoothBridge.swift').readAsStringSync();

    expect(macos, contains('private func rejectUnverifiedMessage(_ message: String, code: String, on rejectedChannel: IOBluetoothRFCOMMChannel?)'));
    expect(macos, contains('handleLine(line, from: rfcommChannel)'));
    expect(macos, contains('rejectedChannel?.close()'));
    expect(macos, isNot(contains('channel?.close()\n    }\n\n    private func emit')));
  });

  test('macOS serializes clipboard strings without NSJSONSerialization object-only crashes', () {
    final macos = File('macos/Runner/ClassicBluetoothBridge.swift').readAsStringSync();

    expect(macos, contains('JSONEncoder().encode(value)'));
    expect(macos, isNot(contains('JSONSerialization.data(withJSONObject: value')));
  });

  test('macOS sends classic Bluetooth clipboard payloads in bounded RFCOMM chunks', () {
    final source = File('macos/Runner/ClassicBluetoothBridge.swift').readAsStringSync();

    expect(source, contains('private let maxWriteChunkSize'));
    expect(source, contains('let totalBytes = bytes.count'));
    expect(source, contains('while offset < totalBytes'));
    expect(source, contains('let chunkLength = min(maxWriteChunkSize, totalBytes - offset)'));
    expect(source, contains('channel.writeSync(baseAddress.advanced(by: offset), length: UInt16(chunkLength))'));
    expect(source, isNot(contains('while offset < bytes.count')));
    expect(source, isNot(contains('bytes.count - offset')));
    expect(source, isNot(contains('guard bytes.count <= Int(UInt16.max)')));
    expect(source, isNot(contains('UInt16(buffer.count)')));
  });

  test('Android sends classic Bluetooth clipboard payloads in bounded RFCOMM chunks', () {
    final source = File('android/app/src/main/kotlin/org/localsend/localsend_app/ClassicBluetoothBridge.kt').readAsStringSync();

    expect(source, contains('private val maxWriteChunkSize = 8192'));
    expect(source, contains(r'val frame = if (payload.endsWith("\n")) payload else "$payload\n"'));
    expect(source, contains('val bytes = frame.toByteArray(Charsets.UTF_8)'));
    expect(source, contains('while (offset < bytes.size)'));
    expect(source, contains('val chunkSize = minOf(maxWriteChunkSize, bytes.size - offset)'));
    expect(source, contains('activeSocket.outputStream.write(bytes, offset, chunkSize)'));
    expect(source, isNot(contains('activeSocket.outputStream.write(payload.toByteArray(Charsets.UTF_8))')));
  });

  test('native connected events include remote device identity', () {
    final android = File('android/app/src/main/kotlin/org/localsend/localsend_app/ClassicBluetoothBridge.kt').readAsStringSync();
    final macos = File('macos/Runner/ClassicBluetoothBridge.swift').readAsStringSync();
    final provider = File('lib/provider/classic_bluetooth_provider.dart').readAsStringSync();

    expect(android, contains('"address" to nextSocket.remoteDevice?.address.orEmpty()'));
    expect(android, contains('"role" to role'));
    expect(macos, contains('"address": address'));
    expect(macos, contains('"role": role'));
    expect(provider, contains("final address = event['address']?.toString()"));
    expect(provider, contains('connectedAddress: address == null || address.isEmpty ? state.connectedAddress : address'));
  });

  test('Android closes any active RFCOMM socket before starting a new outbound connection', () {
    final source = File('android/app/src/main/kotlin/org/localsend/localsend_app/ClassicBluetoothBridge.kt').readAsStringSync();
    final connectIndex = source.indexOf('private fun connect(address: String)');
    final createSocketIndex = source.indexOf('createRfcommSocketToServiceRecord', connectIndex);
    final closeIndex = source.indexOf('closeSocket(emitDisconnected = false)', connectIndex);

    expect(connectIndex, isNonNegative);
    expect(createSocketIndex, isNonNegative);
    expect(closeIndex, isNonNegative);
    expect(closeIndex, lessThan(createSocketIndex));
  });

  test('Android closes a newly created outbound RFCOMM socket when connect fails', () {
    final source = File('android/app/src/main/kotlin/org/localsend/localsend_app/ClassicBluetoothBridge.kt').readAsStringSync();
    final connectIndex = source.indexOf('private fun connect(address: String)');
    final nextSocketVarIndex = source.indexOf('var nextSocket: BluetoothSocket? = null', connectIndex);
    final createSocketIndex = source.indexOf('nextSocket = device.createRfcommSocketToServiceRecord(serviceUuid)', nextSocketVarIndex);
    final attachIndex = source.indexOf('attachSocket(nextSocket, "client", generation)', createSocketIndex);
    final clearIndex = source.indexOf('nextSocket = null', attachIndex);
    final catchIndex = source.indexOf('} catch (e: Exception) {', clearIndex);
    final closeFailedSocketIndex = source.indexOf('closeQuietly(nextSocket)', catchIndex);

    expect(connectIndex, isNonNegative);
    expect(nextSocketVarIndex, isNonNegative);
    expect(createSocketIndex, isNonNegative);
    expect(attachIndex, isNonNegative);
    expect(clearIndex, isNonNegative);
    expect(catchIndex, isNonNegative);
    expect(closeFailedSocketIndex, isNonNegative);
    expect(nextSocketVarIndex, lessThan(createSocketIndex));
    expect(createSocketIndex, lessThan(attachIndex));
    expect(attachIndex, lessThan(clearIndex));
    expect(clearIndex, lessThan(catchIndex));
    expect(catchIndex, lessThan(closeFailedSocketIndex));
    expect(source, contains('private fun closeQuietly(socket: BluetoothSocket?)'));
  });

  test('Android rejects stale RFCOMM socket attach after stop or replacement connect', () {
    final source = File('android/app/src/main/kotlin/org/localsend/localsend_app/ClassicBluetoothBridge.kt').readAsStringSync();
    final importIndex = source.indexOf('import java.util.concurrent.atomic.AtomicInteger');
    final generationFieldIndex = source.indexOf('private val connectionGeneration = AtomicInteger(0)');
    final startServerIndex = source.indexOf('private fun startServer(): Boolean');
    final startGenerationIndex = source.indexOf(
      'val generation = connectionGeneration.incrementAndGet()',
      startServerIndex < 0 ? 0 : startServerIndex,
    );
    final serverAttachIndex = source.indexOf('attachSocket(accepted, "server", generation)', startGenerationIndex < 0 ? 0 : startGenerationIndex);
    final connectIndex = source.indexOf('private fun connect(address: String)');
    final connectGenerationIndex = source.indexOf('val generation = connectionGeneration.incrementAndGet()', connectIndex < 0 ? 0 : connectIndex);
    final clientAttachIndex = source.indexOf(
      'attachSocket(nextSocket, "client", generation)',
      connectGenerationIndex < 0 ? 0 : connectGenerationIndex,
    );
    final catchIndex = source.indexOf('} catch (e: Exception) {', clientAttachIndex < 0 ? 0 : clientAttachIndex);
    final staleErrorGuardIndex = source.indexOf('if (connectionGeneration.get() == generation)', catchIndex < 0 ? 0 : catchIndex);
    final attachSignatureIndex = source.indexOf('private fun attachSocket(nextSocket: BluetoothSocket, role: String, generation: Int)');
    final staleAttachGuardIndex = source.indexOf(
      'if (connectionGeneration.get() != generation)',
      attachSignatureIndex < 0 ? 0 : attachSignatureIndex,
    );
    final staleCloseIndex = source.indexOf('closeQuietly(nextSocket)', staleAttachGuardIndex < 0 ? 0 : staleAttachGuardIndex);
    final stopIndex = source.indexOf('fun stop()');
    final stopGenerationIndex = source.indexOf('connectionGeneration.incrementAndGet()', stopIndex < 0 ? 0 : stopIndex);

    expect(importIndex, isNonNegative);
    expect(generationFieldIndex, isNonNegative);
    expect(startGenerationIndex, isNonNegative);
    expect(serverAttachIndex, isNonNegative);
    expect(connectGenerationIndex, isNonNegative);
    expect(clientAttachIndex, isNonNegative);
    expect(staleErrorGuardIndex, isNonNegative);
    expect(attachSignatureIndex, isNonNegative);
    expect(staleAttachGuardIndex, isNonNegative);
    expect(staleCloseIndex, isNonNegative);
    expect(stopGenerationIndex, isNonNegative);
    expect(startServerIndex, lessThan(startGenerationIndex));
    expect(startGenerationIndex, lessThan(serverAttachIndex));
    expect(connectIndex, lessThan(connectGenerationIndex));
    expect(connectGenerationIndex, lessThan(clientAttachIndex));
    expect(attachSignatureIndex, lessThan(staleAttachGuardIndex));
    expect(staleAttachGuardIndex, lessThan(staleCloseIndex));
    expect(stopIndex, lessThan(stopGenerationIndex));
  });

  test('macOS ignores stale RFCOMM close callbacks after a replacement channel is attached', () {
    final source = File('macos/Runner/ClassicBluetoothBridge.swift').readAsStringSync();

    expect(source, contains('guard channel == rfcommChannel else'));
    expect(source, contains('return'));
  });

  test('macOS replaces the active RFCOMM channel before closing the previous channel', () {
    final source = File('macos/Runner/ClassicBluetoothBridge.swift').readAsStringSync();
    final attachIndex = source.indexOf('private func attach(channel newChannel: IOBluetoothRFCOMMChannel, role: String)');
    final closeIndex = source.indexOf('channel?.close()', attachIndex);
    final assignIndex = source.indexOf('channel = newChannel', attachIndex);

    expect(attachIndex, isNonNegative);
    expect(closeIndex, isNonNegative);
    expect(assignIndex, isNonNegative);
    expect(assignIndex, lessThan(closeIndex));
  });

  test('macOS opens outbound RFCOMM channels off the main Flutter method channel thread', () {
    final source = File('macos/Runner/ClassicBluetoothBridge.swift').readAsStringSync();
    final connectIndex = source.indexOf('private func connect(address: String)');
    final syncOpenIndex = source.indexOf('openRFCOMMChannelSync', connectIndex);
    final asyncIndex = source.indexOf('DispatchQueue.global', connectIndex);

    expect(connectIndex, isNonNegative);
    expect(syncOpenIndex, isNonNegative);
    expect(asyncIndex, isNonNegative);
    expect(asyncIndex, lessThan(syncOpenIndex));
  });

  test('macOS serializes RFCOMM attach, data, and close callbacks onto the main thread', () {
    final source = File('macos/Runner/ClassicBluetoothBridge.swift').readAsStringSync();
    final attachOnMainIndex = source.indexOf(
      'private func attachOnMain(channel newChannel: IOBluetoothRFCOMMChannel, role: String, generation: Int)',
    );
    final connectIndex = source.indexOf('private func connect(address: String)');
    final connectAttachIndex = source.indexOf('self.attachOnMain(channel: rfcommChannel, role: "client", generation: generation)', connectIndex);
    final openedIndex = source.indexOf('@objc private func rfcommChannelOpened');
    final serverAttachIndex = source.indexOf('attachOnMain(channel: newChannel, role: "server", generation: connectionGeneration)', openedIndex);
    final dataCallbackIndex = source.indexOf('func rfcommChannelData');
    final dataDispatchIndex = source.indexOf('DispatchQueue.main.async', dataCallbackIndex);
    final handleDataIndex = source.indexOf('private func handleData(_ data: Data, from rfcommChannel: IOBluetoothRFCOMMChannel)');
    final staleDataGuardIndex = source.indexOf('guard channel == rfcommChannel else', handleDataIndex < 0 ? 0 : handleDataIndex);
    final closeCallbackIndex = source.indexOf('func rfcommChannelClosed');
    final closeDispatchIndex = source.indexOf('DispatchQueue.main.async', closeCallbackIndex);
    final handleCloseIndex = source.indexOf('private func handleChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel, code: String = "DISCONNECTED")');

    expect(attachOnMainIndex, isNonNegative);
    expect(connectAttachIndex, isNonNegative);
    expect(serverAttachIndex, isNonNegative);
    expect(dataDispatchIndex, isNonNegative);
    expect(handleDataIndex, isNonNegative);
    expect(staleDataGuardIndex, isNonNegative);
    expect(closeDispatchIndex, isNonNegative);
    expect(handleCloseIndex, isNonNegative);
    expect(connectIndex, lessThan(connectAttachIndex));
    expect(openedIndex, lessThan(serverAttachIndex));
    expect(dataCallbackIndex, lessThan(dataDispatchIndex));
    expect(dataCallbackIndex, lessThan(handleDataIndex));
    expect(closeCallbackIndex, lessThan(closeDispatchIndex));
    expect(closeCallbackIndex, lessThan(handleCloseIndex));
  });

  test('macOS rejects stale RFCOMM attach callbacks after stop or replacement connect', () {
    final source = File('macos/Runner/ClassicBluetoothBridge.swift').readAsStringSync();
    final generationFieldIndex = source.indexOf('private var connectionGeneration = 0');
    final stopIndex = source.indexOf('private func stop()');
    final stopGenerationIndex = source.indexOf('connectionGeneration += 1', stopIndex < 0 ? 0 : stopIndex);
    final connectIndex = source.indexOf('private func connect(address: String)');
    final connectGenerationIndex = source.indexOf('connectionGeneration += 1', connectIndex < 0 ? 0 : connectIndex);
    final capturedGenerationIndex = source.indexOf('let generation = connectionGeneration', connectGenerationIndex < 0 ? 0 : connectGenerationIndex);
    final connectAttachIndex = source.indexOf(
      'self.attachOnMain(channel: rfcommChannel, role: "client", generation: generation)',
      capturedGenerationIndex < 0 ? 0 : capturedGenerationIndex,
    );
    final serverOpenIndex = source.indexOf('@objc private func rfcommChannelOpened');
    final serverAttachIndex = source.indexOf(
      'attachOnMain(channel: newChannel, role: "server", generation: connectionGeneration)',
      serverOpenIndex < 0 ? 0 : serverOpenIndex,
    );
    final attachOnMainIndex = source.indexOf(
      'private func attachOnMain(channel newChannel: IOBluetoothRFCOMMChannel, role: String, generation: Int)',
    );
    final staleGuardIndex = source.indexOf('guard self.connectionGeneration == generation else', attachOnMainIndex < 0 ? 0 : attachOnMainIndex);
    final staleCloseIndex = source.indexOf('newChannel.close()', staleGuardIndex < 0 ? 0 : staleGuardIndex);

    expect(generationFieldIndex, isNonNegative);
    expect(stopGenerationIndex, isNonNegative);
    expect(connectGenerationIndex, isNonNegative);
    expect(capturedGenerationIndex, isNonNegative);
    expect(connectAttachIndex, isNonNegative);
    expect(serverAttachIndex, isNonNegative);
    expect(attachOnMainIndex, isNonNegative);
    expect(staleGuardIndex, isNonNegative);
    expect(staleCloseIndex, isNonNegative);
    expect(stopIndex, lessThan(stopGenerationIndex));
    expect(connectIndex, lessThan(connectGenerationIndex));
    expect(connectGenerationIndex, lessThan(capturedGenerationIndex));
    expect(capturedGenerationIndex, lessThan(connectAttachIndex));
    expect(attachOnMainIndex, lessThan(staleGuardIndex));
    expect(staleGuardIndex, lessThan(staleCloseIndex));
  });

  test('native Bluetooth server only reports listening after startup succeeds', () {
    final android = File('android/app/src/main/kotlin/org/localsend/localsend_app/ClassicBluetoothBridge.kt').readAsStringSync();
    final macos = File('macos/Runner/ClassicBluetoothBridge.swift').readAsStringSync();

    expect(android, contains('private fun startServer(): Boolean'));
    expect(android, contains('return false'));
    expect(android, contains('result.success(startServer())'));
    expect(android, contains('running = false'));
    expect(macos, contains('private func startServer() -> Bool'));
    expect(macos, contains('guard let serviceRecord else'));
    expect(macos, contains('guard notification != nil else'));
    expect(macos, contains('result(startServer())'));
  });
}
