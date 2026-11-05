import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/collection_progress.dart';
import 'package:la_ultima_mano/engine.dart';
import 'package:la_ultima_mano/game_config.dart';
import 'package:la_ultima_mano/model.dart';
import 'package:la_ultima_mano/theme.dart';
import 'package:la_ultima_mano/ui/game_screen.dart';
import 'package:la_ultima_mano/l10n/game_text.dart';

GameEngine prepared({String card = 'mas1'}) {
  final game = GameEngine(
      rules: const GameRules.balanced(), humanPlayerIds: const {0, 1, 2, 3});
  for (final p in game.players) {
    p.hand.clear();
  }
  game.me.hand.add(card);
  game.me.red = 5;
  game.me.blue = 7;
  game.me.pulse = 3;
  game.me.exchangeAvailable = true;
  game.confirmHumanPlays = true;
  return game;
}

Future<void> mount(WidgetTester tester, GameEngine game,
    {String language = 'es'}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: SS.theme(),
    builder: (context, child) => LanguageScope(
        language: language,
        child: MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!)),
    home: Builder(
        builder: (context) => Scaffold(
            body: TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => GameScreen(session: game))),
                child: const Text('menu')))),
  ));
  await tester.tap(find.text('menu'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'cancelling target or final confirmation preserves hand and lucidity',
      (tester) async {
    final game = prepared();
    addTearDown(game.dispose);
    final mana = game.me.mana;
    var playing = game.humanPlay(0);
    expect(game.choice, isNotNull);
    game.cancelChoice();
    await tester.pump();
    expect(await playing, isFalse);
    playing = game.humanPlay(0);
    game.answer(CardColor.red);
    await tester.pump();
    expect(game.choice!.title, startsWith('Confirmar:'));
    game.answer(null);
    await tester.pump();
    expect(await playing, isFalse);
    expect(game.me.hand, ['mas1']);
    expect(game.me.mana, mana);
    expect(game.me.red, 5);
    expect(game.me.pulse, 3);
    expect(game.me.exchangeAvailable, isTrue);
    expect(game.choice, isNull);
  });

  testWidgets(
      'cards without targets also require confirmation; confirm applies once',
      (tester) async {
    final game = prepared(card: 'sobrecarga');
    addTearDown(game.dispose);
    final mana = game.me.mana;
    var playing = game.humanPlay(0);
    await tester.pump();
    expect(game.choice!.title, 'Confirmar: Insomnio');
    game.answer(null);
    await tester.pump();
    expect(await playing, isFalse);
    expect(game.me.mana, mana);
    expect(game.me.insomniaUsed, isFalse);
    playing = game.humanPlay(0);
    await tester.pump();
    game.answer(true);
    await tester.pump(const Duration(milliseconds: 160));
    expect(await playing, isTrue);
    expect(game.me.hand, isEmpty);
    expect(game.me.mana, mana + 2);
    expect(game.me.insomniaUsed, isTrue);
  });

  testWidgets(
      'Back cancels pending card, then confirms leaving and can keep playing',
      (tester) async {
    final game = prepared();
    await mount(tester, game);
    final playing = game.humanPlay(0);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cancel-card-choice')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(await playing, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
    expect(game.me.hand, ['mas1']);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('¿Salir de la partida?'), findsOneWidget);
    expect(game.paused, isTrue);
    await tester.tap(find.byKey(const ValueKey('stay-in-game')));
    await tester.pumpAndSettle();
    expect(game.paused, isFalse);
    expect(find.byType(GameScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Salir de la mesa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-exit-game')));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsNothing);
    expect(find.text('menu'), findsOneWidget);
  });

  testWidgets(
      'exit confirmation pauses the local reaction and its visible countdown',
      (tester) async {
    final game = prepared();
    await mount(tester, game);
    final reply = game.ask(
        title: 'Reaction',
        seconds: 8,
        options: const [ChoiceOption('Pass', null)]);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(game.paused, isTrue);
    await tester.pump(const Duration(seconds: 20));
    expect(game.choice, isNotNull);
    await tester.tap(find.byKey(const ValueKey('stay-in-game')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(game.paused, isFalse);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        greaterThan(.8));
    game.answer(null);
    await reply;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'finished match stays put; home and another match are explicit choices',
      (tester) async {
    final game = prepared();
    await mount(tester, game);
    final players = game.players;
    game.winner = game.me.name;
    game.notifyListeners();
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('result-play-again')))
            .onPressed,
        isNull);
    await tester.pump(const Duration(seconds: 20));
    expect(game.winner, game.me.name);
    expect(identical(game.players, players), isTrue);
    expect(find.text('JUGAR OTRA PARTIDA'), findsOneWidget);
    expect(find.text('VOLVER AL INICIO'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('result-play-again')));
    await tester.pumpAndSettle();
    expect(game.winner, isNull);
    expect(identical(game.players, players), isFalse);
    game.winner = game.me.name;
    game.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('result-home')));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsNothing);
    expect(find.text('menu'), findsOneWidget);
  });

  testWidgets('English confirmation can cancel without spending a card',
      (tester) async {
    final game = prepared();
    await mount(tester, game, language: 'en');
    final playing = game.humanPlay(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Red · 5'));
    await tester.pumpAndSettle();
    expect(find.text('PLAY CARD'), findsOneWidget);
    expect(find.textContaining('Cost: 1 lucidity'), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(await playing, isFalse);
    expect(game.me.hand, ['mas1']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  setUp(() {
    CollectionProgress.instance = CollectionProgress();
  });
}
