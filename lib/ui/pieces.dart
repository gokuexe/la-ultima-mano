import '../l10n/game_text.dart';
import 'package:flutter/material.dart';

import '../engine.dart';
import '../model.dart';
import '../theme.dart';
import 'card_art.dart';
import 'pixel_art.dart';

/// Panel de un rival. Sus dos cartas están tapadas hasta que las mires con
/// Ojear; el maná en cambio siempre es público, y es la mejor pista de si
/// puede interrumpirte.
class RivalPanel extends StatelessWidget {
  final Player player;
  final bool active;
  final bool hostile;
  final bool seesRed;
  final bool seesBlue;

  const RivalPanel({
    super.key,
    required this.player,
    required this.active,
    this.hostile = false,
    required this.seesRed,
    required this.seesBlue,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: active ? SS.surfaceUp : SS.surface,
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: hostile
              ? SS.rojoUp
              : active
                  ? SS.mana
                  : SS.line,
          width: active ? 1.6 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: SS.mana.withValues(alpha: 0.22),
                  blurRadius: 14,
                )
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PixelPortrait(
              character: player.id - 1, active: active, hostile: hostile),
          const SizedBox(height: 4),
          GameText(
            player.name,
            translate: false,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: active ? SS.ink : SS.mute,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _chip(true, seesRed ? player.red : null),
              const SizedBox(width: 4),
              _chip(false, seesBlue ? player.blue : null),
            ],
          ),
          const SizedBox(height: 6),
          GameText('${player.hand.length} cartas',
              style: const TextStyle(fontSize: 14, color: SS.mute)),
          const SizedBox(height: 4),
          ManaPips(value: player.mana, max: 5, size: 5),
          if (player.pulse > 0)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Tooltip(
                    message: context.tr('ANCLAJE ${player.pulse}/3'),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (var i = 0; i < 3; i++)
                        Container(
                            margin: const EdgeInsets.only(right: 3),
                            width: 7,
                            height: 7,
                            color: i < player.pulse ? SS.react : SS.surfaceUp)
                    ]))),
        ],
      ),
    );
  }

  Widget _chip(bool red, int? value) {
    final known = value != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      width: 27,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: known ? SS.of(red) : const Color(0xFF302B32),
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: known
              ? SS.upOf(red).withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: GameText(
        known ? '$value' : '?',
        style: SS.numStyle.copyWith(
          fontSize: 15,
          color: known ? Colors.white : const Color(0xFFA79B8D),
        ),
      ),
    );
  }
}

/// Puntitos de maná. Se llenan con un pequeño rebote para que gastarlo se note.
class ManaPips extends StatelessWidget {
  final int value;
  final int max;
  final double size;

  const ManaPips({
    super.key,
    required this.value,
    this.max = 7,
    this.size = 11,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) {
        final on = i < value;
        return Padding(
          padding: EdgeInsets.only(right: i == max - 1 ? 0 : size * 0.32),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: on ? 1.0 : 0.0),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            builder: (context, t, _) => Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                color: Color.lerp(const Color(0xFF403940), SS.mana, t),
                boxShadow: t > 0.5
                    ? [
                        BoxShadow(
                          color: SS.mana.withValues(alpha: 0.45 * t),
                          blurRadius: size * 0.8,
                        )
                      ]
                    : null,
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Registro público de la partida. Es la única fuente de información sobre los
/// rivales, así que conviene que se lea cómodo.
class LogView extends StatefulWidget {
  final List<LogEntry> entries;
  const LogView({super.key, required this.entries});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  final _ctrl = ScrollController();

  @override
  void didUpdateWidget(covariant LogView old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_ctrl.hasClients) {
        _ctrl.animateTo(
          _ctrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListView.builder(
        controller: _ctrl,
        padding: EdgeInsets.zero,
        itemCount: widget.entries.length,
        itemBuilder: (context, i) {
          final e = widget.entries[i];
          final last = i == widget.entries.length - 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: GameText(
              e.text,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: last || e.loud ? SS.ink : SS.mute,
                fontWeight: e.loud ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Una carta de acción en la mano. Usa el mismo ícono y color que su versión
/// en la pila, para que se reconozca de un vistazo qué va a caer si se juega.
/// Se mece sola con un movimiento leve y desincronizado entre cartas, así la
/// mano se siente viva sin llamar la atención.
class HandCard extends StatefulWidget {
  static double scaleFor(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(16) / 16;
  static double heightFor(BuildContext context) => 300 * scaleFor(context);

  final ActionCard card;
  final bool enabled;
  final VoidCallback onTap;
  final String? disabledReason;
  final int? effectiveCost;
  const HandCard(
      {super.key,
      required this.card,
      required this.enabled,
      required this.onTap,
      this.disabledReason,
      this.effectiveCost});
  @override
  State<HandCard> createState() => _HandCardState();
}

class _HandCardState extends State<HandCard> {
  bool _hover = false;
  bool _back = false;
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final v = visualFor(widget.card.id);
    final accent = widget.enabled ? v.color : SS.mute;
    return MouseRegion(
      cursor:
          widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: EdgeInsets.only(top: _hover ? 0 : 6, bottom: _hover ? 6 : 0),
        width: (220 * HandCard.scaleFor(context)).clamp(
            180, (MediaQuery.sizeOf(context).width - 106).clamp(180, 320)),
        height: HandCard.heightFor(context),
        decoration: SS.panel(accent: accent, raised: _hover),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 4, 4),
              child: Row(children: [
                Expanded(
                    child: GameText(widget.card.name.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 16, color: SS.ink, height: 1.2))),
                SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip:
                            context.tr(_back ? 'Ver efecto' : 'Leer recuerdo'),
                        onPressed: () => setState(() => _back = !_back),
                        icon: Icon(Icons.flip, size: 16, color: SS.mute))),
              ])),
          Expanded(
              child: GestureDetector(
            onTapDown: (_) {
              if (widget.enabled && !MediaQuery.disableAnimationsOf(context)) {
                setState(() => _pressed = true);
              }
            },
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            behavior: HitTestBehavior.opaque,
            onTap: _back
                ? () => setState(() => _back = false)
                : widget.enabled
                    ? widget.onTap
                    : null,
            child: AnimatedScale(
                scale: _pressed ? 0.97 : 1.0,
                duration: const Duration(milliseconds: 90),
                child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                    child: _back ? _memory(v) : _face(v, accent))),
          )),
        ]),
      ),
    );
  }

  Widget _face(CardVisual v, Color accent) => Column(
        key: const ValueKey('face'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                  color: SS.table, border: Border.all(color: SS.line)),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                GameText('┌', style: TextStyle(color: accent)),
                PixelSigil(
                    seed: widget.card.id.codeUnits.fold(0, (a, b) => a + b),
                    color: accent,
                    size: 32),
                GameText('┘', style: TextStyle(color: accent)),
              ])),
          const SizedBox(height: 8),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GameText(
                  '${widget.effectiveCost ?? widget.card.cost} LUCIDEZ${widget.card.isReaction ? ' · RESPUESTA' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: SS.mana))),
          const SizedBox(height: 6),
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SingleChildScrollView(
                      child: GameText(widget.card.desc,
                          style: const TextStyle(
                              fontSize: 16, height: 1.35, color: SS.ink))))),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: SS.table,
              child: GameText(
                  widget.enabled
                      ? 'JUGAR RECUERDO'
                      : widget.disabledReason ?? 'ESPERÁ TU MOMENTO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14, color: widget.enabled ? SS.win : SS.mute))),
        ],
      );

  Widget _memory(CardVisual v) => Padding(
        key: const ValueKey('memory'),
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          PixelSigil(seed: widget.card.id.length, color: v.color, size: 54),
          const SizedBox(height: 16),
          GameText(v.post.replaceAll('*', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.3, color: SS.ink)),
          const SizedBox(height: 16),
          GameText(v.stamp, style: TextStyle(fontSize: 14, color: v.color)),
          const SizedBox(height: 12),
          const GameText('Tocá para volver', style: SS.sub),
        ])),
      );
}
