import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/main.dart';
import 'package:la_ultima_mano/theme.dart';
import 'package:la_ultima_mano/play_preferences.dart';
import 'package:la_ultima_mano/engine.dart';
import 'package:la_ultima_mano/game_config.dart';
import 'package:la_ultima_mano/model.dart';
import 'package:la_ultima_mano/l10n/game_text.dart';
import 'package:la_ultima_mano/ui/game_screen.dart';
import 'package:la_ultima_mano/ui/pieces.dart';
import 'package:la_ultima_mano/ui/number_card.dart';
import 'package:la_ultima_mano/ui/overlays.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(SS.readingFamily)
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Bold.ttf')))
        .load();
    await (FontLoader('Pixelify')
          ..addFont(rootBundle.load('assets/fonts/PixelifySans.ttf')))
        .load();
  });
  tearDown(() {
    PlayPreferences.instance.language = 'es';
    PlayPreferences.instance.textScale = 1;
    PlayPreferences.instance.reduceMotion = false;
  });
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(412, 915)
  ]) {
    for (final language in ['es', 'en']) {
      for (final scale in [1.0, 1.4]) {
        testWidgets(
            'real app ${size.width}x${size.height} $language reading $scale keeps actions inside safe viewport',
            (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
          addTearDown(tester.view.reset);
          final prefs = PlayPreferences.instance;
          prefs.language = language;
          // Exercise system text scaling beyond the in-game preference range.
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          prefs.reduceMotion = true;
          await tester.pumpWidget(const LaUltimaManoApp());
          await tester.pump();
          expect(tester.takeException(), isNull);
          final engine = GameEngine(
              rules: const GameRules.balanced(),
              humanPlayerIds: const {0, 1, 2, 3});
          engine.me.red = 5;
          engine.me.blue = 7;
          engine.me.free = 2;
          engine.me.pulse = 3;
          engine.me.hand.addAll(List.filled(6 - engine.me.hand.length, 'mas1'));
          engine.me.exchangeAvailable = true;
          unawaited(Navigator.of(tester.element(find.byType(TitleScreen))).push(
              MaterialPageRoute<void>(
                  builder: (_) => GameScreen(session: engine))));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull);
          final action =
              find.text(language == 'en' ? 'End turn' : 'Ceder la palabra');
          // The fixed controls must be usable before scrolling, unlike the old 1000px table.
          final rect = tester.getRect(action);
          expect(rect.bottom, lessThanOrEqualTo(size.height - 24));
          expect(rect.top, greaterThanOrEqualTo(24));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(action.hitTestable(), findsOneWidget);
          await tester.tap(action);
          await tester.pump();
          expect(engine.turn, 1);
          final outer = find
              .descendant(
                  of: find.byKey(const ValueKey('table-scroll')),
                  matching: find.byType(Scrollable))
              .first;
          await tester.scrollUntilVisible(find.byType(HandCard).first, 200,
              scrollable: outer);
          await tester.pump();
          expect(tester.takeException(), isNull);
          // Number cards use the readable family, not the decorative pixel font.
          final number = tester.widget<Text>(find
              .descendant(
                  of: find.byType(NumberCard).first, matching: find.text('5'))
              .first);
          expect(number.style!.fontFamily, SS.readingFamily);
          expect(number.style!.fontSize, greaterThanOrEqualTo(48));
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
  testWidgets('every card fits with English copy and larger text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.reset);
    for (final card in kBalancedCards.values) {
      await tester.pumpWidget(MaterialApp(
          theme: SS.theme(),
          home: LanguageScope(
              language: 'en',
              child: MediaQuery(
                  data: const MediaQueryData(
                      size: Size(320, 800), textScaler: TextScaler.linear(1.4)),
                  child: Scaffold(
                      body: Center(
                          child: HandCard(
                              card: card, enabled: true, onTap: () {})))))));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: card.id);
      await tester.tap(find.byTooltip('Read memory'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '${card.id} memory side');
      // Use a fresh card state for the next entry.
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
  testWidgets('reaction choices scroll inside a small viewport with large type',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.reset);
    final request = ChoiceRequest(
        title: 'Elegí una reacción',
        desc: 'La partida sigue.',
        options: List.generate(12, (i) => ChoiceOption('Reacción $i', i)),
        playerId: 0,
        completer: Completer<Object?>());
    await tester.pumpWidget(MaterialApp(
        theme: SS.theme(),
        home: MediaQuery(
            data: const MediaQueryData(
                textScaler: TextScaler.linear(1.6), disableAnimations: true),
            child: Scaffold(
                body: Stack(children: [
              ChoiceOverlay(request: request, onPick: (_) {})
            ])))));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Reacción 11'), 250);
    expect(find.text('Reacción 11').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
