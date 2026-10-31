import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Familias de efecto. Cada carta elige una y el painter se encarga del resto,
/// así agregar una carta nueva no obliga a escribir un efecto nuevo.
enum FxShape {
  rise,
  fall,
  burst,
  ring,
  snow,
  sparkle,
  sweep,
  slash,
  bolt,
  drops,
  swirl,
}

class CardVisual {
  final IconData icon;
  final Color color;
  final FxShape shape;

  /// Lo que "se comenta" al jugarla, en tono de notificación de red social.
  /// Le da personalidad a la carta en la mano y en la mesa sin depender de
  /// un ícono nuevo por cada una.
  final String social;

  /// El titular de la "nota de la comunidad" que corona la carta en la mano.
  final String ribbon;

  /// El posteo de ejemplo que ilustra el efecto, con libertad propia — no
  /// repite el número exacto de la jugada. La parte entre asteriscos se
  /// resalta con el color de la carta; el resto usa el estilo base.
  final String post;

  /// El sello que cierra la ficha, a juego con el ribbon.
  final String stamp;

  const CardVisual(this.icon, this.color, this.shape, this.social, this.ribbon,
      this.post, this.stamp);
}

const _verde = Color(0xFFA6B58A);
const _hielo = Color(0xFF8DB3AE);
const _violeta = SS.react;

/// Qué dibuja cada carta cuando cae sobre la pila.
final Map<String, CardVisual> kVisuals = {
  'mas1': const CardVisual(
      Icons.keyboard_arrow_up_rounded,
      _verde,
      FxShape.rise,
      'Destello',
      'RECUERDO I',
      'Un detalle vuelve. *Uno solo*.',
      '+1'),
  'mas2': const CardVisual(
      Icons.keyboard_double_arrow_up_rounded,
      _verde,
      FxShape.rise,
      'Déjà vu',
      'RECUERDO II',
      'Esto ya pasó. *Dos veces*.',
      '+2'),
  'mas3': const CardVisual(
      Icons.expand_less_rounded,
      _verde,
      FxShape.rise,
      'La fotografía',
      'RECUERDO III',
      'Hay *tres sombras* detrás de vos.',
      '+3'),
  'men1': const CardVisual(Icons.keyboard_arrow_down_rounded, SS.rojo,
      FxShape.fall, 'Laguna', 'AUSENCIA I', 'Olvidaste *un nombre*.', '−1'),
  'men2': const CardVisual(
      Icons.keyboard_double_arrow_down_rounded,
      SS.rojo,
      FxShape.fall,
      'Punto ciego',
      'AUSENCIA II',
      'Dos minutos. *Ningún recuerdo*.',
      '−2'),
  'men3': const CardVisual(Icons.expand_more_rounded, SS.rojo, FxShape.fall,
      'Amnesia', 'AUSENCIA III', 'Esa noche *no existió*.', '−3'),
  'transferencia': const CardVisual(Icons.east_rounded, SS.azul, FxShape.drops,
      'Culpa ajena', 'PROYECCIÓN', 'Ese recuerdo *nunca fue tuyo*.', 'CULPA'),
  'sanguijuela': const CardVisual(
      Icons.water_drop_rounded,
      SS.rojo,
      FxShape.drops,
      'Voz ajena',
      'INTRUSIÓN',
      'Habla con tu voz. *No sos vos*.',
      'ECO'),
  'intercambio': const CardVisual(
      Icons.swap_horiz_rounded,
      SS.azul,
      FxShape.swirl,
      'Otra vida',
      'DISOCIACIÓN',
      'Recordás su infancia. *Él recuerda la tuya*.',
      'CAMBIO'),
  'volteo': const CardVisual(
      Icons.flip_camera_android_rounded,
      SS.azul,
      FxShape.swirl,
      'El reflejo',
      'DISTORSIÓN',
      'El espejo se movió *antes que vos*.',
      'REFLEJO'),
  'espejo': const CardVisual(
      Icons.auto_awesome_rounded,
      _hielo,
      FxShape.sweep,
      'Falso recuerdo',
      'IMITACIÓN',
      'Lo contaron tantas veces que *lo recordás*.',
      'COPIA'),
  'rebote': const CardVisual(
      Icons.u_turn_left_rounded,
      SS.azul,
      FxShape.ring,
      'La otra versión',
      'CONTRADICCIÓN',
      'Eso no fue lo que pasó. *¿O sí?*',
      'INVERSO'),
  'sobrecarga': const CardVisual(
      Icons.bolt_rounded,
      SS.mana,
      FxShape.bolt,
      'Insomnio',
      'DETERIORO',
      'Otra noche despierto. *Algo va a ceder*.',
      'INSOMNIO'),
  'dobleJugada': const CardVisual(
      Icons.casino_rounded,
      SS.mana,
      FxShape.burst,
      'Personalidad doble',
      'FRACTURA',
      'Por un momento, *alguien decide por vos*.',
      'DOS VOCES'),
  'respiro': const CardVisual(
      Icons.spa_rounded,
      _verde,
      FxShape.rise,
      'Cerrar los ojos',
      'REFUGIO',
      'Si no mirás, *quizá desaparezca*.',
      'SILENCIO'),
  'sincronia': const CardVisual(
      Icons.sync_rounded,
      SS.mana,
      FxShape.ring,
      'Obsesión',
      'REPETICIÓN',
      'El mismo pensamiento. *Una y otra vez*.',
      'BUCLE'),
  'ojear': const CardVisual(
      Icons.visibility_rounded,
      _verde,
      FxShape.sparkle,
      'La mirilla',
      'OBSERVACIÓN',
      'Al otro lado *también hay un ojo*.',
      'TE VEO'),
  'negar': const CardVisual(Icons.block_rounded, _violeta, FxShape.slash,
      'Negación', 'DEFENSA', 'Eso *no ocurrió*.', 'NEGADO'),
  'congelar': const CardVisual(
      Icons.ac_unit_rounded,
      _hielo,
      FxShape.snow,
      'Parálisis',
      'PESADILLA',
      'Estás despierto. *No podés moverte*.',
      'INMÓVIL'),
  'desmentir': const CardVisual(Icons.gavel_rounded, _violeta, FxShape.burst,
      'No te creo', 'SOSPECHA', 'Tu historia tiene *un agujero*.', 'MENTIRA'),
};

CardVisual visualFor(String cardId) =>
    kVisuals[cardId] ??
    const CardVisual(Icons.style_rounded, SS.mute, FxShape.burst, 'Recuerdo',
        'ARCHIVO PERDIDO', 'Algo *no encaja*.', 'NUEVO');

/// Parte un `post` (con la parte a resaltar entre asteriscos) en los
/// TextSpan que necesita un Text.rich.
List<InlineSpan> parsePost(String raw, TextStyle base, Color accent) {
  final parts = raw.split('*');
  return [
    for (var i = 0; i < parts.length; i++)
      TextSpan(
        text: parts[i],
        style: i.isOdd ? base.copyWith(color: accent) : base,
      ),
  ];
}

/// Dibuja el efecto de una carta. Recibe el avance de 0 a 1 y calcula dónde va
/// cada partícula en ese instante; no guarda estado, así se puede repintar
/// cuantas veces haga falta sin que se desincronice.
class CardFxPainter extends CustomPainter {
  final double t;
  final CardVisual v;
  final int seed;

  CardFxPainter({required this.t, required this.v, this.seed = 3});

  double _fade(double local) => (1 - local).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final rnd = math.Random(seed);
    final center = Offset(size.width / 2, size.height / 2);
    final p = Paint();

    switch (v.shape) {
      case FxShape.rise:
      case FxShape.fall:
        final dir = v.shape == FxShape.rise ? -1.0 : 1.0;
        for (var i = 0; i < 20; i++) {
          final delay = rnd.nextDouble() * 0.4;
          final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
          if (local <= 0) continue;
          final x = center.dx + (rnd.nextDouble() - 0.5) * size.width * 0.8;
          final y = center.dy +
              dir * local * size.height * 0.55 -
              dir * size.height * 0.1;
          p.color = v.color.withValues(alpha: _fade(local) * 0.85);
          canvas.drawCircle(Offset(x + math.sin(local * 5 + i) * 5, y),
              (2.6 - local * 1.6).clamp(0.4, 3.0), p);
        }
        break;

      case FxShape.burst:
        for (var i = 0; i < 26; i++) {
          final a = (i / 26) * math.pi * 2 + rnd.nextDouble() * 0.3;
          final speed = 0.5 + rnd.nextDouble() * 0.7;
          final d = Curves.easeOutCubic.transform(t) * size.width * 0.6 * speed;
          p.color = v.color.withValues(alpha: _fade(t) * 0.9);
          canvas.drawCircle(
            center + Offset(math.cos(a) * d, math.sin(a) * d),
            (3.0 - t * 2.2).clamp(0.4, 3.0),
            p,
          );
        }
        break;

      case FxShape.ring:
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4;
        for (var i = 0; i < 3; i++) {
          final delay = i * 0.16;
          final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
          if (local <= 0) continue;
          p.color = v.color.withValues(alpha: _fade(local) * 0.7);
          canvas.drawCircle(
              center, Curves.easeOut.transform(local) * size.width * 0.5, p);
        }
        p.style = PaintingStyle.fill;
        break;

      case FxShape.snow:
        // escarcha en los bordes
        final frost = Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.transparent,
              v.color.withValues(alpha: 0.22 * math.sin(t * math.pi)),
            ],
            stops: const [0.45, 1.0],
          ).createShader(Offset.zero & size);
        canvas.drawRect(Offset.zero & size, frost);

        for (var i = 0; i < 30; i++) {
          final delay = rnd.nextDouble() * 0.5;
          final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
          if (local <= 0) continue;
          final x0 = rnd.nextDouble() * size.width;
          final x = x0 + math.sin(local * 4 + i) * 12;
          final y = -8 + local * (size.height + 16);
          final r = 1.2 + rnd.nextDouble() * 2.2;
          p.color = Colors.white.withValues(alpha: _fade(local) * 0.9);
          canvas.drawCircle(Offset(x, y), r, p);
        }
        break;

      case FxShape.sparkle:
        for (var i = 0; i < 16; i++) {
          final delay = rnd.nextDouble() * 0.55;
          final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
          if (local <= 0) continue;
          final x = rnd.nextDouble() * size.width;
          final y = rnd.nextDouble() * size.height;
          final s = math.sin(local * math.pi) * (4 + rnd.nextDouble() * 4);
          p.color = v.color.withValues(alpha: math.sin(local * math.pi));
          _star(canvas, Offset(x, y), s, p);
        }
        break;

      case FxShape.sweep:
        // banda especular que barre la pila en diagonal
        final pos = -0.4 + t * 1.8;
        final rect = Offset.zero & size;
        final band = Paint()
          ..blendMode = BlendMode.plus
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.55 * math.sin(t * math.pi)),
              v.color.withValues(alpha: 0.35 * math.sin(t * math.pi)),
              Colors.transparent,
            ],
            stops: [
              (pos - 0.22).clamp(0.0, 1.0),
              (pos - 0.06).clamp(0.0, 1.0),
              (pos + 0.06).clamp(0.0, 1.0),
              (pos + 0.22).clamp(0.0, 1.0),
            ],
          ).createShader(rect);
        canvas.drawRect(rect, band);
        for (var i = 0; i < 10; i++) {
          final local = ((t - rnd.nextDouble() * 0.4) / 0.6).clamp(0.0, 1.0);
          if (local <= 0) continue;
          p.color = Colors.white.withValues(alpha: _fade(local) * 0.8);
          _star(
            canvas,
            Offset(
                rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
            math.sin(local * math.pi) * 5,
            p,
          );
        }
        break;

      case FxShape.slash:
        final prog = Curves.easeOutExpo.transform(t.clamp(0.0, 0.5) / 0.5);
        final a = center + Offset(-size.width * 0.34, -size.height * 0.32);
        final b = center + Offset(size.width * 0.34, size.height * 0.32);
        final end = Offset.lerp(a, b, prog)!;
        p
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 7
          ..color = v.color.withValues(alpha: _fade(t) * 0.95);
        canvas.drawLine(a, end, p);
        p
          ..strokeWidth = 16
          ..color = v.color.withValues(alpha: _fade(t) * 0.25);
        canvas.drawLine(a, end, p);
        p.style = PaintingStyle.fill;
        break;

      case FxShape.bolt:
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round;
        final flick = (math.sin(t * 34) * 0.5 + 0.5) * _fade(t);
        for (var i = 0; i < 4; i++) {
          final path = Path();
          final x0 = size.width * (0.2 + 0.2 * i);
          path.moveTo(x0, 0);
          var y = 0.0;
          var x = x0;
          while (y < size.height) {
            y += size.height / 4;
            x += (rnd.nextDouble() - 0.5) * size.width * 0.22;
            path.lineTo(x, y);
          }
          p.color = v.color.withValues(alpha: flick * 0.9);
          canvas.drawPath(path, p);
          p
            ..strokeWidth = 7
            ..color = v.color.withValues(alpha: flick * 0.18);
          canvas.drawPath(path, p);
          p.strokeWidth = 2.6;
        }
        p.style = PaintingStyle.fill;
        break;

      case FxShape.drops:
        for (var i = 0; i < 14; i++) {
          final delay = rnd.nextDouble() * 0.45;
          final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
          if (local <= 0) continue;
          final x = size.width * (0.15 + rnd.nextDouble() * 0.7);
          final y = Curves.easeInQuad.transform(local) * size.height;
          p.color = v.color.withValues(alpha: _fade(local) * 0.9);
          final path = Path()
            ..moveTo(x, y - 6)
            ..quadraticBezierTo(x + 3.4, y, x, y + 3.4)
            ..quadraticBezierTo(x - 3.4, y, x, y - 6);
          canvas.drawPath(path, p);
        }
        break;

      case FxShape.swirl:
        for (var i = 0; i < 22; i++) {
          final a0 = (i / 22) * math.pi * 2;
          final a = a0 + t * 4.2;
          final r = size.width * 0.14 +
              Curves.easeOut.transform(t) * size.width * 0.3;
          p.color = v.color.withValues(alpha: _fade(t) * 0.85);
          canvas.drawCircle(
            center + Offset(math.cos(a) * r, math.sin(a) * r * 0.7),
            (2.8 - t * 2).clamp(0.4, 3.0),
            p,
          );
        }
        break;
    }
  }

  void _star(Canvas canvas, Offset c, double s, Paint p) {
    if (s <= 0.2) return;
    final path = Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CardFxPainter old) =>
      old.t != t || old.v != v || old.seed != seed;
}

/// Polvo que salta cuando la carta golpea la pila.
class ImpactPainter extends CustomPainter {
  final double t;
  final Color color;

  ImpactPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final center = Offset(size.width / 2, size.height / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * (1 - t);
    p.color = Colors.white.withValues(alpha: (1 - t) * 0.5);
    canvas.drawCircle(center, Curves.easeOutCubic.transform(t) * 62, p);

    p.style = PaintingStyle.fill;
    final rnd = math.Random(5);
    for (var i = 0; i < 14; i++) {
      final a = (i / 14) * math.pi * 2;
      final d = Curves.easeOutCubic.transform(t) * (30 + rnd.nextDouble() * 34);
      p.color = color.withValues(alpha: (1 - t) * 0.8);
      canvas.drawCircle(
        center + Offset(math.cos(a) * d, math.sin(a) * d * 0.55),
        (2.6 - t * 2).clamp(0.3, 2.6),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ImpactPainter old) => old.t != t;
}
