import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'platform/local_store.dart';
import 'collection_progress.dart';
import 'campaign.dart';

class RoomSkin {
  final String id, title;
  final int memories, night;
  const RoomSkin(this.id, this.title, this.memories, this.night);
}

const roomSkins = [
  RoomSkin('study', 'La habitación', 0, -1),
  RoomSkin('dining', 'El comedor abandonado', 2, 0),
  RoomSkin('train', 'El vagón vacío', 4, 1),
  RoomSkin('ward', 'La sala de hospital', 6, 2)
];

class RoomProgress extends ChangeNotifier {
  static RoomProgress instance = RoomProgress();
  final LocalStore? store;
  RoomProgress({this.store});
  String selected = 'study';
  String? saveError;
  Future<void> _writes = Future.value();
  bool unlocked(RoomSkin room) =>
      room.id == 'study' ||
      CollectionProgress.instance.memories.length >= room.memories ||
      CampaignProgress.instance.completed
          .contains(campaignNights[room.night].id);
  String get effective => roomSkins.any((r) => r.id == selected && unlocked(r))
      ? selected
      : 'study';
  Future<void> load() async {
    selected = 'study';
    saveError = null;
    try {
      final raw = await store?.read();
      if (raw != null) {
        final id = (jsonDecode(raw) as Map<String, dynamic>)['room'];
        if (id is String && roomSkins.any((r) => r.id == id && unlocked(r))) {
          selected = id;
        }
      }
    } catch (_) {
      saveError = 'No se pudo leer la habitación elegida.';
    }
    notifyListeners();
  }

  Future<void> select(String id) {
    if (!roomSkins.any((r) => r.id == id && unlocked(r))) return Future.value();
    selected = id;
    notifyListeners();
    final snapshot = jsonEncode({'room': id});
    _writes = _writes.then((_) async {
      try {
        await store?.write(snapshot);
        saveError = null;
      } on StorageFailure {
        saveError = 'La habitación cambió, pero no pudo guardarse.';
      }
      notifyListeners();
    });
    return _writes;
  }
}
