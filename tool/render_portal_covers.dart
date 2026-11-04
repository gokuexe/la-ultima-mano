import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'portal_cover.dart';

/// Run with flutter test and --dart-define=PORTAL_COVER_OUTPUT=/absolute/path.
void main() {
  testWidgets('render code-native portal covers', (tester) async {
    const output = String.fromEnvironment('PORTAL_COVER_OUTPUT');
    if (output.isEmpty || !output.startsWith('/')) {
      throw ArgumentError(
          'Set PORTAL_COVER_OUTPUT to an absolute output directory');
    }
    final font = FontLoader('Pixelify')
      ..addFont(rootBundle.load('assets/fonts/PixelifySans.ttf'));
    await font.load();
    tester.view.devicePixelRatio = 1;
    for (final height in [384, 512, 340]) {
      tester.view.physicalSize = Size(512, height.toDouble());
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: Directionality(
              textDirection: TextDirection.ltr,
              child: PortalCover(height: height.toDouble()))));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Directory(output).create(recursive: true);
        final image = await (key.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$output/La-Ultima-Mano-512x$height.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
