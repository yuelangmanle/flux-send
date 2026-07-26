import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:localsend_app/util/user_agent_analyzer.dart';
import 'package:logging/logging.dart';

final _logger = Logger('SimpleServer');

/// A very light layer on top of the HttpServer class.
class SimpleServer {
  final HttpServer _server;

  SimpleServer.start({
    required HttpServer server,
    required SimpleServerRouteBuilder routes,
  }) : _server = server {
    _server.listen((request) async {
      final method = HttpMethod.fromMethodName(request.method);
      if (method == null) {
        request.response.statusCode = HttpStatus.methodNotAllowed;
        request.response.write('Method not allowed');
        await request.response.close();
        return;
      }

      final handler =
          routes._routes[Route(
            method,
            request.uri.path,
          )];

      if (handler != null) {
        try {
          await handler.call(request);
        } catch (e, st) {
          _logger.severe('Unhandled route error: ${request.method} ${request.uri.path}', e, st);
          try {
            await request.respondJson(HttpStatus.internalServerError, message: e.toString());
          } catch (_) {
            await request.response.close();
          }
        }
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not found');
        await request.response.flush();
        await request.response.close();
      }
    });
  }

  Future<void> close() async {
    await _server.close(force: true);
  }
}

typedef HttpRequestHandler = FutureOr<void> Function(HttpRequest request);

enum HttpMethod {
  get('GET'),
  post('POST');

  const HttpMethod(this.methodName);

  final String methodName;

  static HttpMethod? fromMethodName(String methodName) {
    for (final method in values) {
      if (method.methodName == methodName) {
        return method;
      }
    }
    return null;
  }
}

class Route {
  final HttpMethod method;
  final String path;

  Route(this.method, this.path);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Route && other.method == method && other.path == path;
  }

  @override
  int get hashCode => method.hashCode ^ path.hashCode;
}

class SimpleServerRouteBuilder {
  final Map<Route, HttpRequestHandler> _routes = {};

  void addRoute(HttpMethod method, String path, HttpRequestHandler handler) {
    _routes[Route(
          method,
          path,
        )] =
        handler;
  }

  void get(String path, HttpRequestHandler handler) {
    addRoute(HttpMethod.get, path, handler);
  }

  void post(String path, HttpRequestHandler handler) {
    addRoute(HttpMethod.post, path, handler);
  }
}

extension RequestExt on HttpRequest {
  Future<String> readAsString() async {
    return utf8.decodeStream(this);
  }

  /// Syntax sugar for creating an API response.
  ///
  /// Usage:
  /// respondJson(200, message: 'Hello World')
  Future<void> respondJson(int code, {String? message, Map<String, dynamic>? body}) async {
    response
      ..statusCode = code
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(message != null ? {'message': message} : (body ?? {})));

    await response.close();
  }

  /// Syntax sugar for creating an HTML response.
  ///
  /// Usage:
  /// respondAsset(200, 'assets/web/index.html')
  Future<void> respondAsset(int code, String asset, [String type = 'text/html; charset=utf-8']) async {
    response
      ..statusCode = code
      ..headers.contentType = ContentType.parse(type)
      ..write(await rootBundle.loadString(asset));

    await response.close();
  }

  /// The IP address of the client.
  String get ip {
    return connectionInfo!.remoteAddress.address;
  }

  /// Client's device info parsed from the user agent.
  String get deviceInfo {
    final userAgent = headers['user-agent']?.first;
    if (userAgent == null) {
      return 'Unknown';
    }

    final userAgentAnalyzer = UserAgentAnalyzer();
    final browser = userAgentAnalyzer.getBrowser(userAgent);
    final os = userAgentAnalyzer.getOS(userAgent);
    if (browser != null && os != null) {
      return '$browser ($os)';
    } else if (browser != null) {
      return browser;
    } else if (os != null) {
      return os;
    } else {
      return 'Unknown';
    }
  }
}
