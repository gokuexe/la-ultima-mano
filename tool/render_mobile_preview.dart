import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/main.dart';
import 'package:la_ultima_mano/play_preferences.dart';
import 'package:la_ultima_mano/theme.dart';
import 'package:la_ultima_mano/engine.dart';
import 'package:la_ultima_mano/game_config.dart';
import 'package:la_ultima_mano/collection_progress.dart';
import 'package:la_ultima_mano/ui/options_screen.dart';
import 'package:la_ultima_mano/ui/game_screen.dart';
import 'package:la_ultima_mano/ui/pieces.dart';

/// Render previews without an Android emulator. Set MOBILE_PREVIEW_OUTPUT.
void main() {
  testWidgets('render readable phone UI with real bundled fonts',
      (tester) async {
    const output = String.fromEnvironment('MOBILE_PREVIEW_OUTPUT');
    if (!output.startsWith('/')) {
      throw ArgumentError('Set an absolute output directory');
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers.global/events'),
            (_) async => null);
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await (FontLoader(SS.readingFamily)
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Bold.ttf')))
        .load();
    await (FontLoader('Pixelify')
          ..addFont(rootBundle.load('assets/fonts/PixelifySans.ttf')))
        .load();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    PlayPreferences.instance.reduceMotion = true;
    final boundary = GlobalKey();
    Future<void> save(String name) async {
      await tester.pump();
      await tester.runAsync(() async {
        await Directory(output).create(recursive: true);
        final image = await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$output/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(
        RepaintBoundary(key: boundary, child: const LaUltimaManoApp()));
    await tester.pump(const Duration(milliseconds: 500));
    await save('Pulso-menu');
    final game = GameEngine(
        rules: const GameRules.balanced(), humanPlayerIds: const {0, 1, 2, 3});
    game.me.pulse = 3;
    game.me.exchangeAvailable = true;
    game.me.red = 5;
    game.me.blue = 7;
    game.me.hand
      ..clear()
      ..addAll(
          ['sobrecarga', 'intercambio', 'mas1', 'menos1', 'volteo', 'mirar']);
    unawaited(Navigator.of(tester.element(find.byType(TitleScreen))).push(
        MaterialPageRoute<void>(builder: (_) => GameScreen(session: game))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await save('Pulso-tablero');
    final outer = find
        .descendant(
            of: find.byKey(const ValueKey('table-scroll')),
            matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.byType(HandCard).first, 180,
        scrollable: outer);
    await save('Pulso-cartas');
    final nav = Navigator.of(tester.element(find.byType(GameScreen)));
    CollectionProgress.instance.points = 100;
    await CollectionProgress.instance.selectFrame('echo');
    unawaited(nav
        .push(MaterialPageRoute<void>(builder: (_) => const OptionsScreen())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await save('Pulso-coleccion');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
