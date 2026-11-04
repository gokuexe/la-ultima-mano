import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/dialogue.dart';
import 'package:la_ultima_mano/main.dart';
import 'package:la_ultima_mano/ui/archive_screen.dart';
import 'package:la_ultima_mano/ui/dialogue_box.dart';

void main() {
  const line =
      DialogueLine('La habitación', 'El reflejo mueve la mano antes que vos.');
  testWidgets('dialogue can be revealed immediately without changing height',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Center(
                child: SizedBox(width: 300, child: DialogueBox(line: line))))));
    final height = tester.getSize(find.byType(DialogueBox)).height;
    final animated = find.byType(TweenAnimationBuilder<double>);
    expect(find.descendant(of: animated, matching: find.text(line.text)),
        findsNothing);
    await tester.tap(find.byType(DialogueBox));
    await tester.pump();
    expect(find.descendant(of: animated, matching: find.text(line.text)),
        findsOneWidget);
    expect(tester.getSize(find.byType(DialogueBox)).height, height);
    expect(tester.takeException(), isNull);
  });
  testWidgets('dialogue respects reduced motion and enlarged text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(
          disableAnimations: true, textScaler: TextScaler.linear(2)),
      child: const Scaffold(
          body: Center(
              child: SizedBox(width: 240, child: DialogueBox(line: line)))),
    )));
    expect(
        find.descendant(
            of: find.byType(TweenAnimationBuilder<double>),
            matching: find.text(line.text)),
        findsOneWidget);
    expect(tester.getSize(find.byType(DialogueBox)).height, greaterThan(78));
    expect(tester.takeException(), isNull);
  });
  testWidgets('archive opens from title without starting a match',
      (tester) async {
    await tester.pumpWidget(const LaUltimaManoApp());
    await tester.tap(find.text('ARCHIVO 067  /  NO CONFIAR EN NADIE'));
    await tester.pumpAndSettle();
    expect(find.byType(ArchiveScreen), findsOneWidget);
    expect(find.text('NOTA ENCONTRADA BAJO TU SILLA'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('CERRAR EL ARCHIVO'), 300,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('CERRAR EL ARCHIVO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('SENTARSE A LA MESA'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
