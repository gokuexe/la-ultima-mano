import 'dart:convert';
import 'package:game_core/engine.dart';
import 'package:game_core/game_config.dart';
import 'package:game_core/seeded_random.dart';

void main() {
  final e = GameEngine(
      random: ChallengeRandom(20261106 ^ 0x0672026),
      rules: const GameRules.balanced(),
      humanPlayerIds: const {0, 1, 2, 3});
  // CLI probe deliberately prints the same snapshot in VM and JavaScript.
  // ignore: avoid_print
  print(jsonEncode({
    'players': [
      for (final p in e.players) [p.red, p.blue, p.hand]
    ],
    'deck': e.deck
  }));
  e.dispose();
}
