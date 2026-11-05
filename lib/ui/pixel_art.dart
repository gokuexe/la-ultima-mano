import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';

/// Pixel sprites are painted on a fixed grid with no antialiasing.
class PixelSigil extends StatelessWidget {
  final int seed;
  final Color color;
  final double size;
  const PixelSigil(
      {super.key, this.seed = 0, this.color = SS.mana, this.size = 48});
  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _SigilPainter(seed, color)),
      );
}

class _SigilPainter extends CustomPainter {
  final int seed;
  final Color color;
  _SigilPainter(this.seed, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 16;
    final paint = Paint()..isAntiAlias = false;
    void pixel(int x, int y, Color c) {
      paint.color = c;
      canvas.drawRect(Rect.fromLTWH(x * unit, y * unit, unit, unit), paint);
    }

    for (var y = 2; y < 14; y++) {
      for (var x = 2; x < 8; x++) {
        final border = (x == 2 && y > 4 && y < 11) ||
            (y == 2 && x > 4) ||
            (y == 13 && x > 4);
        final rune =
            ((x * 13 + y * 7 + seed * 11) % 9 < 3) && y > 4 && y < 11 && x > 3;
        if (border || rune) {
          pixel(x, y, color);
          pixel(15 - x, y, color);
        }
      }
    }
    pixel(7, 7, SS.ink);
    pixel(8, 7, SS.ink);
    pixel(7, 8, color);
    pixel(8, 8, color);
  }

  @override
  bool shouldRepaint(covariant _SigilPainter old) =>
      old.seed != seed || old.color != color;
}

class PixelPortrait extends StatefulWidget {
  final int character;
  final bool active;
  const PixelPortrait(
      {super.key, required this.character, this.active = false});
  @override
  State<PixelPortrait> createState() => _PixelPortraitState();
}

class _PixelPortraitState extends State<PixelPortrait>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 150));
  Timer? _timer;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) {
      _blink.stop();
      _blink.value = 0;
      return;
    }
    _timer = Timer.periodic(
        Duration(milliseconds: 4200 + (widget.character % 3) * 650), (_) async {
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      await _blink.forward();
      if (mounted) _blink.reverse();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, widget.active ? -1 : 0, 0),
        width: 36,
        height: 36,
        child: AnimatedBuilder(
            animation: _blink,
            builder: (_, __) => CustomPaint(
                painter: _PortraitPainter(
                    widget.character, widget.active, _blink.value))),
      );
}

class _PortraitPainter extends CustomPainter {
  final int character;
  final bool active;
  final double blink;
  _PortraitPainter(this.character, this.active, this.blink);
  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 12;
    final p = Paint()..isAntiAlias = false;
    void rect(int x, int y, int w, int h, Color c) {
      p.color = c;
      canvas.drawRect(Rect.fromLTWH(x * u, y * u, w * u, h * u), p);
    }

    final robe = [SS.react, SS.azul, SS.rojo][character % 3];
    rect(0, 0, 12, 12, SS.table);
    rect(3, 1, 6, 2, robe);
    rect(2, 3, 8, 7, robe);
    rect(3, 4, 6, 5, const Color(0xFF171419));
    if (blink < .65) {
      rect(4, 5, 1, 1, active ? SS.mana : SS.ink);
      rect(7, 5, 1, 1, active ? SS.mana : SS.ink);
    } else {
      rect(3, 6, 2, 1, SS.mute);
      rect(7, 6, 2, 1, SS.mute);
    }
    rect(5, 8, 2, 1, SS.mute);
    rect(1, 10, 10, 2, robe);
    if (character % 3 == 1) rect(5, 3, 2, 6, SS.mute);
    if (character % 3 == 2) rect(4, 7, 4, 1, SS.rojoUp);
  }

  @override
  bool shouldRepaint(covariant _PortraitPainter old) =>
      old.character != character || old.active != active || old.blink != blink;
}

class PixelDust extends CustomPainter {
  final double phase;
  PixelDust(this.phase);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = false;
    for (var i = 0; i < 24; i++) {
      final x = ((i * 79.0 + 17) % size.width).floorToDouble();
      final y =
          (size.height - ((phase * 70 + i * 41) % size.height)).floorToDouble();
      p.color = SS.mana.withValues(alpha: 0.12 + (i % 4) * 0.06);
      canvas.drawRect(Rect.fromLTWH(x, y, 2, 2), p);
    }
  }

  @override
  bool shouldRepaint(covariant PixelDust old) => old.phase != phase;
}
