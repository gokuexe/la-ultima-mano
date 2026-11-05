import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/tension.dart';
import 'package:la_ultima_mano/theme.dart';
import 'package:la_ultima_mano/local_stage_hint.dart';
import 'package:la_ultima_mano/l10n/catalog.dart';
import 'package:la_ultima_mano/engine.dart';
import 'package:la_ultima_mano/game_config.dart';
import 'package:la_ultima_mano/play_preferences.dart';
import 'package:la_ultima_mano/platform/local_store.dart';
import 'package:la_ultima_mano/ui/game_screen.dart';
import 'package:la_ultima_mano/ui/pieces.dart';
import 'package:la_ultima_mano/ui/tension_atmosphere.dart';

class MemoryStore implements LocalStore {
  String? data;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String value) async {
    data = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(SS.readingFamily)
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Bold.ttf')))
        .load();
  });
  test(
      'disabled device hints never read context; proximity uses only own distance',
      () {
    final director = TensionDirector();
    var reads = 0;
    final cue = director.observe(
        distance: 1,
        enabled: true,
        settled: true,
        finished: false,
        npcVoices: true,
        deviceHints: false,
        readDeviceHint: (_) {
          reads++;
          return 'private';
        });
    expect(reads, 0);
    expect(cue!.speaker, 'La Viuda');
    expect(director.level, 1);
    director.observe(
        distance: 0,
        enabled: true,
        settled: true,
        finished: false,
        npcVoices: true,
        deviceHints: false,
        readDeviceHint: (_) => throw StateError('No permission'));
    expect(director.level, 2);
    director.observe(
        distance: 0,
        enabled: false,
        settled: true,
        finished: false,
        npcVoices: true,
        deviceHints: false,
        readDeviceHint: (_) => throw StateError('No permission'));
    expect(director.holdsDialogue, isFalse);
  });
  test('cues have cooldown and round cap; online people are never impersonated',
      () {
    var now = DateTime(2026);
    final director = TensionDirector(now: () => now);
    int cues = 0;
    for (var i = 0; i < 8; i++) {
      director.observe(
          distance: 2,
          enabled: true,
          settled: true,
          finished: false,
          npcVoices: false,
          deviceHints: false,
          readDeviceHint: (_) => 'unused');
      final cue = director.observe(
          distance: 1,
          enabled: true,
          settled: true,
          finished: false,
          npcVoices: false,
          deviceHints: true,
          readDeviceHint: (_) => 'allowed context');
      if (cue != null) {
        cues++;
        expect(cue.speaker, 'La habitación');
      }
      expect(
          director.observe(
              distance: 1,
              enabled: true,
              settled: true,
              finished: false,
              npcVoices: false,
              deviceHints: true,
              readDeviceHint: (_) => 'unused'),
          isNull);
      now = now.add(const Duration(seconds: 13));
    }
    expect(cues, 3);
    director.reset();
    expect(director.level, 0);
    expect(director.holdsDialogue, isFalse);
  });
  test('disabled, unresolved or finished games do not trigger scares', () {
    final director = TensionDirector();
    for (final state in [
      (false, true, false),
      (true, false, false),
      (true, true, true)
    ]) {
      expect(
          director.observe(
              distance: 0,
              enabled: state.$1,
              settled: state.$2,
              finished: state.$3,
              npcVoices: true,
              deviceHints: true,
              readDeviceHint: (_) => throw StateError('Unexpected read')),
          isNull);
    }
  });
  test(
      'local hints use only a clock, platform or selected language and translate',
      () {
    final clock =
        localStageHint(0, language: 'es', now: DateTime(2026, 1, 1, 3, 7));
    expect(Catalog.en(clock),
        'Your clock says 03:07. It is still the same night here.');
    expect(Catalog.en(localStageHint(1, language: 'es')),
        contains('Your screen says'));
    expect(Catalog.en(localStageHint(2, language: 'en')),
        startsWith('You chose English.'));
  });
  test(
      'device hints default on for new/old profiles and preserve explicit disabling',
      () async {
    final store = MemoryStore();
    final prefs = PlayPreferences(store: store);
    await prefs.load();
    expect(prefs.deviceHints, isTrue);
    store.data = '{"language":"es"}';
    await prefs.load();
    expect(prefs.deviceHints, isTrue);
    await prefs.update(deviceHints: true, tension: false);
    final restored = PlayPreferences(store: store);
    await restored.load();
    expect(restored.deviceHints, isTrue);
    expect(restored.tension, isFalse);
    await restored.update(deviceHints: false);
    expect(restored.deviceHints, isFalse);
    await prefs.load();
    expect(prefs.deviceHints, isFalse);
    prefs.dispose();
    restored.dispose();
  });
  testWidgets(
      'tension preserves touch controls; disabling it clears hostile portraits',
      (tester) async {
    final previous = PlayPreferences.instance;
    PlayPreferences.instance = PlayPreferences(store: MemoryStore())
      ..reduceMotion = true;
    addTearDown(() {
      PlayPreferences.instance.dispose();
      PlayPreferences.instance = previous;
    });
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = GameEngine(
        rules: const GameRules.balanced(), humanPlayerIds: const {0, 1, 2, 3});
    game.me.red = 5;
    game.me.blue = 7;
    for (final p in game.players) {
      p.hand.clear();
    }
    await tester.pumpWidget(MaterialApp(
        theme: SS.theme(),
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 568), disableAnimations: true),
            child: GameScreen(session: game))));
    await tester.pumpAndSettle();
    expect(
        tester
            .widgetList<RivalPanel>(find.byType(RivalPanel))
            .every((p) => p.hostile),
        isTrue);
    expect(
        tester.widget<TensionAtmosphere>(find.byType(TensionAtmosphere)).level,
        1);
    await tester.tap(find.text('Ceder la palabra'));
    await tester.pumpAndSettle();
    expect(game.turn, 1);
    await PlayPreferences.instance.update(tension: false);
    await tester.pumpAndSettle();
    expect(
        tester
            .widgetList<RivalPanel>(find.byType(RivalPanel))
            .every((p) => !p.hostile),
        isTrue);
    expect(
        tester.widget<TensionAtmosphere>(find.byType(TensionAtmosphere)).level,
        0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
