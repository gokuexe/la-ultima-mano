import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/engine.dart';
import 'package:la_ultima_mano/online/online_connection.dart';
import 'package:la_ultima_mano_server/room_server.dart';

Future<Map<String, dynamic>> next(StreamIterator<dynamic> stream, String type,
    [bool Function(Map<String, dynamic>)? predicate]) async {
  while (await stream.moveNext().timeout(const Duration(seconds: 4))) {
    final data = jsonDecode(stream.current as String) as Map<String, dynamic>;
    if (data['type'] == type && (predicate?.call(data) ?? true)) return data;
  }
  throw StateError('Closed before $type');
}

void send(WebSocket socket, Map<String, dynamic> data) =>
    socket.add(jsonEncode(data));

void main() {
  test('reaction time is frozen during pause and resumes afterwards', () async {
    final game = GameEngine();
    addTearDown(game.dispose);
    final answer =
        game.ask(title: 'Respuesta', options: const [], seconds: .12);
    game.setPaused(true);
    final remaining = game.choice!.remaining;
    await Future<void>.delayed(const Duration(milliseconds: 220));
    expect(game.choice!.remaining, remaining);
    expect(game.choice!.completer.isCompleted, isFalse);
    game.setPaused(false);
    expect(await answer.timeout(const Duration(seconds: 1)), isNull);
  });

  test(
      'server restores seat privately, pauses and expires disconnected players',
      () async {
    final server =
        RoomServer(reconnectGrace: const Duration(milliseconds: 600));
    await server.start(port: 0);
    addTearDown(server.close);
    final address = 'ws://127.0.0.1:${server.port}/ws';
    final host = await WebSocket.connect(address);
    final hs = StreamIterator<dynamic>(host);
    final guest = await WebSocket.connect(address);
    final gs = StreamIterator<dynamic>(guest);
    addTearDown(() async {
      await host.close();
      await guest.close();
    });
    send(host, {'type': 'create', 'name': 'Uno'});
    final session = await next(hs, 'session');
    final lobby = await next(hs, 'lobby');
    send(guest, {'type': 'join', 'name': 'Dos', 'code': lobby['code']});
    final guestSession = await next(gs, 'session');
    expect(guestSession['token'], isNot(session['token']));
    final publicLobby = await next(gs, 'lobby');
    expect(
        jsonEncode(publicLobby), isNot(contains(session['token'] as String)));
    send(host, {'type': 'start'});
    await next(hs, 'state');
    await next(gs, 'state');
    await host.close();
    await next(gs, 'state', (s) => s['paused'] == true);
    final intruder = await WebSocket.connect(address);
    addTearDown(intruder.close);
    final intrusion = StreamIterator<dynamic>(intruder);
    send(intruder, {'type': 'resume', 'code': lobby['code'], 'token': 'fake'});
    await next(intrusion, 'error');
    final restored = await WebSocket.connect(address);
    addTearDown(restored.close);
    final rs = StreamIterator<dynamic>(restored);
    send(restored,
        {'type': 'resume', 'code': lobby['code'], 'token': session['token']});
    await next(rs, 'session');
    final state = await next(rs, 'state');
    expect(state['seat'], 0);
    expect(state['paused'], isFalse);
    expect(state['players'][0]['hand'], isNotNull);
    expect(state['players'][1]['hand'], isNull);
    await restored.close();
    await next(gs, 'closed');
    final expired = await WebSocket.connect(address);
    addTearDown(expired.close);
    final es = StreamIterator<dynamic>(expired);
    send(expired,
        {'type': 'resume', 'code': lobby['code'], 'token': session['token']});
    await next(es, 'error');
  });

  test('client automatically resumes after an unexpected socket close',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final connection = OnlineConnection();
    final restored = Completer<void>();
    var attempts = 0;
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((raw) {
        final message = jsonDecode(raw as String);
        if (message['type'] == 'leave') return;
        attempts++;
        if (attempts == 1) {
          send(socket, {
            'type': 'session',
            'code': 'ABC234',
            'token': 'private-session'
          });
          send(socket,
              {'type': 'lobby', 'code': 'ABC234', 'seat': 0, 'players': []});
          Timer(const Duration(milliseconds: 50), () => socket.close());
        } else {
          expect(message['type'], 'resume');
          expect(message['token'], 'private-session');
          send(socket,
              {'type': 'lobby', 'code': 'ABC234', 'seat': 0, 'players': []});
          restored.complete();
        }
      });
    });
    addTearDown(() async {
      connection.dispose();
      await server.close(force: true);
    });
    await connection.connect(
        'ws://127.0.0.1:${server.port}/ws', {'type': 'create', 'name': 'Uno'});
    await restored.future.timeout(const Duration(seconds: 3));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(connection.connected, isTrue);
    expect(connection.error, isNull);
    expect(attempts, 2);
  });
  test('rematch requires every human vote and preserves the room', () async {
    GameEngine? authoritative;
    final server = RoomServer(createGame: (rules, humans, names) {
      return authoritative =
          GameEngine(rules: rules, humanPlayerIds: humans, playerNames: names);
    });
    await server.start(port: 0);
    final host = OnlineConnection();
    final guest = OnlineConnection();
    addTearDown(() async {
      host.dispose();
      guest.dispose();
      await server.close();
    });
    final endpoint = 'ws://127.0.0.1:${server.port}/ws';
    await host.connect(endpoint, {'type': 'create', 'name': 'Uno'});
    final code = host.lobby!['code'];
    await guest
        .connect(endpoint, {'type': 'join', 'name': 'Dos', 'code': code});
    Future<void> until(bool Function() check) async {
      final limit = DateTime.now().add(const Duration(seconds: 3));
      while (!check()) {
        if (DateTime.now().isAfter(limit)) {
          throw TimeoutException('State did not arrive');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    host.send({'type': 'start'});
    await until(() => host.game != null && guest.game != null);
    host.send({'type': 'rematch'});
    await until(() => host.error != null);
    expect(host.game!.round, 1);
    authoritative!.winner = 'Uno';
    authoritative!.notifyListeners();
    await until(() => guest.game!.winner != null);
    host.game!.requestRematch();
    await until(() => guest.game!.rematchCount == 1);
    host.send({'type': 'rematch'});
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(guest.game!.round, 1);
    guest.game!.requestRematch();
    await until(() => host.game!.round == 2 && guest.game!.round == 2);
    expect(host.game!.winner, isNull);
    expect(host.game!.rematchCount, 0);
    expect(host.lobby!['code'], code);
    expect(host.game!.players[0].name, 'Uno');
    expect(guest.game!.players[0].name, 'Dos');
    expect(host.game!.players[1].hand, everyElement('?'));
  });
}
