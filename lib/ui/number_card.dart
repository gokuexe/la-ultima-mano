import '../l10n/game_text.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../collection_progress.dart';

/// La carta grande del jugador. Todo el "jugo" del juego pasa por acá: el
/// número cambia con un salto, la carta tiembla y suelta brasas al quemarse, y
/// respira cuando llegás al 6/7.
class NumberCard extends StatefulWidget {
  final bool isRed;
  final int value;
  final bool win;
  final int burnToken;
  final VoidCallback? onTap;
  final bool selectable;

  const NumberCard({
    super.key,
    required this.isRed,
    required this.value,
    this.win = false,
    this.burnToken = 0,
    this.onTap,
    this.selectable = false,
  });

  @override
  State<NumberCard> createState() => _NumberCardState();
}

class _NumberCardState extends State<NumberCard> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final AnimationController _burn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  bool _up = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncGlow();
  }

  void _syncGlow() {
    if (!widget.win || MediaQuery.disableAnimationsOf(context)) {
      _glow.stop();
      _glow.value = 0;
    } else if (!_glow.isAnimating) {
      _glow.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant NumberCard old) {
    super.didUpdateWidget(old);
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (old.value != widget.value) {
      _up = widget.value > old.value;
      if (!reduced) _pulse.forward(from: 0);
    }
    if (old.burnToken != widget.burnToken && !reduced) _burn.forward(from: 0);
    _syncGlow();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _burn.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = SS.of(widget.isRed);
    final up = SS.upOf(widget.isRed);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _burn, _glow]),
        builder: (context, _) {
          final reduced = MediaQuery.disableAnimationsOf(context);
          final b = reduced ? 0.0 : _burn.value;
          final glow = reduced ? 0.0 : _glow.value;
          final shake =
              b > 0 && b < 1 ? math.sin(b * math.pi * 9) * (1 - b) * 11 : 0.0;
          final scale =
              reduced ? 1.0 : 1 + 0.07 * math.sin(_pulse.value * math.pi);

          return Transform.translate(
            offset: Offset(shake, 0),
            child: Transform.scale(
              scale: scale,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: double.infinity,
                    height:
                        112 * (MediaQuery.textScalerOf(context).scale(16) / 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.zero,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [SS.surfaceUp, SS.surface],
                      ),
                      border: Border.all(
                        color: widget.selectable
                            ? SS.mana
                            : widget.win
                                ? SS.win.withValues(alpha: 0.5 + 0.5 * glow)
                                : up,
                        width: widget.selectable || widget.win ? 2.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.win ? SS.win : base).withValues(
                              alpha: widget.win ? 0.25 + 0.3 * glow : 0.28),
                          blurRadius: widget.win ? 26 : 16,
                          spreadRadius: widget.win ? 2 : 0,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // brillo diagonal fijo, da sensación de carta plastificada
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.zero,
                            child: CustomPaint(painter: _SheenPainter()),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedSwitcher(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 280),
                              switchInCurve: Curves.easeOutBack,
                              transitionBuilder: (child, anim) {
                                final dir = _up ? 1.0 : -1.0;
                                return FadeTransition(
                                  opacity: anim,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: Offset(0, 0.45 * dir),
                                      end: Offset.zero,
                                    ).animate(anim),
                                    child: child,
                                  ),
                                );
                              },
                              child: GameText(
                                '${widget.value}',
                                key: ValueKey<int>(widget.value),
                                style: SS.numStyle.copyWith(fontSize: 48),
                              ),
                            ),
                            const SizedBox(height: 2),
                            GameText(
                              widget.isRed ? 'RECUERDO ROJO' : 'RECUERDO AZUL',
                              style: TextStyle(
                                fontSize: 14,
                                letterSpacing: 0.3,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                        if (CollectionProgress.instance.frame != 'plain')
                          Positioned.fill(
                              child: IgnorePointer(
                                  child: CustomPaint(
                                      painter: _MemoryFramePainter(
                                          CollectionProgress.instance.frame ==
                                                  'amber'
                                              ? SS.mana
                                              : SS.react)))),
                        // destello blanco del quemado
                        if (b > 0 && b < 0.4)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.zero,
                              child: Container(
                                color: Colors.white
                                    .withValues(alpha: (0.4 - b) * 1.9),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (b > 0 && b < 1)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(painter: _EmberPainter(b)),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SheenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.55, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.55)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: 0.07),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Brasas que suben cuando una carta se quema.
class _EmberPainter extends CustomPainter {
  final double t;
  _EmberPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < 16; i++) {
      final x = rnd.nextDouble() * size.width;
      final delay = rnd.nextDouble() * 0.35;
      final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y =
          size.height * (0.85 - local * 1.05) + math.sin(local * 6 + i) * 6;
      final r = (3.2 - local * 2.4) * (0.6 + rnd.nextDouble() * 0.8);
      paint.color = Color.lerp(
        const Color(0xFFFFD37A),
        const Color(0xFFE2404C),
        local,
      )!
          .withValues(alpha: (1 - local) * 0.9);
      canvas.drawCircle(Offset(x, y), r.clamp(0.5, 4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmberPainter old) => old.t != t;
}

class _MemoryFramePainter extends CustomPainter {
  final Color color;
  _MemoryFramePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..isAntiAlias = false;
    for (final x in [6.0, size.width - 16]) {
      for (final y in [6.0, size.height - 16]) {
        canvas.drawRect(Rect.fromLTWH(x, y, 10, 3), p);
        canvas.drawRect(Rect.fromLTWH(x, y, 3, 10), p);
      }
    }
  }

  @override
  bool shouldRepaint(_MemoryFramePainter old) => old.color != color;
}
