import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/engine.dart';
import 'package:game_core/model.dart';
import 'package:la_ultima_mano/ui/game_screen.dart';
import 'package:la_ultima_mano/ui/pile.dart';

void main() {
  testWidgets('denying an escape does not cross out the previous played card',
      (tester) async {
    tester.view.physicalSize = const Size(520, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = GameEngine(humanPlayerIds: const {0, 1});
    for (final player in game.players) {
      player.hand.clear();
    }
    game.me.red = 6;
    game.me.blue = 7;
    game.me.hand.add('volteo');
    game.players[1].hand.add('desmentir');
    game.players[1].mana = 3;
    await tester.pumpWidget(MaterialApp(home: GameScreen(session: game)));
    final playing = game.playCard(game.me, 'volteo', Targets());
    await tester.pump(const Duration(milliseconds: 150));
    await playing;
    await tester.pump();
    expect(find.byType(MiniCard), findsWidgets);
    final singing = game.sing(0);
    await tester.pump(const Duration(milliseconds: 510));
    expect(game.choice, isNotNull);
    game.answer('desmentir');
    await tester.pump();
    expect(await singing, isFalse);
    expect(
        tester
            .widgetList<MiniCard>(find.byType(MiniCard))
            .every((c) => !c.blocked),
        isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
