/// Variantes de reglas. El motor lee esto; la UI elige modo en el título.
enum GameMode { classic, fast, bluff }

class GameRules {
  final GameMode mode;
  final int edition;
  bool get isBalanced => edition >= 2;

  const GameRules([this.mode = GameMode.classic]) : edition = 1;

  const GameRules.balanced([this.mode = GameMode.classic]) : edition = 2;

  const GameRules.classic()
      : mode = GameMode.classic,
        edition = 1;
  const GameRules.fast()
      : mode = GameMode.fast,
        edition = 1;
  const GameRules.bluff()
      : mode = GameMode.bluff,
        edition = 1;

  String get label => switch (mode) {
        GameMode.classic => 'Clásico',
        GameMode.fast => 'Rápido',
        GameMode.bluff => 'Farol',
      };

  String get blurb => switch (mode) {
        GameMode.classic =>
          'Canto solo con 6 y 7 reales. Quemado: número nuevo al azar.',
        GameMode.fast => isBalanced
            ? '3 lucidez por turno, mano más chica, reacciones de 5 s y recambio. Límites 0/13 sin quemar.'
            : '2 maná por turno, mano más chica, reacciones de 5 s. Límites 0/13 sin quemar.',
        GameMode.bluff =>
          'Podés cantar de farol (cerca del 6/7). Si no te desmienten, ganás.',
      };

  int get manaPerTurn => mode == GameMode.fast && !isBalanced ? 2 : 3;
  int get initialHandSize => mode == GameMode.fast ? 2 : 3;
  int get maxHandSize => mode == GameMode.fast ? 5 : 6;
  double get reactionSeconds => mode == GameMode.fast ? 5 : 8;
  bool get allowBluffSing => mode == GameMode.bluff;
  int get maxBluffDistance => 2;
  bool get softBurn => mode == GameMode.fast;
}
