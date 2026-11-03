import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/chapter.dart';
import 'package:la_ultima_mano/story_progress.dart';
import 'package:la_ultima_mano/ui/chapter_screen.dart';
import 'package:la_ultima_mano/ui/game_screen.dart';
import 'package:la_ultima_mano/engine.dart';

void main() {
  test('practice teaches the target and never overspends lucidity', () {
    final lesson = MemoryLesson();
    expect(lesson.ready, isFalse);
    expect(lesson.adjust(redCard: true, delta: 1), isTrue);
    expect(lesson.adjust(redCard: false, delta: -1), isTrue);
    expect(lesson.ready, isTrue);
    expect(lesson.lucidity, 1);
    lesson.adjust(redCard: true, delta: 1);
    expect(lesson.adjust(redCard: true, delta: 1), isFalse);
    expect(lesson.lucidity, 0);
    lesson.reset();
    expect(lesson.red, 5);
    expect(lesson.blue, 8);
    expect(lesson.lucidity, 3);
  });
  test('story progress persists and rejects inconsistent completion', () async {
    final dir = await Directory.systemTemp.createTemp('ultima-story-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/progress.json');
    final progress = StoryProgress(file: file);
    await progress.update(chapterComplete: true);
    expect(progress.chapterComplete, isFalse);
    await progress.update(memory: MemoryPath.door);
    await progress.update(tutorialComplete: true, chapterComplete: true);
    final restored = StoryProgress(file: file);
    await restored.load();
    expect(restored.memory, MemoryPath.door);
    expect(restored.tutorialComplete, isTrue);
    expect(restored.chapterComplete, isTrue);
    await file
        .writeAsString('{"chapterComplete":true,"tutorialComplete":true}');
    await restored.load();
    expect(restored.chapterComplete, isFalse);
    await file.writeAsString('corrupt');
    await restored.load();
    expect(restored.saveError, isNotNull);
    progress.dispose();
    restored.dispose();
  });
  test('each clue leads to a distinct victory ending', () {
    expect(ChapterOne.ending(MemoryPath.name, true),
        isNot(ChapterOne.ending(MemoryPath.door, true)));
    expect(ChapterOne.ending(MemoryPath.name, false),
        isNot(contains('FIN DEL CAPÍTULO')));
  });
  testWidgets('introduction, practice and victory form a complete chapter',
      (tester) async {
    final progress = StoryProgress();
    MemoryPath? played;
    await tester.pumpWidget(MaterialApp(
        home: ChapterScreen(
            progress: progress,
            playMatch: (_, path) async {
              played = path;
              return true;
            })));
    Future<void> press(Finder finder) async {
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      await tester.scrollUntilVisible(finder, 200);
      await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await press(find.text('LEER EL PAPEL CON MI NOMBRE'));
    await press(find.text('INTENTAR SALIR'));
    expect(find.textContaining('La puerta no responde.'), findsOneWidget);
    await press(find.text('DESTELLO +1').first);
    await press(find.text('LAGUNA −1').last);
    await press(find.text('INTENTAR SALIR'));
    expect(progress.tutorialComplete, isTrue);
    await press(find.text('JUGAR LA PRIMERA MESA'));
    expect(played, MemoryPath.name);
    expect(progress.chapterComplete, isTrue);
    expect(find.textContaining('FIN DEL CAPÍTULO 01'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    progress.dispose();
  });
  testWidgets('leaving or losing a match never unlocks completion',
      (tester) async {
    final progress = StoryProgress()
      ..memory = MemoryPath.door
      ..tutorialComplete = true;
    var result = false;
    await tester.pumpWidget(MaterialApp(
        home: ChapterScreen(
            progress: progress,
            playMatch: (_, __) async => result ? null : false)));
    await tester.ensureVisible(find.text('JUGAR LA PRIMERA MESA'));
    await tester.tap(find.text('JUGAR LA PRIMERA MESA'));
    await tester.pumpAndSettle();
    expect(find.text('OTRA SILLA'), findsOneWidget);
    expect(progress.chapterComplete, isFalse);
    result = true;
    await tester.ensureVisible(find.text('VOLVER A INTENTARLO'));
    await tester.tap(find.text('VOLVER A INTENTARLO'));
    await tester.pumpAndSettle();
    expect(progress.chapterComplete, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    progress.dispose();
  });
  testWidgets(
      'chapter table returns its outcome instead of starting a new round',
      (tester) async {
    final engine = GameEngine();
    bool? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                              builder: (_) => GameScreen(
                                  session: engine,
                                  chapterMemory: MemoryPath.name)));
                    },
                    child: const Text('OPEN'))))));
    await tester.tap(find.text('OPEN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    engine.winner = engine.me.name;
    engine.notifyListeners();
    await tester.pump();
    await tester.tap(find.text('LEER DESENLACE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, isTrue);
    expect(find.text('OPEN'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
