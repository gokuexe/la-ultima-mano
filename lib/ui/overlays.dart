import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine.dart';
import '../model.dart';
import '../sfx.dart';
import '../theme.dart';

/// Pregunta modal. Cuando trae segundos es una ventana de reacción: la barra
/// se vacía y va sonando el tick, así la urgencia se siente sin leer nada.
class ChoiceOverlay extends StatefulWidget {
  final ChoiceRequest request;
  final void Function(Object? value) onPick;

  const ChoiceOverlay({
    super.key,
    required this.request,
    required this.onPick,
  });

  @override
  State<ChoiceOverlay> createState() => _ChoiceOverlayState();
}

class _ChoiceOverlayState extends State<ChoiceOverlay>
    with TickerProviderStateMixin {
  AnimationController? _timer;
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();
  int _lastTick = -1;

  @override
  void initState() {
    super.initState();
    final secs = widget.request.seconds;
    if (secs != null) {
      _timer = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: (secs * 1000).round()),
      )
        ..addListener(_onTick)
        ..forward();
      Sfx.i.thump();
    }
  }

  void _onTick() {
    if (!mounted) return;
    final secs = widget.request.seconds;
    if (secs == null) return;
    final left = (secs * (1 - _timer!.value)).ceil();
    if (left != _lastTick && left <= 5 && left > 0) {
      _lastTick = left;
      Sfx.i.play('tick', volume: 0.35);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final progress = _timer == null ? 1.0 : 1 - _timer!.value;

    return Positioned.fill(
      child: Container(
        color: const Color(0xE60A1219),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(22),
        child: FadeTransition(
          opacity: _enter,
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: _enter, curve: Curves.easeOutBack),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_timer != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: SS.surface,
                        valueColor: AlwaysStoppedAnimation(
                          Color.lerp(SS.rojo, SS.mana, progress)!,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    r.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: SS.ink,
                    ),
                  ),
                  if (r.desc.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(r.desc, textAlign: TextAlign.center, style: SS.sub),
                  ],
                  const SizedBox(height: 16),
                  for (final o in r.options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _OptionButton(
                        option: o,
                        onTap: () {
                          Sfx.i.tap();
                          widget.onPick(o.value);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final ChoiceOption option;
  final VoidCallback onTap;

  const _OptionButton({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tint =
        option.tint == null ? null : SS.of(option.tint == CardColor.red);
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
          decoration: BoxDecoration(
            color: SS.surface,
            borderRadius: BorderRadius.zero,
            border: Border(
              top: const BorderSide(color: SS.line),
              right: const BorderSide(color: SS.line),
              bottom: const BorderSide(color: SS.line),
              left: BorderSide(
                  color: tint ?? SS.line, width: tint == null ? 1 : 4),
            ),
          ),
          child: Text(
            option.label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: SS.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pantalla final con papelitos. Solo aparece cuando ganás vos; si gana un bot
/// la misma pantalla va sin confeti.
class EndOverlay extends StatefulWidget {
  final String winner;
  final bool youWon;
  final VoidCallback onAgain;
  final String againLabel;

  const EndOverlay({
    super.key,
    required this.winner,
    required this.youWon,
    required this.onAgain,
    this.againLabel = 'Volver a despertar',
  });

  @override
  State<EndOverlay> createState() => _EndOverlayState();
}

class _EndOverlayState extends State<EndOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xF00A1219),
        child: Stack(
          children: [
            if (widget.youWon)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) =>
                      CustomPaint(painter: _ConfettiPainter(_c.value)),
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.youWon ? 'LA PUERTA SE ABRE' : 'TE QUEDÁS ACÁ',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: widget.youWon ? SS.win : SS.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      widget.youWon
                          ? 'Del otro lado, alguien vuelve a repartir.'
                          : '${widget.winner} recordó primero. La habitación te reconoce.',
                      textAlign: TextAlign.center,
                      style: SS.sub),
                  const SizedBox(height: 26),
                  GestureDetector(
                    onTap: widget.onAgain,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 34, vertical: 14),
                      decoration: BoxDecoration(
                        color: SS.mana,
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Text(
                        widget.againLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2A1F05),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  _ConfettiPainter(this.t);

  static const _palette = [SS.mute, SS.mana, SS.ink];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(11);
    final paint = Paint();
    for (var i = 0; i < 70; i++) {
      final x0 = rnd.nextDouble() * size.width;
      final delay = rnd.nextDouble() * 0.3;
      final speed = 0.7 + rnd.nextDouble() * 0.6;
      final local = ((t - delay) * speed).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -30 + local * (size.height + 60);
      final x = x0 + math.sin(local * 7 + i) * 26;
      final w = 4.0 + rnd.nextDouble() * 5;
      final h = w * (1.4 + rnd.nextDouble());
      paint.color = _palette[i % _palette.length]
          .withValues(alpha: (1 - local * 0.55).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * 9 + i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          Radius.zero,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

/// Destello de pantalla completa cuando alguien canta. Es el momento más
/// importante de la partida, así que se toma un segundo entero.
class SingFlash extends StatelessWidget {
  final Animation<double> anim;
  final String actor;

  const SingFlash({super.key, required this.anim, required this.actor});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: anim,
          builder: (context, _) {
            final t = anim.value;
            if (t <= 0 || t >= 1) return const SizedBox.shrink();
            final fade = t < 0.25 ? t / 0.25 : (1 - t) / 0.75;
            return Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _RayPainter(t)),
                ),
                Opacity(
                  opacity: fade.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.7 +
                        Curves.easeOutBack.transform(
                              (t / 0.35).clamp(0.0, 1.0),
                            ) *
                            0.45,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          actor,
                          style: const TextStyle(fontSize: 13, color: SS.mute),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '¡LO RECUERDO!',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: SS.mana,
                            shadows: [
                              Shadow(
                                color: SS.mana.withValues(alpha: 0.8),
                                blurRadius: 26,
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RayPainter extends CustomPainter {
  final double t;
  _RayPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final fade = (1 - t) * 0.6;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            SS.mana.withValues(alpha: 0.30 * fade),
            Colors.transparent,
          ],
        ).createShader(Offset.zero & size),
    );

    final p = Paint()..color = SS.mana.withValues(alpha: 0.16 * fade);
    for (var i = 0; i < 14; i++) {
      final a = (i / 14) * math.pi * 2 + t * 0.7;
      final long = size.height * 1.3;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + math.cos(a - 0.045) * long,
            center.dy + math.sin(a - 0.045) * long)
        ..lineTo(center.dx + math.cos(a + 0.045) * long,
            center.dy + math.sin(a + 0.045) * long)
        ..close();
      canvas.drawPath(path, p);
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * (1 - t)
      ..color = SS.mana.withValues(alpha: (1 - t) * 0.55);
    canvas.drawCircle(
        center, Curves.easeOutCubic.transform(t) * size.width * 0.75, ring);
  }

  @override
  bool shouldRepaint(covariant _RayPainter old) => old.t != t;
}
