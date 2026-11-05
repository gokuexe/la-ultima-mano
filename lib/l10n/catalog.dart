import 'english_messages.dart';

/// Presentation only: canonical game values, player names and protocol IDs are not changed.
abstract final class Catalog {
  static final _folded = {
    for (final e in englishMessages.entries) e.key.toLowerCase(): e.value
  };
  static String translate(String source, String language) {
    if (language != 'en') return source;
    final exact = englishMessages[source];
    if (exact != null) return exact;
    final folded = _folded[source.toLowerCase()];
    if (folded != null) {
      return source == source.toUpperCase() ? folded.toUpperCase() : folded;
    }
    for (final rule in _rules) {
      final match = rule.$1.firstMatch(source);
      if (match != null) return rule.$2(match);
    }
    if (source.contains('\n')) {
      return source
          .split('\n')
          .map((line) => translate(line, language))
          .join('\n');
    }
    final separator = source.lastIndexOf(' · ');
    if (separator >= 0) {
      final tail = source.substring(separator + 3);
      if (englishMessages.containsKey(tail)) {
        return '${source.substring(0, separator)} · ${translate(tail, language)}';
      }
    }
    return source;
  }

  static String en(String source) => translate(source, 'en');
  static final _rules = <(RegExp, String Function(RegExpMatch))>[
    (
      RegExp(
          r'^Son las (\d{2}:\d{2}) en tu reloj\. Acá todavía es la misma noche\.$'),
      (m) => 'Your clock says ${m[1]}. It is still the same night here.'
    ),
    (
      RegExp(r'^Tu pantalla dice (.+)\. La puerta no conoce ese nombre\.$'),
      (m) => 'Your screen says ${m[1]}. The door does not know that name.'
    ),
    (RegExp(r'^Confirmar: (.+)$'), (m) => 'Confirm: ${en(m[1]!)}'),
    (RegExp(r'^Coste: (\d+) lucidez$'), (m) => 'Cost: ${m[1]} lucidity'),
    (
      RegExp(r'^Tu recuerdo: (roja|azul) · (\d+)$'),
      (m) => 'Your memory: ${en(m[1]!)} · ${m[2]}'
    ),
    (RegExp(r'^Rival: (.+)$'), (m) => 'Opponent: ${m[1]}'),
    (
      RegExp(r'^Recuerdo rival: (roja|azul)$'),
      (m) => 'Opponent memory: ${en(m[1]!)}'
    ),
    (RegExp(r'^Color: (roja|azul)$'), (m) => 'Color: ${en(m[1]!)}'),
    (RegExp(r'^ANCLAJE ([0-3])/3$'), (m) => 'ANCHOR ${m[1]}/3'),
    (RegExp(r'^Colección: (\d+) puntos$'), (m) => 'Collection: ${m[1]} points'),
    (RegExp(r'^\+(\d+) puntos de recuerdo$'), (m) => '+${m[1]} memory points'),
    (
      RegExp(r'^(.+) cambia un recuerdo de su mano\.$'),
      (m) => '${m[1]} exchanges one memory card.'
    ),
    (
      RegExp(r'^(.+) usa Anclaje: (.+) en su (roja|azul)\.$'),
      (m) => '${m[1]} uses Anchor: ${m[2]} on their ${en(m[3]!)} card.'
    ),
    (
      RegExp(r'^Lucidez disponible: (\d+)$'),
      (m) => 'Available lucidity: ${m[1]}'
    ),
    (RegExp(r'^Volumen: (\d+) %$'), (m) => 'Volume: ${m[1]} %'),
    (
      RegExp(r'^(\d+) de (\d+) cartas · Consultá sin usar lucidez\.$'),
      (m) => '${m[1]} of ${m[2]} cards · Browse without spending lucidity.'
    ),
    (
      RegExp(r'^(.+) · (\d+) lucidez$'),
      (m) => '${en(m[1]!)} · ${m[2]} lucidity'
    ),
    (RegExp(r'^(\d+) cartas$'), (m) => '${m[1]} cards'),
    (
      RegExp(r'^(\d+) LUCIDEZ( · RESPUESTA)?$'),
      (m) => '${m[1]} LUCIDITY${m[2] == null ? '' : ' · REACTION'}'
    ),
    (RegExp(r'^Revancha: (\d+)/(\d+)$'), (m) => 'Rematch: ${m[1]}/${m[2]}'),
    (RegExp(r'^Turno de (.+)$'), (m) => '${m[1]}’s turn'),
    (RegExp(r'^Modo (.+)$'), (m) => 'Mode: ${en(m[1]!)}'),
    (RegExp(r'^(.+) · Capítulo 01$'), (m) => '${en(m[1]!)} · Chapter 01'),
    (RegExp(r'^(\d+) · (\d+) gratis$'), (m) => '${m[1]} · ${m[2]} free'),
    (RegExp(r'^distancia: (\d+)$'), (m) => 'distance: ${m[1]}'),
    (RegExp(r'^Servidor: (.+)$'), (m) => 'Server: ${m[1]}'),
    (
      RegExp(
          r'^La mesa espera a (.+)\. Guardamos su asiento hasta 60 segundos\.$'),
      (m) => 'Waiting for ${m[1]}. Their seat is reserved for up to 60 seconds.'
    ),
    (
      RegExp(r'^(.+) recordó primero\. La habitación te reconoce\.$'),
      (m) => '${m[1]} remembered first. The room recognizes you.'
    ),
    (
      RegExp(r'^(.+): elegí una carta tuya$'),
      (m) => '${en(m[1]!)}: choose one of your cards'
    ),
    (
      RegExp(r'^(.+): elegí un rival$'),
      (m) => '${en(m[1]!)}: choose an opponent'
    ),
    (
      RegExp(r'^(.+): ¿qué carta de (.+)\?$'),
      (m) => '${en(m[1]!)}: which of ${m[2]}’s cards?'
    ),
    (RegExp(r'^(Roja|Azul)( · .+)?$'), (m) => '${en(m[1]!)}${m[2] ?? ''}'),
    (RegExp(r'^(.+) intenta recordar$'), (m) => '${m[1]} tries to remember'),
    (RegExp(r'^(.+) juega (.+)$'), (m) => '${m[1]} plays ${en(m[2]!)}'),
    (
      RegExp(
          r'^Empieza la partida \((.+)\)\. La puerta sigue cerrada\. Buscá el 6 y el 7\.$'),
      (m) =>
          'The match begins (${en(m[1]!)}). The door is still closed. Find the 6 and the 7.'
    ),
    (
      RegExp(r'^(.+) rozó el límite: (roja|azul) queda en (-?\d+)\.$'),
      (m) => '${m[1]} reached the limit: ${en(m[2]!)} stays at ${m[3]}.'
    ),
    (
      RegExp(r'^(.+) se quemó la (roja|azul) y robó una nueva\.$'),
      (m) => '${m[1]} burned the ${en(m[2]!)} card and drew a new one.'
    ),
    (
      RegExp(r'^(.+) responde con (.+)\.$'),
      (m) => '${m[1]} responds with ${en(m[2]!)}.'
    ),
    (
      RegExp(r'^(.+?) de (.+) queda cancelada\.$'),
      (m) => '${m[2]}’s ${en(m[1]!)} is cancelled.'
    ),
    (
      RegExp(r'^(.+) queda congelado por este turno\.$'),
      (m) => '${m[1]} cannot play again this turn.'
    ),
    (RegExp(r'^(.+) jugó (.+)\.$'), (m) => '${m[1]} played ${en(m[2]!)}.'),
    (
      RegExp(r'^(.+) canta ¡Lo recuerdo!$'),
      (m) => '${m[1]} calls “I remember!”'
    ),
    (
      RegExp(r'^El canto de (.+) queda anulado\. Suma (\d+) a su roja\.$'),
      (m) => '${m[1]}’s escape is denied. Add ${m[2]} to their red card.'
    ),
    (
      RegExp(r'^Desmienten el farol de (.+)\. Suma (\d+) a su roja\.$'),
      (m) => '${m[1]}’s bluff is challenged. Add ${m[2]} to their red card.'
    ),
    (
      RegExp(r'^Nadie desmintió: (.+) gana con el farol\.$'),
      (m) => 'No one challenged: ${m[1]} wins with a bluff.'
    ),
    (RegExp(r'^— Turno de (.+) —$'), (m) => '— ${m[1]}’s turn —'),
    (
      RegExp(r'^(.+) paga Sobrecarga: \+(\d+) a su roja\.$'),
      (m) => '${m[1]} pays for Insomnia: +${m[2]} to their red card.'
    ),
    (
      RegExp(r'^(.+) mira la (roja|azul) de (.+)\.$'),
      (m) => '${m[1]} looks at ${m[3]}’s ${en(m[2]!)} card.'
    ),
    (
      RegExp(r'^(.+) ojea una carta de (.+)\.$'),
      (m) => '${m[1]} looks at one of ${m[2]}’s cards.'
    ),
    (
      RegExp(r'^El azar le da \+(\d+) a la (roja|azul) de (.+)\.$'),
      (m) => 'Chance adds +${m[1]} to ${m[3]}’s ${en(m[2]!)} card.'
    ),
  ];
}
