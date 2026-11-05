import 'dart:async';
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
    'memory',
    'risk',
    'reaction',
    'pulse_ready',
    'anchor',
    'exchange',
    'tension',
  ];

  final Map<String, AudioPlayer> _players = {};
  bool _ready = false;
  Future<void>? _initializing;
  bool muted = false;
  double _masterVolume = 1;
  bool _adMuted = false;
  final Map<String, double> _lastVolumes = {};
  double get masterVolume => _masterVolume;
  double get effectiveVolume => _adMuted ? 0 : masterVolume;
  bool get adMuted => _adMuted;
  set adMuted(bool value) {
    _adMuted = value;
    _syncVolumes();
  }

  set masterVolume(double value) {
    _masterVolume = value.clamp(0, 1);
    _syncVolumes();
  }

  void _syncVolumes() {
    for (final entry in _players.entries) {
      unawaited(entry.value
          .setVolume(
              ((_lastVolumes[entry.key] ?? .85) * effectiveVolume).clamp(0, 1))
          .catchError((Object _) {}));
    }
  }

  Future<void> init() {
    if (_ready) return Future<void>.value();
    return _initializing ??= _load().whenComplete(() => _initializing = null);
  }

  Future<void> _load() async {
    for (final n in names) {
      if (_players.containsKey(n)) continue;
      AudioPlayer? player;
      try {
        final p = player = AudioPlayer(playerId: 'ss_$n');
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setSource(AssetSource('audio/$n.wav'));
        await p.setVolume(0.85 * effectiveVolume);
        _players[n] = p;
      } catch (e) {
        debugPrint('No se pudo cargar el sonido $n: $e');
        try {
          await player?.dispose();
        } catch (_) {
          // A failed native player may also reject disposal.
        }
      }
    }
    // Failed assets can be retried instead of permanently silencing the session.
    _ready = _players.length == names.length;
  }

  Future<void> play(String name, {double volume = 0.85}) async {
    if (muted || adMuted || effectiveVolume == 0 || !names.contains(name)) {
      return;
    }
    if (!_ready) await init();
    if (muted || adMuted || effectiveVolume == 0) return;
    final p = _players[name];
    if (p == null) return;
    try {
      _lastVolumes[name] = volume;
      await p.setVolume((volume * effectiveVolume).clamp(0.0, 1.0));
      // Android SoundPool does not emit onSeekComplete. AudioPlayer.seek()
      // waits for that event, so awaiting seek(0) prevents resume from running.
      // stop resets the position and retains the preloaded source (ReleaseMode.stop).
      await p.stop();
      await p.resume();
    } catch (e) {
      debugPrint('No se pudo reproducir $name: $e');
    }
  }

  void tap() {
    if (muted || adMuted) return;
    HapticFeedback.selectionClick();
  }

  void thump() {
    if (muted || adMuted) return;
    HapticFeedback.mediumImpact();
  }

  void heavy() {
    if (muted || adMuted) return;
    HapticFeedback.heavyImpact();
  }

  Future<void> disposeAll() async {
    await _initializing;
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
    _ready = false;
  }
}
