import 'package:flutter/material.dart';
import '../chapter.dart';
import '../story_progress.dart';
import '../theme.dart';
import 'game_screen.dart';

enum _Scene { introduction, lesson, briefing, ending }

class ChapterScreen extends StatefulWidget {
  final StoryProgress? progress;
  final Future<bool?> Function(BuildContext, MemoryPath)? playMatch;
  const ChapterScreen({super.key, this.progress, this.playMatch});
  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen> {
  late final StoryProgress _progress =
      widget.progress ?? StoryProgress.instance;
  late _Scene _scene = _progress.chapterComplete
      ? _Scene.ending
      : _progress.tutorialComplete
          ? _Scene.briefing
          : _progress.memory != null
              ? _Scene.lesson
              : _Scene.introduction;
  final _lesson = MemoryLesson();
  bool _busy = false;
  bool _won = false;
  String? _feedback;
  @override
  void initState() {
    super.initState();
    _won = _progress.chapterComplete;
  }

  Future<void> _choose(MemoryPath path) async {
    if (_busy) return;
    setState(() => _busy = true);
    await _progress.update(memory: path);
    if (mounted) {
      setState(() {
        _busy = false;
        _scene = _Scene.lesson;
      });
    }
  }

  Future<void> _practiceDone() async {
    if (_busy) return;
    if (!_lesson.ready) {
      setState(() => _feedback =
          'La puerta no responde. Necesitás un 6 y un 7, en cualquier orden.');
      return;
    }
    setState(() => _busy = true);
    await _progress.update(tutorialComplete: true);
    if (mounted) {
      setState(() {
        _busy = false;
        _scene = _Scene.briefing;
        _feedback = null;
      });
    }
  }

  Future<void> _play() async {
    if (_busy) return;
    setState(() => _busy = true);
    final path = _progress.memory!;
    final won = widget.playMatch != null
        ? await widget.playMatch!(context, path)
        : await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => GameScreen(chapterMemory: path)));
    if (!mounted) return;
    if (won == true) await _progress.update(chapterComplete: true);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (won != null) {
        _won = won;
        _scene = _Scene.ending;
      }
    });
  }

  void _adjust(bool red, int delta) {
    setState(() {
      _feedback = _lesson.adjust(redCard: red, delta: delta)
          ? 'Usaste 1 lucidez. Elegí tu próximo movimiento.'
          : 'No alcanza la lucidez. Reiniciá la práctica para probar otra combinación.';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('HISTORIA · CAPÍTULO 01')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: ListView(
                  key: ValueKey(_scene),
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text(ChapterOne.title, style: SS.title),
                    const SizedBox(height: 20),
                    if (_scene == _Scene.introduction) ...[
                      const Text('DESPERTAR', style: SS.title),
                      const SizedBox(height: 12),
                      const Text(
                          'Hay cuatro sillas y una lámpara. La tuya sigue moviéndose, como si acabaras de levantarte.\n\n'
                          'Una mujer alisa un mantel que no existe. Un hombre observa una puerta cerrada. La cuarta figura evita tu mirada.\n\n'
                          'Sobre la mesa hay un papel doblado. Detrás de vos, alguien golpea la madera una sola vez. ¿Qué seguís primero?',
                          style: SS.body),
                      const SizedBox(height: 24),
                      FilledButton(
                          onPressed:
                              _busy ? null : () => _choose(MemoryPath.name),
                          child: const Text('LEER EL PAPEL CON MI NOMBRE')),
                      OutlinedButton(
                          onPressed:
                              _busy ? null : () => _choose(MemoryPath.door),
                          child: const Text('EXAMINAR LA PUERTA')),
                    ],
                    if (_scene == _Scene.lesson) ...[
                      Text(ChapterOne.clue(_progress.memory!), style: SS.body),
                      const SizedBox(height: 20),
                      const Text('PRÁCTICA · DOS RECUERDOS', style: SS.title),
                      const SizedBox(height: 12),
                      const Text(
                          'Esta mesa de práctica no tiene rivales ni reloj. Armá un 6 y un 7 usando Destello (+1) y Laguna (−1). Cada uso cuesta 1 lucidez.\n\nEn una partida real también podés terminar tu turno para recuperar lucidez al volver a jugar.',
                          style: SS.body),
                      const SizedBox(height: 16),
                      Text('Lucidez disponible: ${_lesson.lucidity}',
                          style: SS.title),
                      const SizedBox(height: 16),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _practiceCard(true, _lesson.red)),
                            const SizedBox(width: 12),
                            Expanded(child: _practiceCard(false, _lesson.blue)),
                          ]),
                      if (_feedback != null)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(_feedback!, style: SS.body)),
                      FilledButton(
                          onPressed: _busy ? null : _practiceDone,
                          child: const Text('INTENTAR SALIR')),
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _lesson.reset();
                                    _feedback = null;
                                  }),
                          child: const Text('REINICIAR PRÁCTICA')),
                    ],
                    if (_scene == _Scene.briefing) ...[
                      const Text('LA PRIMERA MESA', style: SS.title),
                      const SizedBox(height: 12),
                      Text(ChapterOne.opening(_progress.memory!),
                          style: SS.body),
                      const SizedBox(height: 16),
                      const Text(
                          'La Viuda guarda una fotografía. El Testigo cuenta las veces que mirás la puerta. El Hueco repite tu último suspiro.\n\n'
                          'Ahora jugás una partida Clásica contra los tres. La práctica no cambia el reparto ni sus decisiones. Llegá a 6 y 7 e intentá salir durante tu turno.\n\n'
                          'Una reacción puede frenar una carta o impedir tu salida. Cuando el juego te pregunte, elegí antes de que termine la barra. Podés consultar la guía desde el botón de ajustes de la mesa.',
                          style: SS.body),
                      const SizedBox(height: 24),
                      FilledButton(
                          onPressed: _busy ? null : _play,
                          child: const Text('JUGAR LA PRIMERA MESA')),
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _lesson.reset();
                                    _scene = _Scene.lesson;
                                  }),
                          child: const Text('VOLVER A PRACTICAR')),
                    ],
                    if (_scene == _Scene.ending) ...[
                      Text(_won ? 'DEL OTRO LADO' : 'OTRA SILLA',
                          style: SS.title),
                      const SizedBox(height: 16),
                      Text(ChapterOne.ending(_progress.memory!, _won),
                          style: SS.body),
                      const SizedBox(height: 24),
                      if (_progress.chapterComplete)
                        const Text(
                            'Capítulo completado · Desenlace disponible al volver.',
                            style: SS.sub),
                      FilledButton(
                          onPressed: _busy ? null : _play,
                          child: Text(_won
                              ? 'VOLVER A JUGAR EL CAPÍTULO'
                              : 'VOLVER A INTENTARLO')),
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('VOLVER AL MENÚ')),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                        'Se guardan tu decisión y los pasos completados. La partida en curso no se guarda.',
                        style: SS.sub),
                    if (_progress.saveError != null)
                      Text(_progress.saveError!,
                          style: const TextStyle(color: SS.rojoUp)),
                    if (_busy) const LinearProgressIndicator(),
                  ],
                ))),
      );
  Widget _practiceCard(bool red, int value) => Container(
      padding: const EdgeInsets.all(12),
      decoration: SS.panel(accent: SS.of(red)),
      child: Column(children: [
        Text(red ? 'ROJO' : 'AZUL', style: SS.sub),
        Text('$value',
            style: SS.numStyle.copyWith(fontSize: 48, color: SS.upOf(red))),
        OutlinedButton(
            onPressed: _busy ? null : () => _adjust(red, 1),
            child: const Text('DESTELLO +1')),
        OutlinedButton(
            onPressed: _busy ? null : () => _adjust(red, -1),
            child: const Text('LAGUNA −1')),
      ]));
}
