import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano_server/room_server.dart';
import 'package:la_ultima_mano/model.dart';
import 'package:la_ultima_mano/online/online_connection.dart';

Future<void> until(bool Function() check) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!check()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('State not received');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  test(
      'real online clients map seats and transfer the turn without local simulation',
      () async {
    final server = RoomServer();
    await server.start(port: 0);
    final host = OnlineConnection();
    final guest = OnlineConnection();
    addTearDown(() async {
      host.dispose();
      guest.dispose();
      await server.close();
    });
    final endpoint = 'ws://127.0.0.1:${server.port}/ws';
    await host.connect(endpoint, {'type': 'create', 'name': 'Uno', 'mode': 0});
    await until(() => host.lobby != null);
    await guest.connect(
        endpoint, {'type': 'join', 'name': 'Dos', 'code': host.lobby!['code']});
    await until(() => guest.lobby != null);
    host.send({'type': 'start'});
    await until(() => host.game != null && guest.game != null);
    expect(host.game!.me.name, 'Uno');
    expect(guest.game!.me.name, 'Dos');
    expect(host.game!.myTurn, isTrue);
    expect(guest.game!.myTurn, isFalse);
    expect(guest.game!.seesCard(3, CardColor.red), isFalse);
    await host.game!.endTurn();
    await until(() => guest.game!.myTurn);
    expect(host.game!.myTurn, isFalse);
    expect(guest.game!.turn, 0);
    expect(guest.game!.me.mana, 3);
    expect(guest.game!.me.hand.every((c) => c != '?'), isTrue);
    expect(host.game!.players[1].hand.every((c) => c == '?'), isTrue);
  });
}
