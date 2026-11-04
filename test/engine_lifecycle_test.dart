import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/engine.dart';
import 'package:game_core/model.dart';

GameEngine preparedGame() {
  final game = GameEngine(humanPlayerIds: const {0, 1});
  for (final player in game.players) {
    player.hand.clear();
  }
  game.me.hand.add('mas1');
  game.me.red = 5;
  game.me.blue = 7;
  game.players[1].hand.add('negar');
  game.players[1].mana = 3;
  return game;
}

void main() {
  testWidgets(
      'leaving during a reaction resolves pending work without applying the card',
      (tester) async {
    final game = preparedGame();
    final actor = game.me;
    final effects = <Fx>[];
    game.onFx = effects.add;
    final playing = game.playCard(actor, 'mas1', Targets(own: CardColor.red));
    await tester.pump(const Duration(milliseconds: 150));
    expect(game.choice, isNotNull);
    final before = effects.length;
    game.dispose();
    await tester.pump();
    await playing;
    expect(actor.red, 5);
    expect(effects.length, before);
    expect(game.choice, isNull);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('leaving during an escape does not declare a winner later',
      (tester) async {
    final game = preparedGame();
    game.me.red = 6;
    final singing = game.sing(0);
    game.dispose();
    await tester.pump(const Duration(milliseconds: 600));
    expect(await singing, isFalse);
    expect(game.winner, isNull);
    expect(game.choice, isNull);
  });

  testWidgets('restarting while a card is in flight isolates the new game',
      (tester) async {
    final game = preparedGame();
    addTearDown(game.dispose);
    final playing = game.playCard(game.me, 'mas1', Targets(own: CardColor.red));
    game.newGame();
    final logs = game.logs.map((l) => l.text).toList();
    await tester.pump(const Duration(milliseconds: 200));
    await playing;
    expect(game.logs.map((l) => l.text).toList(), logs);
    expect(game.choice, isNull);
    expect(game.busy, isFalse);
  });

  testWidgets('answering cancels the reaction timeout', (tester) async {
    final game = preparedGame();
    addTearDown(game.dispose);
    final pending = game.ask(
        title: 'Reply',
        options: const [ChoiceOption('Pass', null)],
        seconds: 8);
    game.answer(null);
    expect(await pending, isNull);
    // flutter_test also asserts that there are no pending timers at teardown.
  });
  testWidgets('an immediate response from a listener leaves no timeout behind',
      (tester) async {
    final game = preparedGame();
    addTearDown(game.dispose);
    game.addListener(() {
      if (game.choice != null) game.answer(null);
    });
    final pending = game.ask(
        title: 'Reply',
        options: const [ChoiceOption('Pass', null)],
        seconds: 8);
    expect(await pending, isNull);
  });
}
