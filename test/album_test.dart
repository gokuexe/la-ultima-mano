import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/collection_progress.dart';
import 'package:la_ultima_mano/habit_dialogue.dart';
import 'package:la_ultima_mano/platform/local_store_native.dart';
import 'package:la_ultima_mano/play_preferences.dart';
import 'package:la_ultima_mano/engine.dart';
import 'package:la_ultima_mano/game_config.dart';
import 'package:la_ultima_mano/l10n/game_text.dart';
import 'package:la_ultima_mano/theme.dart';
import 'package:la_ultima_mano/ui/album_screen.dart';
import 'package:la_ultima_mano/ui/game_screen.dart';
import 'package:la_ultima_mano/ui/pieces.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(SS.readingFamily)
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Bold.ttf')))
        .load();
  });
  test('wins and defeats reveal unique clues, then the complete album persists',
      () async {
    final dir = await Directory.systemTemp.createTemp('ultima-album-');
    addTearDown(() => dir.delete(recursive: true));
    final store = FileStore(File('${dir.path}/collection.json'));
    final p = CollectionProgress(store: store);
    expect((await p.awardMatch(won: false))!.id, 'lost-key');
    expect((await p.awardMatch(won: true))!.id, 'dinner-photo');
    for (var i = 0; i < 4; i++) {
      expect(await p.awardMatch(won: false), isNotNull);
    }
    expect(p.memories, hasLength(6));
    expect(await p.awardMatch(won: true), isNull);
    final restored = CollectionProgress(store: store);
    await restored.load();
    expect(restored.memories, p.memories);
    expect(restored.points, p.points);
    p.dispose();
    restored.dispose();
  });
  test(
      'old collections preserve points/frame and unknown or repeated clues are filtered',
      () async {
    final dir = await Directory.systemTemp.createTemp('ultima-migration-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/c.json');
    await file.writeAsString('{"points":40,"frame":"amber"}');
    final p = CollectionProgress(store: FileStore(file));
    await p.load();
    expect(p.points, 40);
    expect(p.frame, 'amber');
    expect(p.memories, isEmpty);
    await file.writeAsString(
        '{"points":40,"memories":["lost-key","lost-key","unknown",4]}');
    await p.load();
    expect(p.memories, {'lost-key'});
    p.dispose();
  });
  test('save failure keeps the discovered clue for this session and reports it',
      () async {
    final dir = await Directory.systemTemp.createTemp('ultima-album-failure-');
    addTearDown(() => dir.delete(recursive: true));
    final block = File('${dir.path}/block');
    await block.writeAsString('file');
    final p = CollectionProgress(
        store: FileStore(File('${block.path}/collection.json')));
    final clue = await p.awardMatch(won: false);
    expect(clue, isNotNull);
    expect(p.memories, contains(clue!.id));
    expect(p.saveError, isNotNull);
    p.dispose();
  });
  test(
      'habit dialogue recognizes repeated actions, spaces cues and resets between matches',
      () {
    var now = DateTime(2026);
    final habits = HabitDialogue(now: () => now);
    habits.played('mas1');
    habits.played('sobrecarga');
    expect(habits.takeCue(allowed: true, npcVoices: true), isNull);
    habits.played('sobrecarga');
    expect(
        habits.takeCue(allowed: true, npcVoices: true)!.speaker, 'El Testigo');
    habits.cancelled();
    habits.cancelled();
    habits.cancelled();
    expect(habits.takeCue(allowed: true, npcVoices: true), isNull);
    now = now.add(const Duration(seconds: 13));
    expect(habits.takeCue(allowed: true, npcVoices: false)!.speaker,
        'La habitación');
    habits.escapeDenied();
    now = now.add(const Duration(seconds: 13));
    expect(habits.takeCue(allowed: false, npcVoices: true), isNull);
    expect(habits.takeCue(allowed: true, npcVoices: true)!.speaker, 'El Hueco');
    habits.reset();
    expect(habits.holdsDialogue, isFalse);
    expect(habits.takeCue(allowed: true, npcVoices: true), isNull);
  });

  testWidgets(
      'locked memories hide fiction; discovered text fits a small English album',
      (tester) async {
    final old = CollectionProgress.instance;
    final p = CollectionProgress();
    CollectionProgress.instance = p;
    addTearDown(() {
      CollectionProgress.instance = old;
      p.dispose();
    });
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: SS.theme(),
        builder: (context, child) => LanguageScope(
            language: 'en',
            child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.4),
                    disableAnimations: true),
                child: child!)),
        home: const AlbumScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Recovered memories: 0/6'), findsOneWidget);
    expect(find.text('The fifth dinner'), findsNothing);
    await p.awardMatch(won: true);
    await tester.pumpAndSettle();
    expect(find.text('The fifth dinner'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'three cancelled card choices trigger a habit reaction without spending resources',
      (tester) async {
    final oldPrefs = PlayPreferences.instance;
    PlayPreferences.instance = PlayPreferences()..reduceMotion = true;
    addTearDown(() {
      PlayPreferences.instance.dispose();
      PlayPreferences.instance = oldPrefs;
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = GameEngine(
        rules: const GameRules.balanced(), humanPlayerIds: const {0, 1, 2, 3});
    for (final p in game.players) {
      p.hand.clear();
    }
    game.me.hand.add('mas1');
    game.me.red = 3;
    game.me.blue = 7;
    await tester.pumpWidget(MaterialApp(
        theme: SS.theme(),
        builder: (context, child) => LanguageScope(
            language: 'en',
            child: MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!)),
        home: GameScreen(session: game)));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.ensureVisible(find.byType(HandCard));
      await tester.tap(find.byType(HandCard));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('You choose. You hesitate.'), findsWidgets);
    expect(game.me.hand, ['mas1']);
    expect(game.me.mana, 3);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
