import 'package:flutter/material.dart';
import '../collection_progress.dart';
import '../memory_fragments.dart';
import '../l10n/game_text.dart';
import '../theme.dart';

class AlbumScreen extends StatefulWidget {
  final String? focusId;
  const AlbumScreen({super.key, this.focusId});
  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  final _focus = GlobalKey();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _focus.currentContext;
      if (mounted && context != null) {
        Scrollable.ensureVisible(context,
            alignment: .1,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200));
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const GameText('ÁLBUM DE RECUERDOS')),
        body: ListenableBuilder(
            listenable: CollectionProgress.instance,
            builder: (context, _) {
              final progress = CollectionProgress.instance;
              return Center(
                  child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GameText(
                            'Recuerdos recuperados: ${progress.memories.length}/${memoryFragments.length}',
                            style: SS.title),
                        const SizedBox(height: 10),
                        const GameText(
                            'Cada partida terminada puede dejar una pista, incluso si perdés. Salir antes del resultado no desbloquea recuerdos.',
                            style: SS.body),
                        const SizedBox(height: 20),
                        for (var i = 0; i < memoryFragments.length; i++)
                          _MemoryTile(
                              key: memoryFragments[i].id == widget.focusId
                                  ? _focus
                                  : ValueKey(memoryFragments[i].id),
                              memory: memoryFragments[i],
                              number: i + 1,
                              unlocked: progress.memories
                                  .contains(memoryFragments[i].id)),
                        if (progress.memories.length ==
                            memoryFragments.length) ...[
                          const SizedBox(height: 12),
                          const GameText('LA QUINTA SILLA', style: SS.title),
                          const GameText(
                              'La quinta silla nunca estuvo en la fotografía. Está del otro lado de la mesa: donde alguien vuelve a repartir.',
                              style: SS.body),
                        ],
                        if (progress.saveError != null)
                          GameText(progress.saveError!, style: SS.sub),
                      ],
                    )),
              ));
            }),
      );
}

class _MemoryTile extends StatelessWidget {
  final MemoryFragment memory;
  final int number;
  final bool unlocked;
  const _MemoryTile(
      {super.key,
      required this.memory,
      required this.number,
      required this.unlocked});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: SS.panel(accent: unlocked ? SS.mana : SS.line),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GameText('FRAGMENTO ${number.toString().padLeft(2, '0')}',
              style: SS.sub),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(
                width: 64,
                height: 64,
                child: unlocked
                    ? CustomPaint(painter: _RelicPainter(memory.art))
                    : const Center(child: GameText('?', style: SS.title))),
            const SizedBox(width: 14),
            Expanded(
                child: GameText(
                    unlocked ? memory.title : 'Recuerdo sin recuperar',
                    style: SS.title)),
          ]),
          const SizedBox(height: 10),
          GameText(
              unlocked
                  ? memory.text
                  : 'Completá otra partida para encontrar una nueva pista.',
              style: unlocked ? SS.body : SS.sub),
        ]),
      );
}

class _RelicPainter extends CustomPainter {
  final int kind;
  _RelicPainter(this.kind);
  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 16;
    final paint = Paint()..isAntiAlias = false;
    void box(int x, int y, int w, int h, Color color) {
      paint.color = color;
      canvas.drawRect(
          Rect.fromLTWH(x * unit, y * unit, w * unit, h * unit), paint);
    }

    box(1, 1, 14, 14, SS.table);
    if (kind == 0) {
      box(2, 3, 12, 10, SS.ink);
      box(3, 4, 10, 6, SS.azul);
      for (var x = 4; x <= 10; x += 3) {
        box(x, 5, 2, 2, SS.table);
        box(x - 1, 7, 3, 2, SS.table);
      }
    } else if (kind == 3) {
      box(3, 3, 6, 6, SS.mana);
      box(4, 4, 4, 4, SS.table);
      box(8, 7, 5, 2, SS.mana);
      box(10, 9, 1, 3, SS.mana);
      box(12, 9, 1, 2, SS.mana);
    } else if (kind == 2) {
      box(3, 2, 8, 2, SS.azulUp);
      box(3, 4, 10, 7, SS.azul);
      box(5, 4, 2, 2, SS.ink);
      box(7, 6, 2, 2, SS.ink);
      box(9, 8, 2, 2, SS.ink);
      box(5, 11, 6, 2, SS.azulUp);
    } else {
      box(3, 2, 10, 12, SS.ink);
      for (var y = 5; y < 12; y += 2) {
        box(5, y, 6, 1, SS.line);
      }
      if (kind == 4) {
        box(3, 10, 3, 4, SS.rojo);
        box(6, 12, 3, 2, SS.table);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RelicPainter old) => old.kind != kind;
}
