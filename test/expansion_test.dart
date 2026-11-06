import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/daily_challenge.dart';
import 'package:la_ultima_mano/campaign.dart';
import 'package:la_ultima_mano/rooms.dart';
import 'package:la_ultima_mano/collection_progress.dart';
import 'package:la_ultima_mano/platform/local_store.dart';
import 'package:la_ultima_mano/engine.dart';
import 'package:la_ultima_mano/game_config.dart';
import 'package:la_ultima_mano/theme.dart';
import 'package:la_ultima_mano/ui/daily_screen.dart';
import 'package:la_ultima_mano/ui/daily_share.dart';
import 'package:la_ultima_mano/ui/campaign_screen.dart';
import 'package:la_ultima_mano/ui/rooms_screen.dart';
import 'package:la_ultima_mano/ui/game_screen.dart';
import 'package:la_ultima_mano/play_preferences.dart';

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
  test('daily identity follows the shared UTC day and reproduces initial deals',
      () {
    final a = DailyChallenge.at(DateTime.parse('2026-11-06T23:30:00-03:00'));
    final b = DailyChallenge.at(DateTime.utc(2026, 11, 7));
    expect(a.day, b.day);
    expect(a.seed, b.seed);
    List<Object> snapshot(DailyChallenge c) {
      final e = GameEngine(
          random: ChallengeRandom(c.seed),
          rules: const GameRules.balanced(),
          humanPlayerIds: const {0, 1, 2, 3});
      final value = <Object>[
        for (final p in e.players) [p.red, p.blue, p.hand.toList()],
        e.deck.toList()
      ];
      e.dispose();
      return value;
    }

    expect(snapshot(a), snapshot(b));
    expect(snapshot(a),
        isNot(snapshot(DailyChallenge.at(DateTime.utc(2026, 11, 8)))));
  });
  test(
      'daily best is local, persists, counts abandoned starts and ignores duplicate finishes',
      () async {
    final store = MemoryStore();
    final p = DailyProgress(store: store);
    final attempt = await p.start('2026-11-06');
    await p.finish('2026-11-06', attempt, won: true, turns: 9);
    await p.finish('2026-11-06', attempt, won: true, turns: 1);
    expect(p.forDay('2026-11-06').best, 9);
    await p.start('2026-11-06');
    final next = await p.start('2026-11-06');
    await p.finish('2026-11-06', next, won: false, turns: 3);
    final restored = DailyProgress(store: store);
    await restored.load();
    expect(restored.forDay('2026-11-06').attempts, 3);
    expect(restored.forDay('2026-11-06').best, 9);
    for (var d = 1; d <= 20; d++) {
      await p.start('2026-12-${d.toString().padLeft(2, '0')}');
    }
    expect(p.scores.length, 14);
    expect(store.data!.length, lessThan(4096));
    p.dispose();
    restored.dispose();
  });
  test('campaign unlocks sequentially and preserves the old first chapter',
      () async {
    final store = MemoryStore();
    final p = CampaignProgress(store: store);
    await p.complete('hollow');
    expect(p.completed, isEmpty);
    await p.load(firstChapterComplete: true);
    expect(p.unlocked(1), isTrue);
    await p.complete('witness');
    await p.complete('hollow');
    final restored = CampaignProgress(store: store);
    await restored.load();
    expect(restored.completed, {'widow', 'witness', 'hollow'});
    expect(campaignNights.map((n) => n.mode),
        [GameMode.classic, GameMode.fast, GameMode.bluff]);
    p.dispose();
    restored.dispose();
  });
  test(
      'rooms unlock through memories or nights; locked saved choices fall back safely',
      () async {
    final oldCollection = CollectionProgress.instance,
        oldCampaign = CampaignProgress.instance;
    CollectionProgress.instance = CollectionProgress();
    CampaignProgress.instance = CampaignProgress();
    addTearDown(() {
      CollectionProgress.instance.dispose();
      CampaignProgress.instance.dispose();
      CollectionProgress.instance = oldCollection;
      CampaignProgress.instance = oldCampaign;
    });
    final store = MemoryStore()..data = jsonEncode({'room': 'ward'});
    final p = RoomProgress(store: store);
    await p.load();
    expect(p.selected, 'study');
    await p.select('ward');
    expect(p.selected, 'study');
    CollectionProgress.instance.memories.addAll(['dinner-photo', 'lost-key']);
    await p.select('dining');
    expect(p.selected, 'dining');
    await CampaignProgress.instance.complete('widow');
    await CampaignProgress.instance.complete('witness');
    await p.select('train');
    expect(p.selected, 'train');
    final restored = RoomProgress(store: store);
    await restored.load();
    expect(restored.selected, 'train');
    p.dispose();
    restored.dispose();
  });
  testWidgets('daily hub, campaign and rooms remain readable on small screens',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final screen in [
      DailyScreen(now: () => DateTime.utc(2026, 11, 6)),
      const CampaignScreen(),
      const RoomsScreen()
    ]) {
      await tester.pumpWidget(MaterialApp(
          theme: SS.theme(),
          home: MediaQuery(
              data: const MediaQueryData(
                  size: Size(320, 568),
                  textScaler: TextScaler.linear(1.4),
                  disableAnimations: true),
              child: screen)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(GameScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
  testWidgets(
      'daily match saves its result once and returns to the daily hub without restarting',
      (tester) async {
    final oldDaily = DailyProgress.instance,
        oldCollection = CollectionProgress.instance;
    DailyProgress.instance = DailyProgress(store: MemoryStore());
    CollectionProgress.instance = CollectionProgress();
    addTearDown(() {
      DailyProgress.instance.dispose();
      DailyProgress.instance = oldDaily;
      CollectionProgress.instance.dispose();
      CollectionProgress.instance = oldCollection;
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: SS.theme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: DailyScreen(now: () => DateTime.utc(2026, 11, 6))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-daily')));
    await tester.pumpAndSettle();
    final dynamic state = tester.state(find.byType(GameScreen));
    final GameEngine game = state.engine as GameEngine;
    for (final p in game.players) {
      p.hand.clear();
    }
    game.me.red = 6;
    game.me.blue = 7;
    final result = game.sing(0);
    await tester.pump(const Duration(milliseconds: 600));
    await result;
    await tester.pump();
    expect(DailyProgress.instance.forDay('2026-11-06').best, 1);
    game.notifyListeners();
    await tester.pump();
    expect(CollectionProgress.instance.memories, hasLength(1));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.ensureVisible(find.text('COMPARTIR RETO'));
    await tester.tap(find.text('COMPARTIR RETO'));
    await tester.pumpAndSettle();
    expect(find.byType(DailyShareDialog), findsOneWidget);
    await tester.ensureVisible(find.text('VOLVER AL RESULTADO'));
    await tester.tap(find.text('VOLVER AL RESULTADO'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('VOLVER AL RETO'));
    await tester.tap(find.text('VOLVER AL RETO'));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsNothing);
    expect(DailyProgress.instance.forDay('2026-11-06').attempts, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'winning a story night unlocks the next night and room even when returning home',
      (tester) async {
    final oldCampaign = CampaignProgress.instance,
        oldCollection = CollectionProgress.instance,
        oldPrefs = PlayPreferences.instance;
    CampaignProgress.instance = CampaignProgress(store: MemoryStore());
    CollectionProgress.instance = CollectionProgress();
    PlayPreferences.instance = PlayPreferences()..reduceMotion = true;
    addTearDown(() {
      CampaignProgress.instance.dispose();
      CampaignProgress.instance = oldCampaign;
      CollectionProgress.instance.dispose();
      CollectionProgress.instance = oldCollection;
      PlayPreferences.instance.dispose();
      PlayPreferences.instance = oldPrefs;
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: SS.theme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: const CampaignScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ENTRAR A LA NOCHE'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('SENTARSE A ESTA MESA'));
    await tester.tap(find.text('SENTARSE A ESTA MESA'));
    await tester.pumpAndSettle();
    final dynamic state = tester.state(find.byType(GameScreen));
    final GameEngine game = state.engine as GameEngine;
    expect(game.rules.mode, GameMode.classic);
    for (final p in game.players) {
      p.hand.clear();
    }
    game.me.red = 6;
    game.me.blue = 7;
    final result = game.sing(0);
    await tester.pump(const Duration(milliseconds: 600));
    await result;
    await tester.pump();
    expect(CampaignProgress.instance.completed, contains('widow'));
    expect(RoomProgress.instance.unlocked(roomSkins[1]), isTrue);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.ensureVisible(find.byKey(const ValueKey('result-home')));
    await tester.tap(find.byKey(const ValueKey('result-home')));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsNothing);
    expect(CampaignProgress.instance.unlocked(1), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('share card contains public score only and can copy the result',
      (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(
        theme: SS.theme(),
        home: const Scaffold(
            body: DailyShareDialog(
                day: '2026-11-06', turns: 8, attempt: 2, won: true))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('COPIAR RESULTADO'));
    await tester.tap(find.text('COPIAR RESULTADO'));
    await tester.pump();
    final copied = calls
        .firstWhere((c) => c.method == 'Clipboard.setData')
        .arguments['text'] as String;
    expect(copied, contains('2026-11-06'));
    expect(copied, contains('8'));
    expect(copied, contains('Intento 2'));
    expect(copied, isNot(contains('roja')));
    expect(copied, isNot(contains('azul')));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
