import 'package:flutter/material.dart';
import '../rooms.dart';
import '../theme.dart';

class RoomBackdrop extends StatelessWidget {
  final String? room;
  const RoomBackdrop({super.key, this.room});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: RoomProgress.instance,
        builder: (context, _) {
          final id = room ?? RoomProgress.instance.effective;
          if (id == 'study') return const SizedBox.expand();
          return Stack(fit: StackFit.expand, children: [
            CustomPaint(painter: RoomScenePainter(id)),
            const DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xAA101015), Color(0xD9101015)]))),
          ]);
        },
      );
}

/// Small fixed pixel grids; all environments are drawn locally without downloads.
class RoomScenePainter extends CustomPainter {
  final String room;
  RoomScenePainter(this.room);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    void box(double x, double y, double w, double h, Color color) {
      paint.color = color;
      canvas.drawRect(
          Rect.fromLTWH(x * size.width / 80, y * size.height / 100,
              w * size.width / 80, h * size.height / 100),
          paint);
    }

    box(0, 0, 80, 100, const Color(0xFF302B32));
    box(0, 67, 80, 33, const Color(0xFF16151B));
    for (var y = 68; y < 100; y += 8) {
      box(0, y.toDouble(), 80, 1, SS.line);
    }
    if (room == 'train') {
      box(0, 0, 80, 8, SS.azul);
      box(38, 8, 4, 60, SS.line);
      for (final x in [5.0, 46.0]) {
        box(x, 15, 29, 28, SS.line);
        box(x + 2, 17, 25, 23, const Color(0xFF0B151B));
        box(x + 3, 19, 23, 1, SS.azulUp);
        box(x + 13, 17, 1, 23, SS.azul);
        box(x, 52, 29, 12, SS.rojo);
        box(x, 64, 29, 9, SS.surfaceUp);
        box(x + 2, 73, 3, 10, SS.line);
        box(x + 24, 73, 3, 10, SS.line);
      }
      box(36, 22, 8, 35, SS.surface);
      box(39, 24, 2, 18, SS.mana);
    } else if (room == 'ward') {
      for (var y = 10; y < 64; y += 10) {
        box(0, y.toDouble(), 80, 1, SS.azul);
      }
      box(25, 7, 30, 4, SS.azulUp);
      box(7, 16, 18, 24, SS.line);
      box(9, 18, 14, 20, const Color(0xFF0F1A1B));
      box(10, 23, 12, 1, SS.win);
      box(15, 20, 1, 9, SS.win);
      box(36, 42, 32, 30, SS.azul);
      box(38, 44, 28, 5, SS.ink);
      box(37, 51, 30, 19, SS.surfaceUp);
      box(33, 70, 38, 4, SS.line);
      box(35, 74, 3, 12, SS.line);
      box(65, 74, 3, 12, SS.line);
      box(70, 15, 2, 48, SS.mute);
      box(67, 17, 8, 2, SS.mute);
      box(68, 20, 5, 9, SS.ink);
    } else {
      box(12, 12, 56, 5, SS.line);
      box(15, 17, 50, 23, SS.surface);
      box(37, 0, 2, 20, SS.line);
      box(29, 20, 18, 5, SS.mana);
      box(30, 25, 16, 2, SS.ink);
      box(10, 58, 60, 5, SS.line);
      box(14, 63, 52, 10, SS.rojo);
      box(15, 73, 4, 18, SS.line);
      box(60, 73, 4, 18, SS.line);
      for (final x in [20.0, 37.0, 54.0]) {
        box(x, 57, 8, 1, SS.ink);
        box(x + 2, 54, 4, 3, SS.mute);
      }
      box(32, 41, 16, 15, SS.surface);
      box(35, 38, 10, 3, SS.line);
    }
  }

  @override
  bool shouldRepaint(covariant RoomScenePainter old) => old.room != room;
}
