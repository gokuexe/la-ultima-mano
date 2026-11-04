import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/ui/options_screen.dart';
import 'package:la_ultima_mano/ui/game_screen.dart';
import 'package:la_ultima_mano/main.dart';

void main() {
  testWidgets('guide searches accented names and filters reactions',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: CardGuide())));
    await tester.enterText(find.byType(TextField), 'paralisis');
    await tester.pump();
    expect(find.text('Parálisis'), findsOneWidget);
    expect(find.textContaining('1 de 20'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'no existe');
    await tester.pump();
    expect(find.text('No hay cartas que coincidan con tu búsqueda.'),
        findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.text('Todas las familias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reacciones').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('3 de 20'), findsOneWidget);
    expect(find.text('Negación'), findsOneWidget);
  });
  testWidgets('title and table fit with larger text and reduced motion',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(520, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget app(Widget child) => MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                textScaler: TextScaler.linear(1.2), disableAnimations: true),
            child: child));
    await tester.pumpWidget(app(const TitleScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(app(const GameScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
