import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/game_config.dart';
import 'package:la_ultima_mano/ui/game_screen.dart';

void main() {
  for (final size in [
    const Size(520, 700),
    const Size(520, 900),
    const Size(1280, 900),
  ]) {
    testWidgets('tablero accesible en ${size.width} x ${size.height}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: GameScreen(rules: GameRules.fast())),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Modo Rápido'), findsOneWidget);

      await tester.ensureVisible(find.text('Ceder la palabra'));
      await tester.pump();
      final button = tester.getRect(find.text('Ceder la palabra'));
      expect(button.bottom, lessThanOrEqualTo(size.height));
      expect(button.top, greaterThanOrEqualTo(0));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
