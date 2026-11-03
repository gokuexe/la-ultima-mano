import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/online/online_connection.dart';

void main() {
  Future<(HttpServer, OnlineConnection, Future<WebSocket>)> setup() async {
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final accepted = Completer<WebSocket>();
    http.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      accepted.complete(socket);
    });
    final connection = OnlineConnection();
    addTearDown(() async {
      connection.dispose();
      await http.close(force: true);
    });
    return (http, connection, accepted.future);
  }

  test('connect waits for the room confirmation, not just a socket', () async {
    final (http, connection, accepted) = await setup();
    var ready = false;
    final pending = connection.connect('ws://127.0.0.1:${http.port}/ws',
        {'type': 'create', 'name': 'Uno'}).then((_) => ready = true);
    final socket = await accepted;
    final request = Completer<void>();
    socket.listen((raw) {
      request.complete();
    });
    await request.future;
    expect(ready, isFalse);
    expect(connection.connectionStatus, contains('confirmación'));
    socket.add(jsonEncode(
        {'type': 'lobby', 'code': 'ABC234', 'seat': 0, 'players': []}));
    await pending;
    expect(ready, isTrue);
    expect(connection.lobby!['code'], 'ABC234');
    expect(connection.connectionStatus, isNull);
    await socket.close();
  });

  test('server rejection fails the attempt with the actual reason', () async {
    final (http, connection, accepted) = await setup();
    final pending = connection.connect('ws://127.0.0.1:${http.port}/ws',
        {'type': 'join', 'name': 'Uno', 'code': 'ABC234'});
    final expectation = expectLater(pending, throwsA(isA<FormatException>()));
    final socket = await accepted;
    socket.listen((_) {
      socket
          .add(jsonEncode({'type': 'error', 'message': 'Sala no disponible.'}));
    });
    await expectation;
    expect(connection.connected, isFalse);
    expect(connection.error, 'Sala no disponible.');
    expect(connection.lobby, isNull);
    await socket.close();
  });

  test('disconnect before confirmation fails promptly', () async {
    final (http, connection, accepted) = await setup();
    final pending = connection.connect(
        'ws://127.0.0.1:${http.port}/ws', {'type': 'create', 'name': 'Uno'});
    final expectation = expectLater(pending, throwsA(isA<SocketException>()));
    final socket = await accepted;
    socket.listen((_) => socket.close());
    await expectation;
    expect(connection.connected, isFalse);
  });
}
