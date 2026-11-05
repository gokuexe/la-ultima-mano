import 'dart:convert';
import 'platform/local_store.dart';
import 'package:flutter/foundation.dart';
import 'sfx.dart';

/// Local preferences only. No account or network is involved.
class PlayPreferences extends ChangeNotifier {
  static PlayPreferences instance =
      PlayPreferences(store: createStore('preferences'));
  final LocalStore? store;
  PlayPreferences({this.store});
  double volume = 1;
  double textScale = 1;
  bool reduceMotion = false;
  bool tension = true;
  bool deviceHints = false;
  String language = 'es';
  String? saveError;
  Future<void> _writes = Future<void>.value();

  Future<void> load() async {
    saveError = null;
    volume = 1;
    textScale = 1;
    reduceMotion = false;
    language = 'es';
    tension = true;
    deviceHints = false;
    try {
      final raw = await store?.read();
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final v = data['volume'];
        final t = data['textScale'];
        if (v is num && v.isFinite) volume = v.toDouble().clamp(0, 1);
        if (t is num && t.isFinite) {
          textScale = (t.clamp(1, 1.2) * 10).round() / 10;
        }
        reduceMotion = data['reduceMotion'] == true;
        tension = data['tension'] != false;
        deviceHints = data['deviceHints'] == true;
        language = data['language'] == 'en' ? 'en' : 'es';
      }
    } on StorageFailure {
      saveError = 'No se pudieron leer los ajustes guardados.';
    } on FormatException {
      saveError =
          'Los ajustes guardados no eran válidos. Se usan los valores iniciales.';
    } on TypeError {
      saveError =
          'Los ajustes guardados no eran válidos. Se usan los valores iniciales.';
    }
    _applySound();
    notifyListeners();
  }

  void _applySound() {
    Sfx.i.masterVolume = volume;
    Sfx.i.muted = volume == 0;
  }

  Future<void> update(
      {double? volume,
      double? textScale,
      bool? reduceMotion,
      bool? tension,
      bool? deviceHints,
      String? language}) {
    if (volume != null && volume.isFinite) this.volume = volume.clamp(0, 1);
    if (textScale != null && textScale.isFinite) {
      this.textScale = (textScale.clamp(1, 1.2) * 10).round() / 10;
    }
    if (reduceMotion != null) this.reduceMotion = reduceMotion;
    if (tension != null) this.tension = tension;
    if (deviceHints != null) this.deviceHints = deviceHints;
    if (language == 'en' || language == 'es') this.language = language!;
    _applySound();
    notifyListeners();
    final snapshot = jsonEncode({
      'volume': this.volume,
      'textScale': this.textScale,
      'reduceMotion': this.reduceMotion,
      'tension': this.tension,
      'deviceHints': this.deviceHints,
      'language': this.language
    });
    _writes = _writes.then((_) async {
      try {
        if (store == null) throw const StorageFailure('No storage configured');
        await store!.write(snapshot);
        saveError = null;
      } on StorageFailure {
        saveError =
            'El cambio funciona ahora, pero no pudo guardarse para la próxima vez.';
      }
      notifyListeners();
    });
    return _writes;
  }
}
