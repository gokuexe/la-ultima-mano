import 'dialogue.dart';

/// Presentation only. Accepts the local player's distance, never rival values.
/// Device text is read lazily and is never read while the option is disabled.
class TensionDirector {
  final DateTime Function() now;
  TensionDirector({DateTime Function()? now}) : now = now ?? DateTime.now;
  int level = 0;
  int _visits = 0;
  bool _near = false;
  DateTime? _lastCue;
  DateTime? holdUntil;

  void reset() {
    level = 0;
    _visits = 0;
    _near = false;
    _lastCue = null;
    holdUntil = null;
  }

  DialogueLine? observe({
    required int distance,
    required bool enabled,
    required bool settled,
    required bool finished,
    required bool npcVoices,
    required bool deviceHints,
    required String Function(int) readDeviceHint,
  }) {
    if (!enabled || finished) {
      level = 0;
      _near = false;
      holdUntil = null;
      return null;
    }
    if (!settled) return null;
    level = distance == 0
        ? 2
        : distance == 1
            ? 1
            : 0;
    if (level == 0) {
      _near = false;
      return null;
    }
    final entering = !_near;
    _near = true;
    if (!entering ||
        _visits >= 3 ||
        (_lastCue != null &&
            now().difference(_lastCue!) < const Duration(seconds: 12))) {
      return null;
    }
    final index = _visits++;
    _lastCue = now();
    holdUntil = now().add(const Duration(seconds: 7));
    final base = npcVoices ? _rivals[index] : _room[index];
    final text =
        deviceHints ? '${base.text}\n${readDeviceHint(index)}' : base.text;
    // Online uses only the room bank; authored NPCs can break the fourth wall locally.
    return DialogueLine(base.speaker, text);
  }

  bool get holdsDialogue => holdUntil != null && now().isBefore(holdUntil!);
  static const _rivals = [
    DialogueLine('La Viuda',
        'No. No vas a dejarme otra vez. Alejá la mano de esa puerta.'),
    DialogueLine('El Testigo',
        'Casi lo recordás. Qué conveniente. ¿También recordás quién se quedó afuera?'),
    DialogueLine('El Hueco',
        'Si cerrás el juego, ¿quién se queda mirando desde este lado de la pantalla?'),
  ];
  static const _room = [
    DialogueLine('La habitación',
        'La lámpara pierde calor. Algo no quiere que termines esta partida.'),
    DialogueLine(
        'La habitación', 'Los números encajan. La sombra de tu silla, no.'),
    DialogueLine('La habitación',
        'Estás mirando una pantalla. Eso no explica por qué la puerta está detrás de vos.'),
  ];
}
