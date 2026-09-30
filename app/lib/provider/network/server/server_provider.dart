import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:common/constants.dart';
import 'package:common/isolate.dart';
import 'package:common/model/dto/multicast_dto.dart';
import 'package:common/model/stored_security_context.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/model/state/server/server_state.dart';
import 'package:localsend_app/provider/clipboard_sync_provider.dart';
import 'package:localsend_app/provider/network/server/controller/common.dart';
import 'package:localsend_app/provider/network/server/controller/receive_controller.dart';
import 'package:localsend_app/provider/network/server/controller/send_controller.dart';
import 'package:localsend_app/provider/network/server/server_utils.dart';
import 'package:localsend_app/provider/security_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/alias_generator.dart';
import 'package:localsend_app/util/request_limiter.dart';
import 'package:localsend_app/util/simple_server.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('Server');

/// 剪切板接口请求体上限：剪切板是文本通道，1MB 已远超合理上限。
const maxClipboardBodyBytes = 1024 * 1024;
const _minFallbackPort = 1024;
const _serverPortFallbackCount = 20;

/// This provider runs the server and provides the current server state.
/// It is a singleton provider, so only one server can be running at a time.
/// The server state is null if the server is not running.
/// The server can receive files (since v1) and send files (since v2).
final serverProvider = NotifierProvider<ServerService, ServerState?>(
  (ref) {
    return ServerService();
  },
  onChanged: (previous, next, ref) {
    final settings = ref.read(settingsProvider);
    final syncState = ref.read(parentIsolateProvider).syncState;
    final syncStatePrev = (syncState.alias, syncState.port, syncState.protocol, syncState.serverRunning, syncState.download);
    final syncStateNext = (
      next?.alias ?? settings.alias,
      next?.port ?? settings.port,
      (next?.https ?? settings.https) ? ProtocolType.https : ProtocolType.http,
      next != null,
      next?.webSendState != null,
    );

    if (syncStatePrev == syncStateNext) {
      return;
    }

    ref
        .redux(parentIsolateProvider)
        .dispatch(
          IsolateSyncServerStateAction(
            alias: syncStateNext.$1,
            port: syncStateNext.$2,
            protocol: syncStateNext.$3,
            serverRunning: syncStateNext.$4,
            download: syncStateNext.$5,
          ),
        );

    if (shouldRestartMulticastListener(previousPort: previous?.port, nextPort: next?.port)) {
      ref.redux(parentIsolateProvider).dispatch(IsolateSendMulticastRestartListenerAction());
    }
  },
);

class ServerService extends Notifier<ServerState?> {
  late final _serverUtils = ServerUtils(
    refFunc: () => ref,
    getState: () => state!,
    getStateOrNull: () => state,
    setState: (builder) => state = builder(state),
  );

  late final _receiveController = ReceiveController(_serverUtils);
  late final _sendController = SendController(_serverUtils);

  ServerService();

  @override
  ServerState? init() {
    return null;
  }

  /// Starts the server from user settings.
  Future<ServerState?> startServerFromSettings() async {
    final settings = ref.read(settingsProvider);
    return startServer(
      alias: settings.alias,
      port: settings.port,
      https: settings.https,
    );
  }

  /// Starts the server.
  Future<ServerState?> startServer({
    required String alias,
    required int port,
    required bool https,
  }) async {
    if (state != null) {
      _logger.info('Server already running.');
      return null;
    }

    alias = alias.trim();
    if (alias.isEmpty) {
      alias = generateRandomAlias();
    }

    if (port < 0 || port > 65535) {
      port = defaultPort;
    }

    _logger.info('Starting server...');
    final httpServer = await bindHttpServerWithFallback(
      preferredPort: port,
      https: https,
      secureContext: https ? ref.read(securityProvider) : null,
    );
    final actualPort = httpServer.port;
    final fallbackMessage = describeServerPortFallback(preferredPort: port, actualPort: actualPort);
    if (fallbackMessage != null) {
      _logger.warning(fallbackMessage);
    }
    _logger.info('Server started. (Port: $actualPort, ${https ? 'HTTPS only' : 'HTTP only'})');

    final router = SimpleServerRouteBuilder();
    final fingerprint = ref.read(securityProvider).certificateHash;
    _receiveController.installRoutes(
      router: router,
      alias: alias,
      port: actualPort,
      https: https,
      fingerprint: fingerprint,
      showToken: ref.read(settingsProvider).showToken,
    );
    _sendController.installRoutes(
      router: router,
      alias: alias,
      fingerprint: fingerprint,
    );

    // Flux: Clipboard sync route
    final clipboardRateLimiter = RequestRateLimiter(maxRequests: 30, window: const Duration(minutes: 1));
    router.post('/api/clipboard', (HttpRequest request) async {
      try {
        // 同一 IP 每分钟最多 30 次，防止剪切板接口被刷。
        if (!clipboardRateLimiter.allow(request.ip, DateTime.now())) {
          return await request.respondJson(HttpStatus.tooManyRequests, message: 'Too many requests.');
        }
        // 接收端设置了 PIN 时，剪切板写入也必须提供 PIN（X-Pin 头或 query 参数）。
        final pinOk = await checkPin(
          pin: ref.read(settingsProvider).receivePin,
          request: request,
        );
        if (!pinOk) {
          return;
        }

        final contentLength = int.tryParse(request.headers.value(HttpHeaders.contentLengthHeader) ?? '');
        if (contentLength != null && contentLength > maxClipboardBodyBytes) {
          return await request.respondJson(HttpStatus.requestEntityTooLarge, message: 'Clipboard payload too large.');
        }
        final body = await utf8.decoder.bind(request.cast<List<int>>().transform(limitBytes(maxClipboardBodyBytes))).join();
        final text = extractClipboardTextFromRequestBody(
          body: body,
          contentType: request.headers.contentType?.toString() ?? request.headers.value(HttpHeaders.contentTypeHeader),
        );
        if (text != null && text.isNotEmpty) {
          final updated = await ref.notifier(clipboardSyncProvider).handleIncomingClipboard(text);
          if (!updated) {
            final clipboardError = ref.read(clipboardSyncProvider).lastError;
            return await request.respondJson(HttpStatus.internalServerError, message: clipboardError ?? 'clipboard write failed');
          }
          return await request.respondJson(HttpStatus.ok, body: {'status': 'ok'});
        } else {
          return await request.respondJson(HttpStatus.badRequest, message: 'missing text');
        }
      } on BytesLimitExceededException {
        return await request.respondJson(HttpStatus.requestEntityTooLarge, message: 'Clipboard payload too large.');
      } catch (e) {
        return await request.respondJson(HttpStatus.internalServerError, message: e.toString());
      }
    });

    final server = SimpleServer.start(server: httpServer, routes: router);

    final newServerState = ServerState(
      httpServer: server,
      alias: alias,
      port: actualPort,
      https: https,
      session: null,
      webSendState: null,
      pinAttempts: const {},
    );

    state = newServerState;
    return newServerState;
  }

  Future<void> stopServer() async {
    _logger.info('Stopping server...');
    await state?.httpServer.close();
    state = null;
    _logger.info('Server stopped.');
  }

  Future<ServerState?> restartServerFromSettings() async {
    await stopServer();
    return await startServerFromSettings();
  }

  Future<ServerState?> restartServer({required String alias, required int port, required bool https}) async {
    await stopServer();
    return await startServer(alias: alias, port: port, https: https);
  }

  void acceptFileRequest(Map<String, String> fileNameMap) {
    _receiveController.acceptFileRequest(fileNameMap);
  }

  void declineFileRequest() {
    _receiveController.declineFileRequest();
  }

  /// Updates the destination directory for the current session.
  void setSessionDestinationDir(String destinationDirectory) {
    _receiveController.setSessionDestinationDir(destinationDirectory);
  }

  /// Updates the save to gallery setting for the current session.
  void setSessionSaveToGallery(bool saveToGallery) {
    _receiveController.setSessionSaveToGallery(saveToGallery);
  }

  /// In addition to [closeSession], this method also cancels incoming requests.
  void cancelSession() {
    _receiveController.cancelSession();
  }

  /// Clears the session.
  void closeSession() {
    _receiveController.closeSession();
  }

  /// Initializes the web send state.
  Future<void> initializeWebSend(List<CrossFile> files) async {
    await _sendController.initializeWebSend(files: files);
  }

  /// Updates the web send pin.
  void setWebSendPin(String? pin) {
    state = state?.copyWith(
      webSendState: state?.webSendState?.copyWith(
        pin: pin,
      ),
    );
  }

  /// Updates the auto accept setting for web send.
  void setWebSendAutoAccept(bool autoAccept) {
    state = state?.copyWith(
      webSendState: state?.webSendState?.copyWith(
        autoAccept: autoAccept,
      ),
    );
  }

  /// Accepts the web send request.
  void acceptWebSendRequest(String sessionId) {
    _sendController.acceptRequest(sessionId);
  }

  /// Declines the web send request.
  void declineWebSendRequest(String sessionId) {
    _sendController.declineRequest(sessionId);
  }
}

// Below is a first prototype of mTLS (mutual TLS).
// Problem:
// - we cannot request client certificates while ignoring errors

Future<HttpServer> bindHttpServerWithFallback({
  required int preferredPort,
  required bool https,
  required StoredSecurityContext? secureContext,
}) async {
  Object? lastError;

  for (final port in serverPortCandidates(preferredPort, fallbackCount: _serverPortFallbackCount)) {
    try {
      if (https) {
        if (secureContext == null) {
          throw StateError('HTTPS server requires a security context.');
        }
        return await HttpServer.bindSecure(
          '0.0.0.0',
          port,
          SecurityContext()
            ..usePrivateKeyBytes(secureContext.privateKey.codeUnits)
            ..useCertificateChainBytes(secureContext.certificate.codeUnits),
        );
      }

      return await HttpServer.bind('0.0.0.0', port);
    } catch (e) {
      lastError = e;
      if (!isAddressAlreadyInUse(e)) {
        rethrow;
      }
      _logger.warning('Server port $port is already in use, trying next candidate.');
    }
  }

  throw lastError ?? const SocketException('No available server port.');
}

List<int> serverPortCandidates(int preferredPort, {required int fallbackCount}) {
  final normalizedPort = preferredPort < 0 || preferredPort > 65535 ? defaultPort : preferredPort;
  final candidates = <int>[];

  for (var offset = 0; offset <= fallbackCount; offset++) {
    final candidate = normalizedPort + offset;
    final port = candidate <= 65535 ? candidate : _minFallbackPort + candidate - 65536;
    if (!candidates.contains(port)) {
      candidates.add(port);
    }
  }

  return candidates;
}

bool isAddressAlreadyInUse(Object error) {
  if (error is! SocketException) {
    return false;
  }

  final code = error.osError?.errorCode;
  if (code == 48 || code == 98 || code == 10048) {
    return true;
  }

  final message = error.toString().toLowerCase();
  return message.contains('address already in use') || message.contains('only one usage of each socket address');
}

String? describeServerPortFallback({
  required int preferredPort,
  required int actualPort,
}) {
  if (preferredPort == actualPort) {
    return null;
  }

  return '默认端口 $preferredPort 被占用，Flux 已自动切换到 $actualPort。';
}

bool shouldRestartMulticastListener({
  required int? previousPort,
  required int? nextPort,
}) {
  return previousPort != null && nextPort != null && previousPort != nextPort;
}

// Future<HttpServer> _startServer({
//   required Router router,
//   required int port,
//   required SecurityContext? securityContext,
// }) async {
//   const address = '0.0.0.0';
//   final server = await (securityContext == null
//       ? HttpServer.bind(address, port)
//       : HttpServer.bindSecure(
//     address,
//     port,
//     securityContext,
//     requestClientCertificate: true,
//   ));
//
//   final stream = server.map((request) {
//     print('Request Cert: ${request.certificate?.pem}');
//     return request;
//   });
//
//   serveRequests(stream, router);
//   return server;
// }
