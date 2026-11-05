import 'package:flutter/material.dart';
import '../engine.dart';
import '../theme.dart';
import '../l10n/game_text.dart';

class PulseStrip extends StatelessWidget {
  final GameEngine engine;
  const PulseStrip({super.key, required this.engine});
  @override
  Widget build(BuildContext context) {
    final pulse = engine.me.pulse;
    return Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Tooltip(
              message: context.tr(
                  'Ganás una carga al cerrar tu turno. Con 3, Anclaje ajusta un recuerdo en +1 o −1.'),
              child: OutlinedButton(
                  key: const ValueKey('pulse-button'),
                  onPressed:
                      engine.canUsePulse(0) ? () => engine.humanPulse() : null,
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: pulse == 3 ? SS.mana : SS.line),
                      minimumSize: const Size(48, 48)),
                  child: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        GameText('ANCLAJE $pulse/3',
                            style: TextStyle(
                                fontSize: 14,
                                color: pulse == 3 ? SS.mana : SS.mute)),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          for (var i = 0; i < 3; i++)
                            AnimatedContainer(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(right: 3),
                              width: 8,
                              height: 16,
                              decoration: BoxDecoration(
                                  color: i < pulse
                                      ? (pulse == 3 ? SS.mana : SS.react)
                                      : SS.surface,
                                  border: Border.all(color: SS.line)),
                            )
                        ]),
                      ]))),
          if (engine.me.exchangeAvailable)
            TextButton.icon(
                key: const ValueKey('exchange-button'),
                onPressed:
                    engine.canExchange(0) ? () => engine.humanExchange() : null,
                icon: const Icon(Icons.swap_horiz, size: 20),
                label: const GameText('CAMBIAR 1 CARTA',
                    style: TextStyle(fontSize: 14))),
        ]);
  }
}
