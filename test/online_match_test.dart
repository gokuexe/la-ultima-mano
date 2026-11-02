import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/engine.dart';
import 'package:game_core/game_config.dart';
import 'package:game_core/model.dart';
import 'package:la_ultima_mano/online/online_connection.dart';
import 'package:la_ultima_mano_server/room_server.dart';

Future<void> waitFor(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('The match did not reach the expected state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _Match {
  final RoomServer server;
  final OnlineConnection host;
  final OnlineConnection guest;
  _Match(this.server, this.host, this.guest);
  Future<void> close() async {
    host.dispose();
    guest.dispose();
    await server.close();
  }
}

Future<_Match> _openMatch({
  GameRules rules = const GameRules.classic(),
  required void Function(GameEngine) arrange,
}) async {
  final server = RoomServer(createGame: (rules, humans, names) {
    final game =
        GameEngine(rules: rules, humanPlayerIds: humans, playerNames: names);
    for (final player in game.players) {
      player.hand.clear();
      player.mana = 3;
      player.red = 0;
      player.blue = 0;
    }
    arrange(game);
    return game;
  });
  await server.start(port: 0);
  final host = OnlineConnection();
  final guest = OnlineConnection();
  final match = _Match(server, host, guest);
  addTearDown(match.close);
  final address = 'ws://127.0.0.1:${server.port}/ws';
  await host.connect(address,
      {'type': 'create', 'name': 'Anfitrión', 'mode': rules.mode.index});
  await waitFor(() => host.lobby != null);
  await guest.connect(address,
      {'type': 'join', 'name': 'Invitado', 'code': host.lobby!['code']});
  await waitFor(() => guest.lobby != null);
  host.send({'type': 'start'});
  await waitFor(() => host.game != null && guest.game != null);
  return match;
}

Future<void> playRed(OnlineConnection connection) async {
  final playing = connection.game!.humanPlay(0);
  await waitFor(() => connection.game!.choice != null);
  connection.game!.answer(CardColor.red);
  expect(await playing, isTrue);
}

void main() {
  test(
      'complete match: play, reach 6/7, escape, consistent winner for both clients',
      () async {
    final match = await _openMatch(arrange: (game) {
      game.me.red = 5;
      game.me.blue = 7;
      game.me.hand.add('mas1');
    });
    final host = match.host.game!;
    final guest = match.guest.game!;
    final hostFx = <FxKind>[];
    final guestFx = <FxKind>[];
    host.onFx = (fx) => hostFx.add(fx.kind);
    guest.onFx = (fx) => guestFx.add(fx.kind);
    expect(host.canSing(0), isFalse);
    await playRed(match.host);
    await waitFor(() => host.me.red == 6 && !host.busy);
    expect(host.me.hand, isEmpty);
    expect(host.me.mana, 2);
    expect(host.canSing(0), isTrue);
    expect(guest.seesCard(3, CardColor.red), isFalse);
    expect(await host.sing(0), isTrue);
    await waitFor(() => host.winner != null && guest.winner != null);
    expect(host.winner, 'Anfitrión');
    expect(guest.winner, host.winner);
    expect(hostFx, contains(FxKind.win));
    expect(guestFx, contains(FxKind.lose));
    expect(host.myTurn, isFalse);
    expect(guest.myTurn, isFalse);
  });

  test('opponent alone receives a reaction and cancels the played card',
      () async {
    final match = await _openMatch(arrange: (game) {
      game.me.red = 5;
      game.me.blue = 7;
      game.me.hand.add('mas1');
      game.players[1].hand.add('negar');
    });
    final host = match.host.game!;
    final guest = match.guest.game!;
    await playRed(match.host);
    await waitFor(() => guest.choice != null);
    expect(host.choice, isNull);
    expect(guest.choice!.options.any((o) => o.value == 'negar'), isTrue);
    guest.answer('negar');
    await waitFor(() => !host.busy && guest.choice == null);
    expect(host.me.red, 5);
    expect(host.me.hand, isEmpty);
    expect(guest.me.hand, isEmpty);
    expect(guest.me.mana, 1);
    expect(host.winner, isNull);
  });

  test('denied bluff adds two and does not leak truth before the response',
      () async {
    final match = await _openMatch(
        rules: const GameRules.bluff(),
        arrange: (game) {
          game.me.red = 6;
          game.me.blue = 5;
          game.players[1].hand.add('desmentir');
        });
    final host = match.host.game!;
    final guest = match.guest.game!;
    expect(await host.sing(0), isTrue);
    await waitFor(() => guest.choice != null);
    expect(host.winner, isNull);
    expect(guest.logs.last.text, 'Anfitrión canta ¡Lo recuerdo!');
    expect(guest.seesCard(3, CardColor.red), isFalse);
    guest.answer('desmentir');
    await waitFor(() => !host.busy && host.me.red == 8);
    expect(host.winner, isNull);
    expect(guest.winner, isNull);
    expect(guest.me.hand, isEmpty);
  });

  test('nonzero seat selects targets and a reaction can be declined', () async {
    final match = await _openMatch(arrange: (game) {
      game.me.hand.add('negar');
      game.players[1].red = 5;
      game.players[1].blue = 7;
      game.players[1].hand.add('mas1');
    });
    final host = match.host.game!;
    final guest = match.guest.game!;
    await host.endTurn();
    await waitFor(() => guest.myTurn);
    await playRed(match.guest);
    await waitFor(() => host.choice != null);
    expect(guest.choice, isNull);
    host.answer(null);
    await waitFor(() => !guest.busy && guest.me.red == 6);
    expect(host.me.hand, ['negar']);
    expect(guest.me.blue, 7);
    expect(host.seesCard(1, CardColor.red), isFalse);
  });
  test(
      'nonzero seat targets the intended rival rather than a local seat number',
      () async {
    final match = await _openMatch(arrange: (game) {
      game.me.red = 9;
      game.me.blue = 11;
      game.players[1].red = 4;
      game.players[1].blue = 3;
      game.players[1].hand.add('sanguijuela');
    });
    final host = match.host.game!;
    final guest = match.guest.game!;
    await host.endTurn();
    await waitFor(() => guest.myTurn);
    final playing = guest.humanPlay(0);
    await waitFor(() => guest.choice != null);
    guest.answer(CardColor.red);
    await waitFor(() => guest.choice?.title.contains('rival') ?? false);
    // Host is server seat 0, but local seat 3 on the guest's table.
    guest.answer(3);
    await waitFor(() => guest.choice?.title.contains('Anfitrión') ?? false);
    guest.answer(CardColor.blue);
    expect(await playing, isTrue);
    await waitFor(() => !guest.busy && guest.me.red == 5);
    await waitFor(() => host.me.blue == 10);
    expect(host.me.red, 9);
    expect(guest.me.blue, 3);
    expect(guest.me.mana, 1);
  });
}
