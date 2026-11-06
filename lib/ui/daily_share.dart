import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../platform/share_card.dart';
import '../l10n/game_text.dart';
import '../theme.dart';
import 'pixel_art.dart';

class DailyShareDialog extends StatefulWidget {
  final String day;
  final int turns, attempt;
  final bool won;
  const DailyShareDialog(
      {super.key,
      required this.day,
      required this.turns,
      required this.attempt,
      required this.won});
  @override
  State<DailyShareDialog> createState() => _DailyShareDialogState();
}

class _DailyShareDialogState extends State<DailyShareDialog> {
  final _card = GlobalKey();
  bool _saving = false;
  String? _message;
  String get _outcome =>
      widget.won ? 'ESCAPÉ DE LA HABITACIÓN' : 'LA HABITACIÓN ME RETUVO';
  Future<void> _export() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final boundary =
          _card.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('PNG unavailable');
      final path = await exportResultCard(data.buffer.asUint8List(),
          'La-Ultima-Mano-${widget.day}-intento-${widget.attempt}.png');
      if (mounted) {
        setState(() => _message = path == null
            ? context.tr('La tarjeta está lista para compartir.')
            : 'PNG: $path');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = context
            .tr('No se pudo exportar la tarjeta. Podés copiar el resultado.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(
          text:
              'La Última Mano · ${widget.day}\n${context.tr(_outcome)}\n${context.tr('Turnos propios: ${widget.turns}')} · ${context.tr('Intento ${widget.attempt}')}\n${context.tr('Mismo reparto. ¿Podés escapar?')}'));
      if (mounted) setState(() => _message = context.tr('Resultado copiado.'));
    } catch (_) {
      if (mounted) {
        setState(() => _message = context
            .tr('El navegador no permitió copiar. Podés guardar la tarjeta.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            RepaintBoundary(
                key: _card,
                child: Container(
                    width: 320,
                    padding: const EdgeInsets.all(24),
                    color: SS.table,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const GameText('LA ÚLTIMA MANO',
                          textAlign: TextAlign.center, style: SS.title),
                      const SizedBox(height: 12),
                      const GameText('LA MANO DE HOY', style: SS.sub),
                      GameText(widget.day, translate: false, style: SS.body),
                      const SizedBox(height: 20),
                      const PixelSigil(seed: 67, color: SS.mana, size: 80),
                      const SizedBox(height: 20),
                      GameText(_outcome,
                          textAlign: TextAlign.center, style: SS.title),
                      GameText('Turnos propios: ${widget.turns}',
                          style: SS.body),
                      GameText('Intento ${widget.attempt}', style: SS.sub),
                      const SizedBox(height: 20),
                      const GameText('Mismo reparto. ¿Podés escapar?',
                          textAlign: TextAlign.center, style: SS.body),
                    ]))),
            const SizedBox(height: 12),
            const GameText('La tarjeta no muestra tus cartas ni la solución.',
                style: SS.sub),
            FilledButton(
                onPressed: _saving ? null : _export,
                child: const GameText('GUARDAR / COMPARTIR PNG')),
            TextButton(
                onPressed: _saving ? null : _copy,
                child: const GameText('COPIAR RESULTADO')),
            if (_message != null) SelectableText(_message!, style: SS.sub),
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const GameText('VOLVER AL RESULTADO')),
          ])));
}
