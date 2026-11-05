import 'dart:math';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/engine.dart';

void main() {
  test('seeded bot runs reproduce deals, decisions, reactions and final state',
      () {
    Map<String, Object?> run(int seed) {
      return fakeAsync((clock) {
        final game = GameEngine(random: Random(seed), humanPlayerIds: const {});
        var turns = 1;
        game.onFx = (fx) {
          if (fx.kind == FxKind.turn && ++turns >= 40) game.dispose();
        };
        clock.elapse(const Duration(hours: 1));
        final result = <String, Object?>{
          'winner': game.winner,
          'turns': turns,
          'players': [
            for (final p in game.players)
              [p.red, p.blue, p.mana, p.hand.toList()]
          ],
          'deck': game.deck.toList(),
          'logs': game.logs.map((log) => log.text).toList(),
        };
        game.dispose();
        return result;
      });
    }

    expect(run(18), equals(run(18)));
    expect(run(18), isNot(equals(run(19))));
  });
}
