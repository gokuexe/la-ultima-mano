import 'dialogue.dart';

/// Match-local reactions to public actions. No profiling, files or hidden cards.
class HabitDialogue {
  final DateTime Function() now;
  HabitDialogue({DateTime Function()? now}) : now = now ?? DateTime.now;
  int _insomnia = 0, _cancellations = 0, _denied = 0;
  final Set<String> _shown = {};
  DateTime? _last;
  DateTime? _hold;
  bool get holdsDialogue => _hold != null && now().isBefore(_hold!);
  void reset() {
    _insomnia = 0;
    _cancellations = 0;
    _denied = 0;
    _shown.clear();
    _last = null;
    _hold = null;
  }

  void played(String cardId) {
    if (cardId == 'sobrecarga') _insomnia++;
  }

  void cancelled() => _cancellations++;
  void escapeDenied() => _denied++;

  DialogueLine? takeCue({required bool allowed, required bool npcVoices}) {
    if (!allowed ||
        _shown.length >= 3 ||
        (_last != null &&
            now().difference(_last!) < const Duration(seconds: 12))) {
      return null;
    }
    final candidates = <String>[
      if (_denied >= 1) 'denied',
      if (_insomnia >= 2) 'insomnia',
      if (_cancellations >= 3) 'cancel',
    ];
    for (final key in candidates) {
      if (!_shown.add(key)) continue;
      _last = now();
      _hold = now().add(const Duration(seconds: 7));
      final line = _lines[key]!;
      return DialogueLine(
          npcVoices ? line.speaker : 'La habitación', line.text);
    }
    return null;
  }

  static const _lines = {
    'insomnia': DialogueLine('El Testigo',
        'Otra vez Insomnio. Ya sé qué noche estás tratando de olvidar.'),
    'cancel': DialogueLine('La Viuda',
        'Elegís. Retrocedés. Volvés a elegir. ¿Siempre dudabas cuando te llamaban desde la puerta?'),
    'denied': DialogueLine('El Hueco',
        'Intentaste salir y la puerta te devolvió. Ahora tu silla conoce el peso de tu miedo.'),
  };
}
