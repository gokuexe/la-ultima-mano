import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano_server/room_server.dart';
import 'package:la_ultima_mano/engine.dart';
import 'package:la_ultima_mano/model.dart';

class _Client {
  final WebSocket socket;
  final List<Map<String, dynamic>> inbox = [];
  Completer<void>? _wake;
  _Client(this.socket) {
    socket.listen((raw) {
      inbox.add(jsonDecode(raw as String) as Map<String, dynamic>);
      _wake?.complete();
      _wake = null;
    });
  }
  void send(Map<String, dynamic> message) => socket.add(jsonEncode(message));
  Future<Map<String, dynamic>> next(String type,
      [bool Function(Map<String, dynamic>)? predicate]) async {
    while (true) {
      final i = inbox
          .indexWhere((m) => m['type'] == type && (predicate?.call(m) ?? true));
      if (i >= 0) return inbox.removeAt(i);
      _wake = Completer<void>();
      await _wake!.future.timeout(const Duration(seconds: 5));
    }
  }
}

void main() {
  test('knowledge belongs only to the observer', () {
    final e = GameEngine(humanPlayerIds: const {0, 1});
    addTearDown(e.dispose);
    e.knowledge[1] = {'2-0'};
    expect(e.seesCard(2, CardColor.red, viewerId: 1), isTrue);
    expect(e.seesCard(2, CardColor.red, viewerId: 0), isFalse);
    expect(e.seesCard(2, CardColor.blue, viewerId: 1), isFalse);
    expect(e.seesCard(1, CardColor.blue, viewerId: 1), isTrue);
  });

  test('reveal effect is private even when a nonzero seat plays it', () async {
    final e = GameEngine(humanPlayerIds: const {0, 1});
    addTearDown(e.dispose);
    for (final p in e.players) {
      p.hand.clear();
    }
    e.players[1].hand.add('ojear');
    e.players[1].mana = 3;
    e.players[2].blue = 11;
    await e.playCard(
        e.players[1], 'ojear', Targets(foe: 2, foeColor: CardColor.blue));
    expect(e.seesCard(2, CardColor.blue, viewerId: 1), isTrue);
    expect(e.seesCard(2, CardColor.blue, viewerId: 0), isFalse);
    expect(e.logs.last.text, isNot(contains('11')));
  });

  test('two real sockets: private state, permissions and turn progression',
      () async {
    final server = RoomServer();
    await server.start(port: 0);
    addTearDown(server.close);
    final host =
        _Client(await WebSocket.connect('ws://127.0.0.1:${server.port}/ws'));
    final guest =
        _Client(await WebSocket.connect('ws://127.0.0.1:${server.port}/ws'));
    host.send({'type': 'create', 'name': 'Host', 'mode': 0});
    final lobby = await host.next('lobby');
    expect(lobby['code'], matches(RegExp(r'^[A-Z2-9]{6}$')));
    guest.send({'type': 'join', 'name': 'Guest', 'code': lobby['code']});
    final joined = await guest.next('lobby');
    expect(joined['players'], hasLength(2));
    guest.send({'type': 'start'});
    expect((await guest.next('error'))['message'], contains('anfitrión'));
    host.send({'type': 'start'});
    final hs = await host.next('state');
    final gs = await guest.next('state');
    final hp = hs['players'] as List;
    final gp = gs['players'] as List;
    expect(hp[0]['hand'], isNotEmpty);
    expect(hp[0]['red'], isA<int>());
    expect(hp[1]['hand'], isNull);
    expect(hp[1]['red'], isNull);
    expect(hp[1]['blue'], isNull);
    expect(gp[0]['hand'], isNull);
    expect(gp[0]['red'], isNull);
    expect(gp[1]['hand'], isNotEmpty);
    expect(hs['choice'], isNull);
    guest.send({'type': 'end'});
    expect((await guest.next('error'))['message'], contains('turno'));
    host.send({'type': 'play', 'card': 'forged-card'});
    expect((await host.next('error'))['message'], contains('carta'));
    host.send({'type': 'answer', 'choice': 999, 'value': 'negar'});
    expect((await host.next('error'))['message'], contains('Respuesta'));
    host.send({'type': 'end'});
    final next =
        await guest.next('state', (m) => m['turn'] == 1 && m['busy'] == false);
    expect(next['players'][1]['mana'], 3);
    await host.socket.close();
    expect((await guest.next('closed'))['message'], contains('desconectó'));
  });

  test('invalid code and names do not create a seat', () async {
    final server = RoomServer();
    await server.start(port: 0);
    addTearDown(server.close);
    final client =
        _Client(await WebSocket.connect('ws://127.0.0.1:${server.port}/ws'));
    client.send({'type': 'join', 'name': 'Nobody', 'code': 'XXXXXX'});
    expect((await client.next('error'))['message'], contains('disponible'));
    client.send({'type': 'create', 'name': 'bad\nname'});
    expect((await client.next('error'))['message'], contains('nombre'));
    await client.socket.close();
  });
}
