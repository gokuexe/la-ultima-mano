import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:la_ultima_mano/theme.dart';

/// Code-native promotional art, rendered at each portal-required size.
class PortalCover extends StatelessWidget {
  final double height;
  const PortalCover({super.key, required this.height});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 512,
      height: height,
      child: Stack(fit: StackFit.expand, children: [
        const CustomPaint(painter: _Room()),
        Padding(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('NO CONFÍES EN TUS RECUERDOS',
                  style: TextStyle(
                      fontFamily: 'Pixelify',
                      fontSize: 13,
                      letterSpacing: 2,
                      color: SS.mana)),
              const Spacer(),
              Row(children: [
                const Expanded(
                    child: Text('LA ÚLTIMA\nMANO',
                        style: TextStyle(
                            fontFamily: 'Pixelify',
                            fontSize: 50,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                            color: SS.ink))),
                Transform.rotate(
                    angle: -math.pi / 22, child: _card('6', SS.rojo)),
                Transform.translate(
                    offset: const Offset(-8, 16),
                    child: Transform.rotate(
                        angle: math.pi / 22, child: _card('7', SS.azul))),
              ]),
              const Spacer(),
              const Text('CARTAS · TERROR PSICOLÓGICO',
                  style: TextStyle(
                      fontFamily: 'Pixelify',
                      fontSize: 16,
                      letterSpacing: 1,
                      color: SS.ink)),
              const SizedBox(height: 8),
              const Text('HISTORIA EN SOLITARIO  /  SALAS CON AMIGOS',
                  style: TextStyle(
                      fontFamily: 'Pixelify',
                      fontSize: 11,
                      letterSpacing: 1,
                      color: SS.mana)),
            ])),
        IgnorePointer(
            child: Container(
                decoration: BoxDecoration(
                    border: Border.all(color: SS.line, width: 4)))),
      ]));
  Widget _card(String number, Color color) => Container(
      width: 78,
      height: 128,
      decoration: BoxDecoration(
          color: SS.surface,
          border: Border.all(color: color, width: 4),
          boxShadow: const [
            BoxShadow(color: Color(0xAA000000), offset: Offset(5, 7))
          ]),
      child: Center(
          child: Text(number,
              style: TextStyle(
                  fontFamily: 'Pixelify',
                  fontSize: 86,
                  height: 1,
                  color: color))));
}

class _Room extends CustomPainter {
  const _Room();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = SS.table);
    final door = Rect.fromLTWH(292, 24, 148, size.height - 52);
    canvas.drawRect(door, Paint()..color = const Color(0xFF27212A));
    canvas.drawRect(door.deflate(8), Paint()..color = const Color(0xFF151319));
    canvas.drawRect(Rect.fromLTWH(door.right - 20, door.center.dy, 6, 6),
        Paint()..color = SS.mana.withValues(alpha: .3));
    final p = Paint()..color = SS.line.withValues(alpha: .10);
    for (double y = 8; y < size.height; y += 12) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
    canvas.drawRect(Rect.fromLTWH(0, size.height - 82, size.width, 82),
        Paint()..color = const Color(0x66101015));
  }

  @override
  bool shouldRepaint(covariant _Room oldDelegate) => false;
}
