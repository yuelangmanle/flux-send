import 'dart:io';

import 'package:localsend_app/util/simple_server.dart';
import 'package:test/test.dart';

void main() {
  test('returns 500 instead of leaking async route exceptions', () async {
    final routes = SimpleServerRouteBuilder()
      ..get('/boom', (_) async {
        throw StateError('route failed');
      });
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final server = SimpleServer.start(server: httpServer, routes: routes);

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('http://127.0.0.1:${httpServer.port}/boom'));
      final response = await request.close();
      await response.drain();
      client.close();

      expect(response.statusCode, HttpStatus.internalServerError);
    } finally {
      await server.close();
    }
  });

  test('returns 405 for unsupported HTTP methods instead of throwing', () async {
    final routes = SimpleServerRouteBuilder();
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final server = SimpleServer.start(server: httpServer, routes: routes);

    try {
      final client = HttpClient();
      final request = await client.openUrl('PATCH', Uri.parse('http://127.0.0.1:${httpServer.port}/anything'));
      final response = await request.close();
      await response.drain();
      client.close();

      expect(response.statusCode, HttpStatus.methodNotAllowed);
    } finally {
      await server.close();
    }
  });
}
