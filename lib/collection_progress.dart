import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'platform/local_store.dart';

/// Cosmetic, device-local rewards. They never change game rules or server scores.
class CollectionProgress extends ChangeNotifier {
  static CollectionProgress instance = CollectionProgress();
  final LocalStore? store;
  CollectionProgress({this.store});
  int points = 0;
  String frame = 'plain';
  String? saveError;
  Future<void> _writes = Future.value();
  static const thresholds = {'plain': 0, 'amber': 40, 'echo': 100};
  bool unlocked(String name) =>
      thresholds.containsKey(name) && points >= thresholds[name]!;
  Future<void> load() async {
    points = 0;
    frame = 'plain';
    saveError = null;
    try {
      final raw = await store?.read();
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final n = data['points'];
        if (n is int && n >= 0) points = n.clamp(0, 1000000000);
        final saved = data['frame'];
        if (saved is String && unlocked(saved)) frame = saved;
      }
    } on StorageFailure {
      saveError = 'No se pudo leer la colección.';
    } on FormatException {
      saveError = 'La colección guardada no era válida.';
    } on TypeError {
      saveError = 'La colección guardada no era válida.';
    }
    notifyListeners();
  }

  Future<void> awardMatch({required bool won}) {
    points = (points + (won ? 30 : 10)).clamp(0, 1000000000);
    return _save();
  }

  Future<void> selectFrame(String name) {
    if (!unlocked(name)) return Future.value();
    frame = name;
    return _save();
  }

  Future<void> _save() {
    notifyListeners();
    final data = jsonEncode({'points': points, 'frame': frame});
    _writes = _writes.then((_) async {
      if (store == null) return;
      try {
        await store!.write(data);
        saveError = null;
      } on StorageFailure {
        saveError = 'Los puntos funcionan ahora, pero no pudieron guardarse.';
      }
      notifyListeners();
    });
    return _writes;
  }
}
