import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:fake_async/fake_async.dart';
import 'package:game_core/engine.dart';
import 'package:game_core/game_config.dart';
import 'package:game_core/model.dart';

/// Real engine + real bot policy. Virtual clocks remove presentation delays.
/// This is a bot benchmark, not a measurement of human win rates or match duration.
void main(List<String> args) {
  final count = args.isEmpty ? 1000 : int.parse(args.first);
  if (count < 1 || count > 10000) {
    throw ArgumentError('Use 1..10000 games per mode');
  }
  final modes = <Map<String, Object?>>[];
  final scenarios = <(String, GameRules)>[
    ('classic', const GameRules.classic()),
    ('pulse_classic_playtest', const GameRules.balanced()),
    ('pulse_fast_playtest', const GameRules.balanced(GameMode.fast)),
    ('fast', const GameRules.fast()),
    ('bluff', const GameRules.bluff()),
    ('fast_mana3_experiment', const _FastThreeMana()),
    ('fast_mana3_exchange_experiment', const _FastThreeMana()),
    ('classic_exchange_experiment', const GameRules.classic()),
  ];
  for (final scenario in scenarios) {
    final rules = scenario.$2;
    final exchange = scenario.$1.contains('exchange');
    var exchanges = 0;
    var hardLocks = 0;
    final cutoffExamples = <Object>[];
    final wins = List.filled(4, 0);
    final turns = <int>[];
    final plays = <String, int>{};
    var cutoffs = 0,
        genuineAttempts = 0,
        bluffAttempts = 0,
        genuineWins = 0,
        bluffWins = 0;
    var manaSpentOnReactions = 0, reactions = 0;
    for (var seed = 1; seed <= count; seed++) {
      fakeAsync((clock) {
        final e = GameEngine(
            random: Random(seed), rules: rules, humanPlayerIds: const {});
        final swapRng = Random(seed + 1000000);
        var totalTurns = 1;
        var capped = false;
        e.onFx = (fx) {
          if (fx.kind == FxKind.turn) {
            totalTurns++;
            // Experimental only: one random replacement when starting with a full hand.
            // This hook is not shipped as a production game rule.
            if (exchange &&
                e.current.hand.length >= rules.maxHandSize &&
                e.deck.isNotEmpty) {
              e.current.hand.removeAt(swapRng.nextInt(e.current.hand.length));
              e.current.hand.add(e.deck.removeLast());
              exchanges++;
            }
            if (totalTurns >= 400) {
              capped = true;
              e.dispose();
            }
          }
          if (fx.kind == FxKind.play) {
            plays.update(fx.cardId!, (n) => n + 1, ifAbsent: () => 1);
          }
          if (fx.kind == FxKind.sing) {
            if (e.players[fx.playerId!].isWin) {
              genuineAttempts++;
            } else {
              bluffAttempts++;
            }
          }
          if (fx.kind == FxKind.block) {
            reactions++;
            manaSpentOnReactions += e.cards[fx.cardId!]!.cost;
          }
        };
        clock.elapse(const Duration(hours: 4));
        if (e.winner == null || capped) {
          cutoffs++;
          final hardLock = e.players.every((p) =>
              !e.canSing(p.id) &&
              p.free == 0 &&
              p.hand.length >= rules.maxHandSize &&
              p.hand.every((id) =>
                  e.cards[id]!.isReaction ||
                  e.cards[id]!.cost > max(rules.manaPerTurn, p.pending)));
          if (hardLock) hardLocks++;
          if (cutoffExamples.length < 2) {
            cutoffExamples.add({
              'seed': seed,
              'hardLock': hardLock,
              'players': [
                for (final p in e.players)
                  {
                    'seat': p.id,
                    'red': p.red,
                    'blue': p.blue,
                    'hand': p.hand.toList(),
                    'mana': p.mana,
                    'pending': p.pending
                  }
              ],
            });
          }
        } else {
          final winner = e.players.singleWhere((p) => p.name == e.winner);
          wins[winner.id]++;
          if (winner.isWin) {
            genuineWins++;
          } else {
            bluffWins++;
          }
          turns.add(totalTurns);
        }
        e.dispose();
      });
    }
    turns.sort();
    modes.add({
      'mode': scenario.$1,
      'manaPerTurn': rules.manaPerTurn,
      'hardLocksAtCap': hardLocks,
      'experimentalExchanges': exchanges,
      'cutoffExamples': cutoffExamples,
      'games': count,
      'seedRange': [1, count],
      'turnCap': 400,
      'winsBySeat': wins,
      'cutoffs': cutoffs,
      'meanTurnsCompleted':
          turns.isEmpty ? null : turns.reduce((a, b) => a + b) / turns.length,
      'medianTurnsCompleted': turns.isEmpty ? null : turns[turns.length ~/ 2],
      'p90TurnsCompleted':
          turns.isEmpty ? null : turns[((turns.length - 1) * .9).round()],
      'genuineAttempts': genuineAttempts,
      'bluffAttempts': bluffAttempts,
      'genuineWins': genuineWins,
      'bluffWins': bluffWins,
      'cardPlays': plays,
      'reactions': reactions,
      'reactionMana': manaSpentOnReactions,
    });
  }
  var swapsUnchanged = 0, mirrorHelps = 0, mirrorHurts = 0;
  var mirrorMin = 999, mirrorMax = -999;
  for (var red = 0; red <= 13; red++) {
    for (var blue = 0; blue <= 13; blue++) {
      final p = Player(id: 0, name: 'Audit', human: true, red: red, blue: blue);
      final before = p.distance;
      final swapped =
          Player(id: 0, name: 'Audit', human: true, red: blue, blue: red);
      if (swapped.distance == before) swapsUnchanged++;
      for (final color in CardColor.values) {
        final changed =
            Player(id: 0, name: 'Audit', human: true, red: red, blue: blue);
        changed.setValue(color, 13 - changed.value(color));
        final delta = changed.distance - before;
        mirrorMin = min(mirrorMin, delta);
        mirrorMax = max(mirrorMax, delta);
        if (delta < 0) mirrorHelps++;
        if (delta > 0) mirrorHurts++;
      }
    }
  }
  final initial = [
    for (final r in kValues)
      for (final b in kValues)
        Player(id: 0, name: 'A', human: true, red: r, blue: b).distance
  ];
  final output = {
    'method':
        'Baseline uses real GameEngine/bots and deterministic seeds with virtual timers. Named experiments use isolated rule overrides and, where indicated, a full-hand exchange hook. Legacy scenarios retain edition 1; pulse_* scenarios exercise edition 2.',
    'limitations': [
      'Bots are symmetric and use the current heuristic. No estimate of human win rate or wall-clock duration.',
      'Seed parity across modes is not a matched deal: hand size and RNG consumption differ.',
      'Card frequency measures the current bot policy, not intrinsic card strength.',
    ],
    'probes': _probeRules(),
    'deckCards': kDeckList.fold<int>(0, (n, r) => n + (r[1] as int)),
    'initialMeanDistance': initial.reduce((a, b) => a + b) / initial.length,
    'exact': {
      'swapStates': 196,
      'swapDistanceUnchanged': swapsUnchanged,
      'mirrorStates': 392,
      'mirrorHelpsTarget': mirrorHelps,
      'mirrorHurtsTarget': mirrorHurts,
      'mirrorDistanceDeltaMin': mirrorMin,
      'mirrorDistanceDeltaMax': mirrorMax
    },
    'modes': modes,
  };
  final destination = File(args.length > 1 ? args[1] : 'balance-audit.json');
  destination
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
  stdout.writeln(jsonEncode(output));
}

/// An isolated what-if; the live rules and catalog are left unchanged.
class _FastThreeMana extends GameRules {
  const _FastThreeMana() : super.fast();
  @override
  int get manaPerTurn => 3;
}

Map<String, Object?> _probeRules() {
  final result = <String, Object?>{};
  fakeAsync((clock) {
    final e = GameEngine(
        random: Random(1),
        rules: const GameRules.bluff(),
        humanPlayerIds: const {0, 1, 2, 3});
    for (final p in e.players) {
      p.hand.clear();
      p.mana = 0;
    }
    e.me.red = 6;
    e.me.blue = 7;
    e.me.mana = 3;
    e.players[1].hand.add('desmentir');
    e.players[1].mana = 2;
    e.addListener(() {
      if (e.choice != null) scheduleMicrotask(() => e.answer('desmentir'));
    });
    bool? first, second;
    e.sing(0).then((v) => first = v);
    clock.elapse(const Duration(seconds: 3));
    final canRetry = e.canSing(0);
    e.sing(0).then((v) => second = v);
    clock.elapse(const Duration(seconds: 3));
    result['bluffRetry'] = {
      'firstEscapeWon': first,
      'canRetrySameTurn': canRetry,
      'secondEscapeWon': second,
      'winnerReallyHas67': e.me.isWin,
      'actorManaRemaining': e.me.mana
    };
    e.dispose();
  });
  fakeAsync((clock) {
    final e = GameEngine(random: Random(2), humanPlayerIds: const {0, 1, 2, 3});
    for (final p in e.players) {
      p.hand.clear();
      p.mana = 0;
    }
    e.me.red = 0;
    e.me.blue = 0;
    e.me.hand.addAll(['sobrecarga', 'sobrecarga']);
    e.playCard(e.me, 'sobrecarga', Targets());
    clock.elapse(const Duration(seconds: 1));
    e.playCard(e.me, 'sobrecarga', Targets());
    clock.elapse(const Duration(seconds: 1));
    final gain = e.me.mana;
    e.endTurn();
    clock.elapse(const Duration(seconds: 2));
    result['stackedInsomnia'] = {
      'cardsUsed': 2,
      'manaGained': gain,
      'penaltyEvents':
          e.logs.where((log) => log.text.contains('paga Sobrecarga:')).length
    };
    e.dispose();
  });
  fakeAsync((clock) {
    final e = GameEngine(random: Random(3));
    for (final p in e.players) {
      p.hand.clear();
      p.mana = 3;
    }
    final bot = e.players[1];
    bot.hand.add('ojear');
    e.playCard(bot, 'ojear', Targets(foe: 2, foeColor: CardColor.red));
    clock.elapse(const Duration(seconds: 1));
    result['botPeek'] = {
      'manaPaid': 3 - bot.mana,
      'retainsRevealedCard': e.knowledge[1]?.contains('2-0') ?? false
    };
    e.dispose();
  });
  fakeAsync((clock) {
    final botGame =
        GameEngine(random: Random(4), humanPlayerIds: const {1, 2, 3});
    for (final p in botGame.players) {
      p.hand.clear();
      p.mana = 0;
    }
    botGame.me.red = 6;
    botGame.me.blue = 6;
    botGame.me.mana = 3;
    botGame.me.hand.addAll(['mas2', 'men1']);
    var botPlays = 0;
    botGame.onFx = (fx) {
      if (fx.kind == FxKind.play) botPlays++;
    };
    clock.elapse(const Duration(seconds: 5));
    final movedOn = botGame.turn == 1;
    botGame.dispose();
    final legal =
        GameEngine(random: Random(4), humanPlayerIds: const {0, 1, 2, 3});
    for (final p in legal.players) {
      p.hand.clear();
      p.mana = 0;
    }
    legal.me.red = 6;
    legal.me.blue = 6;
    legal.me.mana = 3;
    legal.me.hand.addAll(['mas2', 'men1']);
    legal.playCard(legal.me, 'mas2', Targets(own: CardColor.red));
    clock.elapse(const Duration(seconds: 1));
    legal.playCard(legal.me, 'men1', Targets(own: CardColor.red));
    clock.elapse(const Duration(seconds: 1));
    result['greedyCombo'] = {
      'start': [6, 6],
      'cards': ['mas2', 'men1'],
      'botPlayed': botPlays,
      'botEndedTurn': movedOn,
      'legalSequenceReaches67': legal.me.isWin,
      'manaRemainingAfterCombo': legal.me.mana
    };
    legal.dispose();
  });
  return result;
}
