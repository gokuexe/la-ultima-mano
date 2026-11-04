import 'engine.dart';

class DialogueLine {
  final String speaker;
  final String text;
  const DialogueLine(this.speaker, this.text);
}

/// Uses public events only: dialogue must never expose hidden cards or bluffing.
class DialogueDirector {
  final Map<String, int> _visits = {};
  final DateTime Function() _now;
  DateTime? _holdUntil;
  int _priority = -1;
  DialogueDirector({DateTime Function()? now}) : _now = now ?? DateTime.now;

  DialogueLine beginRound(int round) {
    _visits.clear();
    _holdUntil = null;
    _priority = -1;
    return round <= 1
        ? opening
        : const DialogueLine('La habitación',
            'Volvés a sentarte. Esta vez, la silla está fría.');
  }

  static const opening = DialogueLine(
      'La habitación', 'La silla estaba tibia antes de que te sentaras.');
  DialogueLine? react(Fx fx, String actor, {bool allowNpcVoice = true}) {
    final npc = allowNpcVoice && _play.containsKey(actor);
    final priority = switch (fx.kind) {
      FxKind.win || FxKind.lose => 4,
      FxKind.sing || FxKind.deny => 3,
      FxKind.block || FxKind.burn => 2,
      FxKind.play => 1,
      _ => 0,
    };
    if (_holdUntil != null &&
        _now().isBefore(_holdUntil!) &&
        priority < _priority) {
      return null;
    }
    final bank = switch (fx.kind) {
      FxKind.play => _cards[fx.cardId] ??
          (npc ? _play[actor] : null) ??
          const [
            'El papel huele a una casa que ya no existe.',
            'Otra voz ocupa el lugar de un recuerdo.'
          ],
      FxKind.block => _cards[fx.cardId] ??
          const [
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
      FxKind.turn => npc ? _turn[actor] : null,
      FxKind.win => const [
          'La puerta cede. Afuera, alguien pronuncia tu nombre.',
          'Recordás el camino. Todavía no recordás quién te espera.'
        ],
      FxKind.lose => const [
          'Otra silla queda vacía. La tuya sigue tibia.',
          'Se fueron los pasos. El lugar en la mesa sigue siendo tuyo.'
        ],
      _ => null,
    };
    if (bank == null || bank.isEmpty) return null;
    _priority = priority;
    _holdUntil = _now().add(const Duration(seconds: 4));
    final key = '${npc ? actor : 'room'}-${fx.kind.name}-${fx.cardId ?? ''}';
    final n = _visits.update(key, (n) => n + 1, ifAbsent: () => 0);
    // Only authored NPCs speak; online players are never impersonated.
    final speaker = npc && fx.kind != FxKind.burn && fx.kind != FxKind.sing
        ? actor
        : 'La habitación';
    return DialogueLine(speaker, bank[n % bank.length]);
  }

  // Every entry refers to a public card action, never its hidden result.
  static const _cards = {
    'mas1': [
      'Por un instante, reconocés el pasillo.',
      'Una luz se enciende detrás de tus párpados.'
    ],
    'men1': [
      'Olvidaste por qué habías entrado.',
      'El pasillo tiene una puerta menos.'
    ],
    'mas2': [
      'Esto ya pasó. Esta vez, la lámpara estaba del otro lado.',
      'La segunda vez tampoco reconociste la voz.'
    ],
    'men2': [
      'Hay alguien justo donde no podés mirar.',
      'En el borde de la foto falta una persona.'
    ],
    'mas3': [
      'La fotografía sigue húmeda. Nadie trajo una cámara.',
      'En la foto, todos miran hacia tu silla.'
    ],
    'men3': [
      'La frase termina antes de que puedas recordarla.',
      'Sabés que falta algo. Eso es todo lo que queda.'
    ],
    'transferencia': [
      'La culpa pesa igual en otras manos.',
      'Alguien te devuelve un recuerdo que no pediste.'
    ],
    'sanguijuela': [
      'La voz cambia de boca, pero no de tono.',
      'Escuchás tu nombre en una voz prestada.'
    ],
    'intercambio': [
      'Al volver a mirar, las sillas parecen distintas.',
      'Durante un segundo, esta vida le pertenece a otro.'
    ],
    'volteo': [
      'El reflejo mueve la mano antes que vos.',
      'La luz cambia de lado. La sombra también.'
    ],
    'espejo': [
      'Dos versiones de una misma noche.',
      'El espejo devuelve una historia demasiado familiar.'
    ],
    'rebote': [
      'La otra versión llega antes de que termines la tuya.',
      'El papel vuelve. La marca de los dedos es distinta.'
    ],
    'sobrecarga': [
      'El reloj que no existe vuelve a sonar.',
      'Llevás demasiado tiempo sin cerrar los ojos.'
    ],
    'dobleJugada': [
      'Dos manos buscan la misma carta.',
      'Una voz termina lo que la otra empezó.'
    ],
    'respiro': [
      'Cerrás los ojos. La habitación sigue mirando.',
      'La oscuridad detrás de los párpados tiene otro tamaño.'
    ],
    'sincronia': [
      'Las dos manchas empiezan a parecerse.',
      'Todo encaja demasiado bien.'
    ],
    'ojear': [
      'La mirilla está tibia por dentro.',
      'Del otro lado del papel, algo respira.'
    ],
    'negar': [
      'Esa parte de la historia no cruza la mesa.',
      'Alguien apoya un dedo sobre la última palabra.'
    ],
    'congelar': [
      'La mano se detiene. El temblor continúa.',
      'La habitación guarda silencio hasta en las paredes.'
    ],
    'desmentir': [
      'La puerta escucha dos versiones distintas.',
      'Nadie mira la cerradura cuando vuelve a girar.'
    ],
  };

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
