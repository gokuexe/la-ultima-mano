import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'chapter.dart';
import 'play_preferences.dart';

class StoryProgress extends ChangeNotifier {
  static final instance = StoryProgress(
      file: PlayPreferences.instance.file == null
          ? null
          : File(
              '${PlayPreferences.instance.file!.parent.path}/story-progress.json'));
  final File? file;
  StoryProgress({this.file});
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
      if (file != null &&
          await file!.exists() &&
          await file!.length() <= 4096) {
        final data =
            jsonDecode(await file!.readAsString()) as Map<String, dynamic>;
        memory = switch (data['memory']) {
          'name' => MemoryPath.name,
          'door' => MemoryPath.door,
          _ => null
        };
        tutorialComplete = memory != null && data['tutorialComplete'] == true;
        chapterComplete = tutorialComplete && data['chapterComplete'] == true;
      }
    } on FileSystemException {
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
        if (file == null) {
          throw const FileSystemException('No storage configured');
        }
        await file!.parent.create(recursive: true);
        final temporary = File('${file!.path}.$pid.tmp');
        await temporary.writeAsString(snapshot, flush: true);
        await temporary.rename(file!.path);
        saveError = null;
      } on FileSystemException {
        saveError =
            'El avance funciona en esta sesión, pero no pudo guardarse.';
      }
      notifyListeners();
    });
    return _writes;
  }
}
