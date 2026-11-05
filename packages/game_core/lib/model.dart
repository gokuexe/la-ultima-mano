/// Modelo puro del juego: no depende de Flutter ni del motor, así se puede
/// testear solo y más adelante correr igual en un servidor para el online.
library;

enum CardColor { red, blue }

String colorName(CardColor c) => c == CardColor.red ? 'roja' : 'azul';

enum Need { own, color, foe, foeCard }

enum ReactKind { none, card, sing }

enum CardFamily { motor, interaccion, riesgo, reaccion, info }

class Targets {
  CardColor? own;
  CardColor? color;
  int? foe;
  CardColor? foeColor;

  Targets({this.own, this.color, this.foe, this.foeColor});

  Targets copy() =>
      Targets(own: own, color: color, foe: foe, foeColor: foeColor);
}

class Player {
  final int id;
  final String name;
  final bool human;

  int red;
  int blue;
  int mana = 0;
  int pending = 0;
  int free = 0;
  bool overload = false;
  bool insomniaUsed = false;
  bool exchangeAvailable = false;
  bool attemptedEscape = false;
  int pulse = 0;
  bool endNow = false;
  bool frozen = false;
  final List<String> hand = [];

  Player({
    required this.id,
    required this.name,
    required this.human,
    required this.red,
    required this.blue,
  });

  int value(CardColor c) => c == CardColor.red ? red : blue;

  void setValue(CardColor c, int v) {
    if (c == CardColor.red) {
      red = v;
    } else {
      blue = v;
    }
  }

  bool get isWin => (red == 6 && blue == 7) || (red == 7 && blue == 6);

  /// Cuántos puntos faltan en total para el 6/7, en la mejor de las dos
  /// asignaciones posibles.
  int get distance {
    final a = (red - 6).abs() + (blue - 7).abs();
    final b = (red - 7).abs() + (blue - 6).abs();
    return a < b ? a : b;
  }
}

/// Lo que una carta puede hacerle a la partida. El motor implementa esto, así
/// las cartas se definen sin conocerlo.
abstract class EffectCtx {
  List<Player> get players;
  Player get self;
  Targets get q;

  void bump(Player p, CardColor c, int n);
  void assign(Player p, CardColor c, int v);
  void reveal(Player p, CardColor c);
  int roll(int max);
  void log(String text);
}

typedef Effect = void Function(EffectCtx ctx);

class ActionCard {
  final String id;
  final String name;
  final String desc;
  final int cost;
  final CardFamily family;
  final List<Need> needs;
  final ReactKind react;
  final Effect? effect;

  const ActionCard({
    required this.id,
    required this.name,
    required this.desc,
    required this.cost,
    required this.family,
    this.needs = const [],
    this.react = ReactKind.none,
    this.effect,
  });

  bool get isReaction => react != ReactKind.none;
  bool get blind => needs.contains(Need.foe) || needs.contains(Need.foeCard);
}

// ---------------------------------------------------------------------------
// Catálogo
// ---------------------------------------------------------------------------

final Map<String, ActionCard> kCards = {
  // --- motor ---------------------------------------------------------------
  'mas1': ActionCard(
    id: 'mas1',
    name: 'Destello',
    desc: 'Sumá 1 a una carta tuya.',
    cost: 1,
    family: CardFamily.motor,
    needs: const [Need.own],
    effect: (c) => c.bump(c.self, c.q.own!, 1),
  ),
  'men1': ActionCard(
    id: 'men1',
    name: 'Laguna',
    desc: 'Restá 1 a una carta tuya.',
    cost: 1,
    family: CardFamily.motor,
    needs: const [Need.own],
    effect: (c) => c.bump(c.self, c.q.own!, -1),
  ),
  'mas2': ActionCard(
    id: 'mas2',
    name: 'Déjà vu',
    desc: 'Sumá 2 a una carta tuya.',
    cost: 2,
    family: CardFamily.motor,
    needs: const [Need.own],
    effect: (c) => c.bump(c.self, c.q.own!, 2),
  ),
  'men2': ActionCard(
    id: 'men2',
    name: 'Punto ciego',
    desc: 'Restá 2 a una carta tuya.',
    cost: 2,
    family: CardFamily.motor,
    needs: const [Need.own],
    effect: (c) => c.bump(c.self, c.q.own!, -2),
  ),
  'mas3': ActionCard(
    id: 'mas3',
    name: 'La fotografía',
    desc: 'Sumá 3 a una carta tuya.',
    cost: 3,
    family: CardFamily.motor,
    needs: const [Need.own],
    effect: (c) => c.bump(c.self, c.q.own!, 3),
  ),
  'men3': ActionCard(
    id: 'men3',
    name: 'Amnesia',
    desc: 'Restá 3 a una carta tuya.',
    cost: 3,
    family: CardFamily.motor,
    needs: const [Need.own],
    effect: (c) => c.bump(c.self, c.q.own!, -3),
  ),

  // --- interacción ---------------------------------------------------------
  'transferencia': ActionCard(
    id: 'transferencia',
    name: 'Culpa ajena',
    desc: 'Restá 2 a una carta tuya y sumáselos a un rival.',
    cost: 2,
    family: CardFamily.interaccion,
    needs: const [Need.own, Need.foeCard],
    effect: (c) {
      c.bump(c.self, c.q.own!, -2);
      c.bump(c.players[c.q.foe!], c.q.foeColor!, 2);
    },
  ),
  'sanguijuela': ActionCard(
    id: 'sanguijuela',
    name: 'Voz ajena',
    desc: 'Restá 1 a un rival y sumáte 1.',
    cost: 2,
    family: CardFamily.interaccion,
    needs: const [Need.own, Need.foeCard],
    effect: (c) {
      c.bump(c.players[c.q.foe!], c.q.foeColor!, -1);
      c.bump(c.self, c.q.own!, 1);
    },
  ),
  'intercambio': ActionCard(
    id: 'intercambio',
    name: 'Otra vida',
    desc: 'Cambiá tu carta por la del mismo color de un rival.',
    cost: 3,
    family: CardFamily.interaccion,
    needs: const [Need.color, Need.foe],
    effect: (c) {
      final foe = c.players[c.q.foe!];
      final col = c.q.color!;
      final mine = c.self.value(col);
      c.assign(c.self, col, foe.value(col));
      c.assign(foe, col, mine);
    },
  ),
  'volteo': ActionCard(
    id: 'volteo',
    name: 'El reflejo',
    desc: 'Intercambiá los valores de tus dos cartas.',
    cost: 1,
    family: CardFamily.interaccion,
    effect: (c) {
      final r = c.self.red;
      c.assign(c.self, CardColor.red, c.self.blue);
      c.assign(c.self, CardColor.blue, r);
    },
  ),
  'espejo': ActionCard(
    id: 'espejo',
    name: 'Falso recuerdo',
    desc: 'Copiá el valor de la carta de un rival en la tuya del mismo color.',
    cost: 3,
    family: CardFamily.interaccion,
    needs: const [Need.color, Need.foe],
    effect: (c) {
      final col = c.q.color!;
      c.assign(c.self, col, c.players[c.q.foe!].value(col));
    },
  ),
  'rebote': ActionCard(
    id: 'rebote',
    name: 'La otra versión',
    desc: 'Una carta rival pasa a valer 13 menos su valor.',
    cost: 3,
    family: CardFamily.interaccion,
    needs: const [Need.foeCard],
    effect: (c) {
      final foe = c.players[c.q.foe!];
      c.assign(foe, c.q.foeColor!, 13 - foe.value(c.q.foeColor!));
    },
  ),

  // --- riesgo y lucidez -------------------------------------------------------
  'sobrecarga': ActionCard(
    id: 'sobrecarga',
    name: 'Insomnio',
    desc: 'Ganá 2 lucidez. Al cerrar el turno sumás 0–5 al azar a tu roja.',
    cost: 0,
    family: CardFamily.riesgo,
    effect: (c) {
      c.self.mana = (c.self.mana + 2).clamp(0, 7);
      c.self.overload = true;
    },
  ),
  'dobleJugada': ActionCard(
    id: 'dobleJugada',
    name: 'Personalidad doble',
    desc: 'Tus próximas 2 cartas son gratis. Sumá 0–5 al azar a la elegida.',
    cost: 0,
    family: CardFamily.riesgo,
    needs: const [Need.own],
    effect: (c) {
      c.self.free += 2;
      final r = c.roll(6);
      c.log('El azar le da +$r a la ${colorName(c.q.own!)} de ${c.self.name}.');
      c.bump(c.self, c.q.own!, r);
    },
  ),
  'respiro': ActionCard(
    id: 'respiro',
    name: 'Cerrar los ojos',
    desc: 'Terminás el turno ya. El próximo abrís con 5 lucidez.',
    cost: 0,
    family: CardFamily.riesgo,
    effect: (c) {
      c.self.pending = 5;
      c.self.endNow = true;
    },
  ),
  'sincronia': ActionCard(
    id: 'sincronia',
    name: 'Obsesión',
    desc: 'Tus dos cartas toman el valor de la que elijas.',
    cost: 2,
    family: CardFamily.riesgo,
    needs: const [Need.own],
    effect: (c) {
      final v = c.self.value(c.q.own!);
      c.assign(c.self, CardColor.red, v);
      c.assign(c.self, CardColor.blue, v);
    },
  ),

  // --- información ---------------------------------------------------------
  'ojear': ActionCard(
    id: 'ojear',
    name: 'La mirilla',
    desc: 'Mirás una carta de un rival.',
    cost: 1,
    family: CardFamily.info,
    needs: const [Need.foeCard],
    effect: (c) => c.reveal(c.players[c.q.foe!], c.q.foeColor!),
  ),

  // --- reacción ------------------------------------------------------------
  'negar': const ActionCard(
    id: 'negar',
    name: 'Negación',
    desc: 'Cancela una carta rival antes de que se resuelva.',
    cost: 2,
    family: CardFamily.reaccion,
    react: ReactKind.card,
  ),
  'congelar': const ActionCard(
    id: 'congelar',
    name: 'Parálisis',
    desc: 'Cancela la carta y el rival no juega más este turno.',
    cost: 2,
    family: CardFamily.reaccion,
    react: ReactKind.card,
  ),
  'desmentir': const ActionCard(
    id: 'desmentir',
    name: 'No te creo',
    desc: 'Impide escapar. Suma 1 a su roja; 2 si era un farol.',
    cost: 2,
    family: CardFamily.reaccion,
    react: ReactKind.sing,
  ),
};

/// Edition 2 is opt-in. The original catalog remains available for older rooms.
final Map<String, ActionCard> kBalancedCards = {
  ...kCards,
  'congelar': const ActionCard(
    id: 'congelar',
    name: 'Parálisis',
    desc: 'Cancela la carta y el rival no juega más este turno.',
    cost: 3,
    family: CardFamily.reaccion,
    react: ReactKind.card,
  ),
  'volteo': ActionCard(
    id: 'volteo',
    name: 'El reflejo',
    desc: 'Sumá 1 a un recuerdo tuyo y restá 1 al otro.',
    cost: 2,
    family: CardFamily.interaccion,
    needs: const [Need.own],
    effect: (c) {
      final chosen = c.q.own!;
      c.bump(c.self, chosen, 1);
      c.bump(
          c.self, chosen == CardColor.red ? CardColor.blue : CardColor.red, -1);
    },
  ),
  'sobrecarga': ActionCard(
    id: 'sobrecarga',
    name: 'Insomnio',
    desc:
        'Ganá 2 lucidez. Al cerrar el turno sumás 0–5 al azar a tu roja. Un uso por turno.',
    cost: 0,
    family: CardFamily.riesgo,
    effect: (c) {
      c.self.mana = (c.self.mana + 2).clamp(0, 7);
      c.self.overload = true;
    },
  ),
};

/// Composición del mazo: 73 cartas.
const List<List<Object>> kDeckList = [
  ['mas1', 10],
  ['men1', 8],
  ['mas2', 6],
  ['men2', 5],
  ['mas3', 3],
  ['men3', 3],
  ['transferencia', 3],
  ['sanguijuela', 3],
  ['intercambio', 2],
  ['volteo', 3],
  ['espejo', 2],
  ['rebote', 2],
  ['sobrecarga', 3],
  ['dobleJugada', 2],
  ['respiro', 2],
  ['sincronia', 2],
  ['negar', 4],
  ['congelar', 3],
  ['desmentir', 3],
  ['ojear', 4],
];

/// Los valores que existen en el mazo de números. Ni 6 ni 7: hay que armarlos.
const List<int> kValues = [0, 1, 2, 3, 4, 5, 8, 9, 10, 11, 12, 13];
