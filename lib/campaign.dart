import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'game_config.dart';
import 'platform/local_store.dart';

class CampaignNight {
  final String id, title, character, opening, ending, room;
  final GameMode mode;
  const CampaignNight(this.id, this.title, this.character, this.opening,
      this.ending, this.room, this.mode);
  GameRules get rules => GameRules.balanced(mode);
}

const campaignNights = [
  CampaignNight(
      'widow',
      'NOCHE 1 · LA CENA FRÍA',
      'La Viuda',
      'La Viuda sirve un plato vacío. «Si salís, decime quién falta en esta mesa». Reconstruí tus recuerdos antes de que termine la cena.',
      'El plato ya no está vacío: hay una fotografía debajo. La quinta persona no se sentaba con ustedes. Era quien llamaba desde la puerta.',
      'dining',
      GameMode.classic),
  CampaignNight(
      'witness',
      'NOCHE 2 · EL ÚLTIMO VAGÓN',
      'El Testigo',
      'El tren no se mueve, pero las luces del túnel pasan por la ventana. El Testigo te pide una versión corta. Cada respuesta tiene menos tiempo.',
      'El Testigo dobla su declaración. «No vi quién abrió. Vi quién volvió a cerrar». En el vidrio aparece el reflejo de una cama de hospital.',
      'train',
      GameMode.fast),
  CampaignNight(
      'hollow',
      'NOCHE 3 · EL NOMBRE EN LA CAMA',
      'El Hueco',
      'El Hueco señala una pulsera sin nombre. «Podés contar la verdad. O podés convencerlos». Acá también se puede escapar de farol.',
      'La pulsera lleva los nombres de los cuatro. Recordás por qué repartían las cartas: nadie quería ser la última voz que quedara despierta. Esta vez dejás la puerta abierta.',
      'ward',
      GameMode.bluff),
];

class CampaignProgress extends ChangeNotifier {
  static CampaignProgress instance = CampaignProgress();
  final LocalStore? store;
  CampaignProgress({this.store});
  final Set<String> completed = {};
  String? saveError;
  Future<void> _writes = Future.value();
  bool unlocked(int index) =>
      index == 0 || completed.contains(campaignNights[index - 1].id);
  Future<void> load({bool firstChapterComplete = false}) async {
    completed.clear();
    saveError = null;
    try {
      final raw = await store?.read();
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final ids = data['completed'];
        if (ids is List) {
          for (final night in campaignNights) {
            if (!ids.contains(night.id)) break;
            completed.add(night.id);
          }
        }
      }
    } catch (_) {
      saveError = 'No se pudo leer la campaña guardada.';
    }
    if (firstChapterComplete) completed.add('widow');
    notifyListeners();
  }

  Future<void> complete(String id) {
    final index = campaignNights.indexWhere((n) => n.id == id);
    if (index < 0 || !unlocked(index) || !completed.add(id)) {
      return Future.value();
    }
    notifyListeners();
    final snapshot = jsonEncode({'completed': completed.toList()});
    _writes = _writes.then((_) async {
      try {
        await store?.write(snapshot);
        saveError = null;
      } on StorageFailure {
        saveError = 'La noche está completada, pero no pudo guardarse.';
      }
      notifyListeners();
    });
    return _writes;
  }
}
