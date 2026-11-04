import 'dart:async';
import 'dart:io';
import 'package:la_ultima_mano/platform/connection_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/online/server_endpoint.dart';
import 'package:la_ultima_mano/online/server_readiness.dart';

void main() {
  test('normalizes secure endpoints and derives health', () {
    final endpoint = ServerEndpoint.parse(' https://example.com/ ');
    expect(endpoint.websocket.toString(), 'wss://example.com/ws');
    expect(endpoint.health.toString(), 'https://example.com/health');
    expect(endpoint.secure, isTrue);
    expect(ServerEndpoint.parse('ws://127.0.0.1:8080').secure, isFalse);
    for (final value in [
      'example.com',
      'http://example.com',
      'wss://user:password@example.com',
      'wss://example.com?token=x',
      'wss://example.com/#fragment'
    ]) {
      expect(() => ServerEndpoint.parse(value), throwsFormatException);
    }
  });

  test('retries while server wakes then accepts health', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var calls = 0;
    server.listen((request) {
      request.response.statusCode = ++calls < 2 ? 503 : 200;
      request.response.write(calls < 2 ? 'starting' : 'ok');
      request.response.close();
    });
    await waitForServer(Uri.parse('http://127.0.0.1:${server.port}/health'),
        retryDelay: const Duration(milliseconds: 5));
    expect(calls, 2);
  });

  test('rejects wrong health address immediately', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response.statusCode = 404;
      request.response.close();
    });
    await expectLater(
        waitForServer(Uri.parse('http://127.0.0.1:${server.port}/health')),
        throwsFormatException);
  });

  test('bounds waiting and supports cancellation', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response.statusCode = 503;
      request.response.close();
    });
    final uri = Uri.parse('http://127.0.0.1:${server.port}/health');
    await expectLater(
        waitForServer(uri,
            timeout: const Duration(milliseconds: 80),
            retryDelay: const Duration(milliseconds: 5)),
        throwsA(isA<TimeoutException>()));
    await expectLater(waitForServer(uri, cancelled: () => true),
        throwsA(isA<ConnectionFailure>()));
  });
}
