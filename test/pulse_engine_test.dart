import 'dart:async';
import 'dart:math';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/engine.dart';
import 'package:game_core/game_config.dart';
import 'package:game_core/model.dart';

GameEngine arranged(
    {GameMode mode = GameMode.classic, Set<int> humans = const {0, 1, 2, 3}}) {
  final e = GameEngine(
      random: Random(17),
      rules: GameRules.balanced(mode),
      humanPlayerIds: humans);
  for (final p in e.players) {
    p.hand.clear();
    p.mana = 3;
    p.red = 0;
    p.blue = 0;
  }
  return e;
}

void main() {
  test(
      'catalog editions keep legacy targets/costs and give Reflejo a useful effect',
      () {
    fakeAsync((clock) {
      final e = arranged();
      e.me.red = 5;
      e.me.blue = 8;
      e.me.hand.add('volteo');
      expect(e.cards['congelar']!.cost, 3);
      expect(kCards['congelar']!.cost, 2);
      expect(kCards['volteo']!.needs, isEmpty);
      e.playCard(e.me, 'volteo', Targets(own: CardColor.red));
      clock.elapse(const Duration(seconds: 1));
      expect(e.me.isWin, isTrue);
      expect(e.me.mana, 1);
      e.dispose();
    });
  });
  test('Insomnio is once per turn and concurrent end requests charge only once',
      () {
    fakeAsync((clock) {
      final e = arranged();
      e.me.hand.addAll(['sobrecarga', 'sobrecarga']);
      e.playCard(e.me, 'sobrecarga', Targets());
      clock.elapse(const Duration(seconds: 1));
      expect(e.me.mana, 5);
      expect(e.canPlayCard(e.me, e.cards['sobrecarga']!), isFalse);
      e.playCard(e.me, 'sobrecarga', Targets());
      clock.elapse(const Duration(seconds: 1));
      expect(e.me.mana, 5);
      expect(e.me.hand, hasLength(1));
      e.endTurn();
      e.endTurn();
      clock.elapse(const Duration(seconds: 1));
      expect(e.turn, 1);
      expect(e.me.pulse, 1);
      e.dispose();
    });
  });
  test(
      'Anchor validates charge, turn, range, delta, pause and freezing atomically',
      () {
    final e = arranged();
    addTearDown(e.dispose);
    e.me.red = 5;
    e.me.blue = 7;
    e.me.pulse = 2;
    expect(e.usePulse(0, CardColor.red, 1), isFalse);
    e.me.pulse = 3;
    expect(e.usePulse(0, CardColor.red, 2), isFalse);
    expect(e.me.pulse, 3);
    e.setPaused(true);
    expect(e.usePulse(0, CardColor.red, 1), isFalse);
    e.setPaused(false);
    e.me.frozen = true;
    expect(e.usePulse(0, CardColor.red, 1), isFalse);
    e.me.frozen = false;
    expect(e.usePulse(1, CardColor.red, 1), isFalse);
    expect(e.usePulse(0, CardColor.red, 1), isTrue);
    expect(e.me.isWin, isTrue);
    expect(e.me.pulse, 0);
    expect(e.me.mana, 3);
    expect(e.usePulse(0, CardColor.red, -1), isFalse);
    e.me.pulse = 3;
    e.me.red = 0;
    expect(e.usePulse(0, CardColor.red, -1), isFalse);
    expect(e.me.pulse, 3);
  });
  test('cancelling Anchor retains the charge', () {
    fakeAsync((clock) {
      final e = arranged();
      e.me.pulse = 3;
      bool? result;
      e.humanPulse().then((v) => result = v);
      clock.flushMicrotasks();
      expect(e.choice, isNotNull);
      e.answer(null);
      clock.flushMicrotasks();
      expect(result, isFalse);
      expect(e.me.pulse, 3);
      expect(e.choice, isNull);
      e.dispose();
    });
  });
  test('exchange is one card at full hand, only before acting', () {
    fakeAsync((clock) {
      final e = arranged();
      e.me.hand.addAll(List.filled(6, 'mas1'));
      e.me.exchangeAvailable = true;
      final deck = e.deck.length;
      expect(e.exchangeCard(0, 999), isFalse);
      expect(e.me.exchangeAvailable, isTrue);
      expect(e.exchangeCard(0, 2), isTrue);
      expect(e.me.hand, hasLength(6));
      expect(e.deck.length, deck - 1);
      expect(e.exchangeCard(0, 0), isFalse);
      e.me.exchangeAvailable = true;
      e.me.hand[0] = 'mas1';
      e.playCard(e.me, 'mas1', Targets(own: CardColor.red));
      clock.elapse(const Duration(seconds: 1));
      expect(e.me.exchangeAvailable, isFalse);
      expect(e.exchangeCard(0, 0), isFalse);
      e.dispose();
    });
  });
  test('edition 2 bots find the +2 then -1 winning combination', () {
    fakeAsync((clock) {
      final e = arranged(humans: const {1, 2, 3});
      e.me.red = 6;
      e.me.blue = 6;
      e.me.hand.addAll(['mas2', 'men1']);
      clock.elapse(const Duration(seconds: 15));
      expect(e.winner, e.me.name);
      e.dispose();
    });
  });
  test('bots remember reveals without sharing them and forget changed values',
      () {
    fakeAsync((clock) {
      final e = arranged(humans: const {0});
      final observer = e.players[1];
      observer.hand.add('ojear');
      e.players[2].hand.add('mas1');
      e.playCard(observer, 'ojear', Targets(foe: 2, foeColor: CardColor.red));
      clock.elapse(const Duration(seconds: 1));
      expect(e.seesCard(2, CardColor.red, viewerId: 1), isTrue);
      expect(e.seesCard(2, CardColor.red, viewerId: 0), isFalse);
      e.playCard(e.players[2], 'mas1', Targets(own: CardColor.red));
      clock.elapse(const Duration(seconds: 1));
      expect(e.seesCard(2, CardColor.red, viewerId: 1), isFalse);
      e.dispose();
    });
  });
  test('bluff cannot retry the escape in the same turn after being denied', () {
    fakeAsync((clock) {
      final e = arranged(mode: GameMode.bluff);
      e.me.red = 6;
      e.me.blue = 7;
      e.players[1].hand.add('desmentir');
      e.addListener(() {
        if (e.choice != null) scheduleMicrotask(() => e.answer('desmentir'));
      });
      bool? won;
      e.sing(0).then((v) => won = v);
      clock.elapse(const Duration(seconds: 2));
      expect(won, isFalse);
      expect(e.canSing(0), isFalse);
      e.dispose();
    });
  });
  test('the starting seat rotates on rematches only in the new edition', () {
    final e = arranged();
    addTearDown(e.dispose);
    expect(e.turn, 0);
    e.newGame();
    expect(e.turn, 1);
    e.newGame();
    expect(e.turn, 2);
    final old = GameEngine(humanPlayerIds: const {0, 1, 2, 3});
    addTearDown(old.dispose);
    old.newGame();
    expect(old.turn, 0);
  });
}
