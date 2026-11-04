import 'package:flutter_test/flutter_test.dart';

import 'package:la_ultima_mano/engine.dart';
import 'package:la_ultima_mano/game_config.dart';

void main() {
  test('modo rápido: maná inicial y tope de mano', () {
    final e = GameEngine(rules: const GameRules.fast());
    expect(e.rules.manaPerTurn, 2);
    expect(e.rules.maxHandSize, 5);
    expect(e.me.hand.length, lessThanOrEqualTo(5));
    expect(e.current.mana, 2);
  });

  test('modo farol: canSing sin 6/7 si estás cerca', () {
    final e = GameEngine(rules: const GameRules.bluff());
    e.players[0].red = 6;
    e.players[0].blue = 5;
    expect(e.players[0].isWin, isFalse);
    expect(e.players[0].distance, 2);
    expect(e.canSing(0), isTrue);
  });

  test('modo clásico: no canto sin 6/7', () {
    final e = GameEngine(rules: const GameRules.classic());
    e.players[0].red = 6;
    e.players[0].blue = 5;
    expect(e.canSing(0), isFalse);
  });

  test('modo rápido usa quemado suave en reglas', () {
    expect(const GameRules.fast().softBurn, isTrue);
    expect(const GameRules.classic().softBurn, isFalse);
  });
}
