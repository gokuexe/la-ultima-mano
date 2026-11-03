import '../l10n/game_text.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'card_art.dart';
import 'pixel_art.dart';

/// Una carta que ya se jugó y quedó sobre la mesa.
class PlayedEntry {
  final int seq;
  final String cardId;
  final String actor;
  final double dx;
  final double dy;
  final double rot;
  bool blocked;

  PlayedEntry({
    required this.seq,
    required this.cardId,
    required this.actor,
    required this.dx,
    required this.dy,
    required this.rot,
    this.blocked = false,
  });

  static final _rnd = math.Random();

  factory PlayedEntry.scattered(int seq, String cardId, String actor) =>
      PlayedEntry(
        seq: seq,
        cardId: cardId,
        actor: actor,
        dx: (_rnd.nextDouble() - 0.5) * 26,
        dy: (_rnd.nextDouble() - 0.5) * 16,
        rot: (_rnd.nextDouble() - 0.5) * 0.5,
      );
}

/// La carita de una carta jugada. Chica, con su ícono y su color, para que de
/// un vistazo sepas qué hay en la pila sin leer nada.
class MiniCard extends StatelessWidget {
  final String cardId;
  final bool blocked;

  const MiniCard({super.key, required this.cardId, this.blocked = false});

  @override
  Widget build(BuildContext context) {
    final v = visualFor(cardId);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        width: 64,
        height: 86,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.zero,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(SS.surfaceUp, v.color, 0.18)!,
              Color.lerp(SS.surface, v.color, 0.06)!,
            ],
          ),
          border: Border.all(
            color: blocked ? SS.rojo : v.color.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 9,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: v.color.withValues(alpha: 0.22),
              blurRadius: 14,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PixelSigil(
                    seed: cardId.codeUnits.fold(0, (a, b) => a + b),
                    size: 32,
                    color: v.color),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GameText(
                    v.social,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
            if (blocked)
              Positioned.fill(
                child: CustomPaint(painter: _BlockedPainter()),
              ),
          ],
        ),
      ),
    );
  }

  IconData icon(CardVisual v) => v.icon;
}

class _BlockedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = SS.rojo.withValues(alpha: 0.85)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.16, size.height * 0.2),
        Offset(size.width * 0.84, size.height * 0.8), p);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// La mesa. Las cartas caen desde arriba, golpean la pila y sueltan su efecto.
class PlayedPile extends StatefulWidget {
  final List<PlayedEntry> entries;

  const PlayedPile({super.key, required this.entries});

  @override
  State<PlayedPile> createState() => _PlayedPileState();
}

class _PlayedPileState extends State<PlayedPile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  int _lastSeq = -1;

  @override
  void didUpdateWidget(covariant PlayedPile old) {
    super.didUpdateWidget(old);
    final top = widget.entries.isEmpty ? -1 : widget.entries.last.seq;
    if (top != _lastSeq) {
      _lastSeq = top;
      if (top >= 0) _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final visible =
        entries.length > 7 ? entries.sublist(entries.length - 7) : entries;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        gradient: const RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: [SS.surfaceUp, SS.table],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final c = MediaQuery.disableAnimationsOf(context) ? 1.0 : _c.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                const Positioned.fill(child: _Watermark()),

                // pila asentada
                for (var i = 0; i < visible.length; i++)
                  if (i < visible.length - 1)
                    _settled(visible[i], visible.length - 1 - i)
                  else
                    _landing(visible[i], c),

                if (visible.isEmpty)
                  GameText(
                    'la mesa está limpia',
                    style: SS.sub.copyWith(
                        fontSize: 11, color: SS.mute.withValues(alpha: 0.5)),
                  ),

                // efecto de la última carta, por encima de todo
                if (visible.isNotEmpty && c > 0 && c < 1)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: CardFxPainter(
                          t: ((c - 0.40) / 0.60).clamp(0.0, 1.0),
                          v: visualFor(visible.last.cardId),
                          seed: visible.last.seq * 7 + 3,
                        ),
                      ),
                    ),
                  ),

                if (visible.isNotEmpty && c > 0.45 && c < 0.95)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: ImpactPainter(
                          t: ((c - 0.45) / 0.5).clamp(0.0, 1.0),
                          color: visualFor(visible.last.cardId).color,
                        ),
                      ),
                    ),
                  ),

                // quién la jugó
                if (visible.isNotEmpty)
                  Positioned(
                    top: 8,
                    child: Opacity(
                      opacity: c < 0.15
                          ? c / 0.15
                          : (c > 0.8 ? ((1 - c) / 0.2).clamp(0.0, 1.0) : 1.0),
                      child: GameText(
                        '${visible.last.actor} · '
                        '${visualFor(visible.last.cardId).social}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: visualFor(visible.last.cardId).color,
                        ),
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

  Widget _settled(PlayedEntry e, int depth) {
    // cuanto más abajo en la pila, más apagada y más chica
    final f = (1 - depth * 0.09).clamp(0.5, 1.0);
    return Transform.translate(
      offset: Offset(e.dx, e.dy - depth * 1.5),
      child: Transform.rotate(
        angle: e.rot,
        child: Transform.scale(
          scale: 0.86 * f,
          child: Opacity(
            opacity: (1 - depth * 0.13).clamp(0.15, 1.0),
            child: MiniCard(cardId: e.cardId, blocked: e.blocked),
          ),
        ),
      ),
    );
  }

  Widget _landing(PlayedEntry e, double c) {
    final drop = Curves.easeOutBack.transform((c / 0.5).clamp(0.0, 1.0));
    final scale = 1.85 - 0.99 * drop;
    final y = -78 + (e.dy + 78) * drop;
    final rot = e.rot + (1 - drop) * 0.7;
    final settle = c > 0.5 ? math.sin((c - 0.5) * 20) * (1 - c) * 2.2 : 0.0;

    return Transform.translate(
      offset: Offset(e.dx, y + settle),
      child: Transform.rotate(
        angle: rot,
        child: Transform.scale(
          scale: (0.86 * scale).clamp(0.4, 2.0),
          child: Opacity(
            opacity: (c * 6).clamp(0.0, 1.0),
            child: MiniCard(cardId: e.cardId, blocked: e.blocked),
          ),
        ),
      ),
    );
  }
}

/// El mazo de robo: de acá salen las cartas que llegan a la mano. El alto de
/// la pila crece con lo que queda, así se ve venir cuando se está por acabar.
class DeckStack extends StatelessWidget {
  final int count;

  const DeckStack({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final layers = count <= 0 ? 0 : (1 + (count / 20).floor()).clamp(1, 4);
    return SizedBox(
      width: 72,
      height: 92,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < layers; i++)
            Positioned(
              left: 6.0 + i * 1.6,
              top: 6.0 - i * 1.8,
              child: const _CardBack(),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.zero,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: GameText(
                '$count',
                style: SS.numStyle.copyWith(fontSize: 11, color: SS.mute),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SS.tableUp, SS.table],
        ),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.09), width: 1.3),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 7,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameText('6',
                style: SS.numStyle.copyWith(
                    fontSize: 22, color: Colors.white.withValues(alpha: 0.14))),
            const SizedBox(width: 4),
            GameText('7',
                style: SS.numStyle.copyWith(
                    fontSize: 22, color: Colors.white.withValues(alpha: 0.14))),
          ],
        ),
      ),
    );
  }
}

/// El 6 y el 7 marcados al agua en la mesa: los números que no están en el mazo.
class _Watermark extends StatelessWidget {
  const _Watermark();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GameText('6',
                style: SS.numStyle.copyWith(
                    fontSize: 96,
                    color: Colors.white.withValues(alpha: 0.035))),
            const SizedBox(width: 18),
            GameText('7',
                style: SS.numStyle.copyWith(
                    fontSize: 96,
                    color: Colors.white.withValues(alpha: 0.035))),
          ],
        ),
      ),
    );
  }
}
