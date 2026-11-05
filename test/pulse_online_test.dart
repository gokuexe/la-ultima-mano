import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/engine.dart';
import 'package:game_core/model.dart';
import 'package:la_ultima_mano/online/online_connection.dart';
import 'package:la_ultima_mano_server/room_server.dart';

Future<void> waitFor(bool Function() done) async {
  final until = DateTime.now().add(const Duration(seconds: 5));
  while (!done()) {
    if (DateTime.now().isAfter(until)) {
      throw TimeoutException('No server update');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  test(
      'new rooms reject old clients; skill/exchange are authoritative and private',
      () async {
    late GameEngine authority;
    final server = RoomServer(createGame: (rules, humans, names) {
      authority = GameEngine(
          rules: rules, humanPlayerIds: const {0, 1, 2, 3}, playerNames: names);
      for (final p in authority.players) {
        p.hand.clear();
        p.mana = 3;
        p.red = 0;
        p.blue = 0;
      }
      authority.me.red = 5;
      authority.me.blue = 7;
      authority.me.pulse = 3;
      authority.me.hand.addAll(List.filled(6, 'mas1'));
      authority.me.exchangeAvailable = true;
      return authority;
    });
    await server.start(port: 0);
    final host = OnlineConnection(),
        guest = OnlineConnection(),
        old = OnlineConnection();
    addTearDown(() async {
      host.dispose();
      guest.dispose();
      old.dispose();
      await server.close();
    });
    final url = 'ws://127.0.0.1:${server.port}/ws';
    await host
        .connect(url, {'type': 'create', 'name': 'Host', 'rulesEdition': 2});
    expect(host.lobby!['rulesEdition'], 2);
    await expectLater(
        old.connect(
            url, {'type': 'join', 'name': 'Old', 'code': host.lobby!['code']}),
        throwsA(isA<FormatException>()));
    await guest.connect(url, {
      'type': 'join',
      'name': 'Guest',
      'code': host.lobby!['code'],
      'rulesEdition': 2
    });
    host.send({'type': 'start'});
    await waitFor(() => host.game != null && guest.game != null);
    expect(host.game!.rules.isBalanced, isTrue);
    expect(host.game!.cards['congelar']!.cost, 3);
    expect(guest.game!.seesCard(1, CardColor.red), isFalse);
    guest.send({'type': 'pulse', 'color': 0, 'delta': 1});
    await waitFor(() => guest.error != null);
    expect(authority.me.pulse, 3);
    expect(authority.me.red, 5);
    host.send({'type': 'pulse', 'color': 0, 'delta': 9});
    await waitFor(() => host.error != null);
    expect(authority.me.pulse, 3);
    expect(authority.me.red, 5);
    host.send({'type': 'exchange', 'index': 999});
    await waitFor(() => host.error!.contains('recambio'));
    expect(authority.me.hand, hasLength(6));
    expect(authority.me.exchangeAvailable, isTrue);
    host.send({'type': 'exchange', 'index': 0});
    await waitFor(() => !authority.me.exchangeAvailable);
    expect(authority.me.hand, hasLength(6));
    expect(authority.me.pulse, 3);
    expect(host.game!.usePulse(0, CardColor.red, 1), isTrue);
    await waitFor(() => host.game!.me.red == 6 && !host.game!.busy);
    expect(authority.me.pulse, 0);
    expect(authority.me.isWin, isTrue);
    expect(host.game!.me.pulse, 0);
    expect(
        guest.game!.players[3].pulse, 0); // server seat 0 maps to local seat 3
    expect(guest.game!.seesCard(3, CardColor.red), isFalse);
    host.send({'type': 'pulse', 'color': 0, 'delta': 1});
    await waitFor(() => host.error!.contains('Anclaje'));
    expect(authority.me.red, 6);
    expect(await host.game!.sing(0), isTrue);
    await waitFor(
        () => host.game!.winner != null && guest.game!.winner != null);
    expect(host.game!.winner, 'Host');
    expect(guest.game!.winner, 'Host');
    host.game!.requestRematch();
    await waitFor(() => host.game!.votedRematch);
    guest.game!.requestRematch();
    await waitFor(() => host.game!.round == 2 && guest.game!.round == 2);
    expect(host.game!.winner, isNull);
    expect(authority.turn, 1);
    expect(guest.game!.myTurn, isTrue);
    expect(authority.players.every((p) => p.pulse == 0), isTrue);
  });
  test(
      'cancelled confirmation sends no play; confirmed card applies once online',
      () async {
    late GameEngine authority;
    final server = RoomServer(createGame: (rules, humans, names) {
      authority = GameEngine(
          rules: rules, humanPlayerIds: const {0, 1, 2, 3}, playerNames: names);
      for (final p in authority.players) {
        p.hand.clear();
      }
      authority.me.hand.add('mas1');
      authority.me.red = 5;
      authority.me.blue = 7;
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
    await waitFor(() => host.game != null && guest.game != null);
    final game = host.game!..confirmHumanPlays = true;
    var playing = game.humanPlay(0);
    game.answer(CardColor.red);
    await waitFor(() => game.choice?.title.startsWith('Confirmar:') ?? false);
    expect(authority.me.red, 5);
    expect(authority.me.mana, 3);
    game.answer(null);
    expect(await playing, isFalse);
    expect(authority.me.hand, ['mas1']);
    playing = game.humanPlay(0);
    game.answer(CardColor.red);
    await waitFor(() => game.choice?.title.startsWith('Confirmar:') ?? false);
    game.answer(true);
    expect(await playing, isTrue);
    await waitFor(() => authority.me.red == 6 && !game.busy);
    expect(authority.me.mana, 2);
    expect(authority.me.hand, isEmpty);
  });
  test('legacy rooms keep their catalog and do not expose new actions',
      () async {
    final server = RoomServer();
    await server.start(port: 0);
    final host = OnlineConnection(), guest = OnlineConnection();
    addTearDown(() async {
      host.dispose();
      guest.dispose();
      await server.close();
    });
    final url = 'ws://127.0.0.1:${server.port}/ws';
    await host.connect(url, {'type': 'create', 'name': 'Original'});
    await guest.connect(url, {
      'type': 'join',
      'name': 'New client',
      'code': host.lobby!['code'],
      'rulesEdition': 2
    });
    host.send({'type': 'start'});
    await waitFor(() => host.game != null && guest.game != null);
    expect(guest.game!.rules.edition, 1);
    expect(guest.game!.cards['congelar']!.cost, 2);
    expect(guest.game!.cards['volteo']!.needs, isEmpty);
    expect(guest.game!.canUsePulse(0), isFalse);
    expect(guest.game!.canExchange(0), isFalse);
  });
}
