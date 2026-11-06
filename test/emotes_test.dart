import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/engine.dart';
import 'package:la_ultima_mano/online/online_connection.dart';
import 'package:la_ultima_mano_server/room_server.dart';

Future<void> until(bool Function() condition) async {
  final end = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('No update');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  test(
      'fixed online reactions preserve turns, resources and pending card choices; server rate limits',
      () async {
    late GameEngine authority;
    final server = RoomServer(createGame: (rules, humans, names) {
      authority = GameEngine(
          rules: rules, humanPlayerIds: const {0, 1, 2, 3}, playerNames: names);
      for (final p in authority.players) {
        p.hand.clear();
      }
      authority.me.hand.add('mas1');
      return authority;
    });
    await server.start(port: 0);
    final host = OnlineConnection(), guest = OnlineConnection();
    addTearDown(() async {
      host.dispose();
      guest.dispose();
      await server.close();
    });
    final url = 'ws://127.0.0.1:${server.port}/ws';
    await host
        .connect(url, {'type': 'create', 'name': 'Host', 'rulesEdition': 2});
    await guest.connect(url, {
      'type': 'join',
      'name': 'Guest',
      'code': host.lobby!['code'],
      'rulesEdition': 2
    });
    host.send({'type': 'start'});
    await until(() => host.game != null && guest.game != null);
    final game = host.game!;
    expect(game.emotesAvailable, isTrue);
    final playing = game.humanPlay(0);
    expect(game.choice, isNotNull);
    final choice = game.choice;
    expect(guest.game!.sendEmote('watch'), isTrue);
    await until(() => game.lastEmote != null);
    expect(game.lastEmote!['actor'], 'Guest');
    expect(game.lastEmote!.keys.toSet(), {'id', 'actor', 'sequence'});
    expect(identical(game.choice, choice), isTrue);
    expect(authority.turn, 0);
    expect(authority.me.hand, ['mas1']);
    expect(authority.me.mana, 3);
    expect(guest.game!.sendEmote('door'), isFalse);
    host.send({'type': 'emote', 'id': 'doubt'});
    await until(() => game.lastEmote!['actor'] == 'Host');
    host.send({'type': 'emote', 'id': 'door'});
    await until(() => host.error?.contains('Esperá') ?? false);
    expect(identical(game.choice, choice), isTrue);
    host.send({'type': 'emote', 'id': 'arbitrary text'});
    await until(() => host.error?.contains('no disponible') ?? false);
    expect(authority.me.hand, ['mas1']);
    game.cancelChoice();
    expect(await playing, isFalse);
  });
}
