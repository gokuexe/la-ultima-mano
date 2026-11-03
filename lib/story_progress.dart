import 'dart:convert';
import 'platform/local_store.dart';
import 'package:flutter/foundation.dart';
import 'chapter.dart';

class StoryProgress extends ChangeNotifier {
  static final instance = StoryProgress(store: createStore('story-progress'));
  final LocalStore? store;
  StoryProgress({this.store});
  MemoryPath? memory;
  bool tutorialComplete = false;
  bool chapterComplete = false;
  String? saveError;
  Future<void> _writes = Future<void>.value();

  Future<void> load() async {
    memory = null;
    tutorialComplete = false;
    chapterComplete = false;
    saveError = null;
    try {
      final raw = await store?.read();
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        memory = switch (data['memory']) {
          'name' => MemoryPath.name,
          'door' => MemoryPath.door,
          _ => null
        };
        tutorialComplete = memory != null && data['tutorialComplete'] == true;
        chapterComplete = tutorialComplete && data['chapterComplete'] == true;
      }
    } on StorageFailure {
      saveError = 'No se pudo leer el avance guardado.';
    } on FormatException {
      saveError = 'El avance guardado no era válido. Podés volver a empezar.';
    } on TypeError {
      saveError = 'El avance guardado no era válido. Podés volver a empezar.';
    }
    notifyListeners();
  }

  Future<void> update(
      {MemoryPath? memory, bool? tutorialComplete, bool? chapterComplete}) {
    if (memory != null) this.memory = memory;
    if (tutorialComplete == true && this.memory != null) {
      this.tutorialComplete = true;
    }
    if (chapterComplete == true && this.tutorialComplete) {
      this.chapterComplete = true;
    }
    final snapshot = jsonEncode({
      'memory': this.memory?.name,
      'tutorialComplete': this.tutorialComplete,
      'chapterComplete': this.chapterComplete
    });
    notifyListeners();
    _writes = _writes.then((_) async {
      try {
        if (store == null) throw const StorageFailure('No storage configured');
        await store!.write(snapshot);
        saveError = null;
      } on StorageFailure {
        saveError =
            'El avance funciona en esta sesión, pero no pudo guardarse.';
      }
      notifyListeners();
    });
    return _writes;
  }
}
