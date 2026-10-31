import 'engine.dart';

class DialogueLine {
  final String speaker;
  final String text;
  const DialogueLine(this.speaker, this.text);
}

/// Uses public events only: dialogue must never expose hidden cards or bluffing.
class DialogueDirector {
  final Map<String, int> _visits = {};
  static const opening = DialogueLine(
      'La habitación', 'La silla estaba tibia antes de que te sentaras.');
  DialogueLine? react(Fx fx, String actor) {
    final bank = switch (fx.kind) {
      FxKind.play => _play[actor] ??
          const [
            'El papel huele a una casa que ya no existe.',
            'Otra voz ocupa el lugar de un recuerdo.'
          ],
      FxKind.block => const [
          'Esa no es la versión que recuerdo.',
          'No. Volvé a contar esa parte.'
        ],
      FxKind.burn => const [
          'Había un rostro ahí. Ya no.',
          'El recuerdo se deshace entre los dedos.'
        ],
      FxKind.sing => const [
          '¿Y si del otro lado tampoco está tu casa?',
          'Todos dejan de respirar. Alguien mira la puerta.'
        ],
      FxKind.deny => const [
          'Por un momento, casi te creí.',
          'La cerradura vuelve a girar sola.'
        ],
      FxKind.turn => _turn[actor],
      _ => null,
    };
    if (bank == null || bank.isEmpty) return null;
    final key = '$actor-${fx.kind.name}';
    final n = _visits.update(key, (n) => n + 1, ifAbsent: () => 0);
    // Only authored NPCs speak; online players are never impersonated.
    final speaker = _play.containsKey(actor) &&
            fx.kind != FxKind.burn &&
            fx.kind != FxKind.sing
        ? actor
        : 'La habitación';
    return DialogueLine(speaker, bank[n % bank.length]);
  }

  static const _play = {
    'La Viuda': [
      'Él también decía que lo recordaba todo.',
      'Guardé esa fotografía. No sé por qué.',
      'No cambies el final. Es lo único que me queda.'
    ],
    'El Testigo': [
      'Estuve ahí. Aunque nadie me haya visto.',
      'La hora no coincide con tu historia.',
      'Seguí hablando. Estoy prestando atención.'
    ],
    'El Hueco': [
      'Esa voz… antes era mía.',
      'Me falta algo. Cada vez me falta menos.',
      'Cuando cierro los ojos, vos desaparecés.'
    ],
  };
  static const _turn = {
    'La Viuda': [
      'Nunca recogieron su plato.',
      'Prometió volver antes de que se enfriara.'
    ],
    'El Testigo': [
      'Empezá por donde dejaste de decir la verdad.',
      'No mires el reloj. No hay ninguno.'
    ],
    'El Hueco': [
      '¿Cuántas veces jugamos esto?',
      'Yo estaba sentado de tu lado.'
    ],
  };
}
