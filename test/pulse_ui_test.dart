import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/collection_progress.dart';
import 'package:la_ultima_mano/engine.dart';
import 'package:la_ultima_mano/game_config.dart';
import 'package:la_ultima_mano/theme.dart';
import 'package:la_ultima_mano/ui/game_screen.dart';
import 'package:la_ultima_mano/l10n/game_text.dart';

void main() {
  testWidgets('Anchor targets correctly and a result awards points only once',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final collection = CollectionProgress();
    final old = CollectionProgress.instance;
    CollectionProgress.instance = collection;
    addTearDown(() {
      CollectionProgress.instance = old;
      collection.dispose();
    });
    final game = GameEngine(
        rules: const GameRules.balanced(), humanPlayerIds: const {0, 1, 2, 3});
    for (final p in game.players) {
      p.hand.clear();
    }
    game.me.red = 5;
    game.me.blue = 7;
    game.me.pulse = 3;
    await tester.pumpWidget(MaterialApp(
        theme: SS.theme(),
        home: const LanguageScope(language: 'en', child: SizedBox())));
    await tester.pumpWidget(MaterialApp(
        theme: SS.theme(),
        home: LanguageScope(
            language: 'en',
            child: MediaQuery(
                data: const MediaQueryData(
                    size: Size(390, 844), disableAnimations: true),
                child: GameScreen(session: game)))));
    await tester.ensureVisible(find.byKey(const ValueKey('pulse-button')));
    await tester.tap(find.byKey(const ValueKey('pulse-button')));
    await tester.pump();
    await tester.tap(find.text('Red · 5'));
    await tester.pump();
    await tester.tap(find.text('+1'));
    await tester.pump();
    expect(game.me.red, 6);
    expect(game.me.pulse, 0);
    expect(collection.points, 0);
    final singing = game.sing(0);
    await tester.pump(const Duration(milliseconds: 600));
    await singing;
    await tester.pump();
    expect(collection.points, 30);
    game.notifyListeners();
    await tester.pump();
    expect(collection.points, 30);
    expect(find.text('+30 memory points'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
