import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reproductor de efectos. Cada sonido tiene su propio AudioPlayer precargado
/// en modo baja latencia, así disparar uno no corta al anterior.
class Sfx {
  Sfx._();
  static final Sfx i = Sfx._();

  static const names = <String>[
    'play',
    'draw',
    'mana',
    'burn',
    'block',
    'sing',
    'deny',
    'win',
    'lose',
    'turn',
    'tick',
  ];

  final Map<String, AudioPlayer> _players = {};
  bool _ready = false;
  bool muted = false;

  Future<void> init() async {
    if (_ready) return;
    for (final n in names) {
      try {
        final p = AudioPlayer(playerId: 'ss_$n');
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setSource(AssetSource('audio/$n.wav'));
        await p.setVolume(0.85);
        _players[n] = p;
      } catch (e) {
        debugPrint('No se pudo cargar el sonido $n: $e');
      }
    }
    _ready = true;
  }

  Future<void> play(String name, {double volume = 0.85}) async {
    if (muted) return;
    final p = _players[name];
    if (p == null) return;
    try {
      await p.setVolume(volume);
      await p.seek(Duration.zero);
      await p.resume();
    } catch (e) {
      debugPrint('No se pudo reproducir $name: $e');
    }
  }

  void tap() {
    if (muted) return;
    HapticFeedback.selectionClick();
  }

  void thump() {
    if (muted) return;
    HapticFeedback.mediumImpact();
  }

  void heavy() {
    if (muted) return;
    HapticFeedback.heavyImpact();
  }

  Future<void> disposeAll() async {
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
    _ready = false;
  }
}
