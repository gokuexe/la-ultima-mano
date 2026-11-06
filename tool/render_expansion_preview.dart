import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/main.dart';
import 'package:la_ultima_mano/theme.dart';
import 'package:la_ultima_mano/play_preferences.dart';
import 'package:la_ultima_mano/rooms.dart';
import 'package:la_ultima_mano/ui/daily_screen.dart';
import 'package:la_ultima_mano/ui/daily_share.dart';
import 'package:la_ultima_mano/ui/campaign_screen.dart';
import 'package:la_ultima_mano/ui/rooms_screen.dart';
import 'package:la_ultima_mano/ui/room_backdrop.dart';

void main() {
  testWidgets('render expansion with real fonts without an emulator',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers.global/events'),
            (_) async => null);
    const output = String.fromEnvironment('MOBILE_PREVIEW_OUTPUT');
    if (!output.startsWith('/')) {
      throw ArgumentError('Absolute output path required');
    }
    await (FontLoader(SS.readingFamily)
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/LiberationSans-Bold.ttf')))
        .load();
    await (FontLoader('Pixelify')
          ..addFont(rootBundle.load('assets/fonts/PixelifySans.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    PlayPreferences.instance.reduceMotion = true;
    final boundary = GlobalKey();
    Future<void> capture(String name, Widget screen) async {
      await tester.pumpWidget(RepaintBoundary(
          key: boundary,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: SS.theme(),
              builder: (context, child) => MediaQuery(
                  data:
                      MediaQuery.of(context).copyWith(disableAnimations: true),
                  child: child!),
              home: screen)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(() async {
        final image = await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await Directory(output).create(recursive: true);
        await File('$output/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      });
      expect(tester.takeException(), isNull);
    }

    await capture('Expansion-menu', const TitleScreen());
    await capture(
        'Expansion-reto', DailyScreen(now: () => DateTime.utc(2026, 11, 6)));
    await capture('Expansion-campana', const CampaignScreen());
    await capture('Expansion-habitaciones', const RoomsScreen());
    await capture(
        'Expansion-tarjeta',
        const Scaffold(
            body: DailyShareDialog(
                day: '2026-11-06', turns: 8, attempt: 2, won: true)));
    for (final room in roomSkins.skip(1)) {
      await capture(
          'Expansion-${room.id}',
          Scaffold(
              body: CustomPaint(
                  painter: RoomScenePainter(room.id),
                  child: const SizedBox.expand())));
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
