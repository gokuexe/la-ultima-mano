import 'dart:async';
import 'dart:math';

import 'game_notifier.dart';

import 'game_config.dart';
import 'model.dart';
import 'story.dart';

enum FxKind { play, draw, mana, burn, block, sing, deny, win, lose, turn }

class Fx {
  final FxKind kind;
  final int? playerId;
  final CardColor? color;
  final String? cardId;
  final String? actorName;

  const Fx(this.kind, {this.playerId, this.color, this.cardId, this.actorName});
}

class ChoiceOption {
  final String label;
  final Object? value;
  final CardColor? tint;
  final bool danger;

  const ChoiceOption(this.label, this.value, {this.tint, this.danger = false});
}

class ChoiceRequest {
  final String title;
  final String desc;
  final List<ChoiceOption> options;
  final double? seconds;
  final DateTime startedAt;
  final Completer<Object?> completer;
  final int playerId;

  ChoiceRequest({
    required this.title,
    required this.desc,
    required this.options,
    required this.completer,
    this.seconds,
    this.playerId = 0,
  }) : startedAt = DateTime.now();

  double get remaining {
    if (seconds == null) return 1;
    final gone = DateTime.now().difference(startedAt).inMilliseconds / 1000.0;
    return ((seconds! - gone) / seconds!).clamp(0.0, 1.0);
  }
}

class LogEntry {
  final String text;
  final bool loud;
  const LogEntry(this.text, {this.loud = false});
}

class _Move {
  final String key;
  final Targets targets;
  final double score;
  const _Move(this.key, this.targets, this.score);
}

class GameEngine extends GameNotifier {
  final Random _rng = Random();
  final GameRules rules;

  late List<Player> players;
  late List<String> deck;
  final List<LogEntry> logs = [];
  final Map<int, Set<String>> knowledge = {};
  Set<String> get known => knowledge.putIfAbsent(0, () => {});
  final Set<int> humanPlayerIds;
  final List<String> playerNames;

  int turn = 0;
  bool busy = false;
  String? winner;
  String? statusMessage;
  ChoiceRequest? choice;

  /// Contadores por jugador+color: cada vez que una carta se quema el número
  /// sube, y la UI usa eso para disparar la animación sin repetirla de más.
  final Map<String, int> burnTokens = {};

  void Function(Fx fx)? onFx;
  bool _dead = false;

  GameEngine(
      {this.rules = const GameRules(),
      this.humanPlayerIds = const {0},
      this.playerNames = Story.opponents}) {
    newGame();
  }

  /// ¿Puede este jugador intentar cantar ahora?
  bool canSing(int id) {
    final p = players[id];
    if (p.isWin) return true;
    if (!rules.allowBluffSing) return false;
    return p.distance <= rules.maxBluffDistance;
  }

  Iterable<Player> _othersFrom(int actorId) sync* {
    final n = players.length;
    for (var k = 1; k < n; k++) {
      yield players[(actorId + k) % n];
    }
  }

  @override
  void dispose() {
    _dead = true;
    super.dispose();
  }

  void _emit(Fx fx) => onFx?.call(fx);

  void _touch() {
    if (!_dead) notifyListeners();
  }

  Player get me => players[0];
  Player get current => players[turn];
  bool get myTurn => turn == 0 && !busy && winner == null && choice == null;

  List<Player> foesOf(int id) => players.where((p) => p.id != id).toList();

  bool seesCard(int playerId, CardColor c, {int viewerId = 0}) =>
      playerId == viewerId ||
      (knowledge[viewerId]?.contains('$playerId-${c.index}') ?? false);

  // ---------------------------------------------------------------- setup ---

  int _drawValue() => kValues[_rng.nextInt(kValues.length)];

  List<String> _buildDeck() {
    final d = <String>[];
    for (final row in kDeckList) {
      final id = row[0] as String;
      final qty = row[1] as int;
      for (var i = 0; i < qty; i++) {
        d.add(id);
      }
    }
    d.shuffle(_rng);
    return d;
  }

  void newGame() {
    final names = playerNames;
    players = List.generate(
      4,
      (i) => Player(
        id: i,
        name: names[i],
        human: humanPlayerIds.contains(i),
        red: _drawValue(),
        blue: _drawValue(),
      ),
    );
    deck = _buildDeck();
    logs.clear();
    knowledge.clear();
    burnTokens.clear();
    winner = null;
    statusMessage = null;
    busy = false;
    choice = null;
    turn = 0;

    for (final p in players) {
      for (var i = 0; i < rules.initialHandSize; i++) {
        _drawCard(p, quiet: true);
      }
    }
    _log(
      'Empieza la partida (${rules.label}). La puerta sigue cerrada. Buscá el 6 y el 7.',
      loud: true,
    );
    _startTurn(0);
  }

  void _log(String text, {bool loud = false}) {
    logs.add(LogEntry(text, loud: loud));
    if (logs.length > 80) logs.removeAt(0);
  }

  void _drawCard(Player p, {bool quiet = false}) {
    if (deck.isEmpty) deck = _buildDeck();
    if (p.hand.length >= rules.maxHandSize) return;
    p.hand.add(deck.removeLast());
    if (!quiet) _emit(const Fx(FxKind.draw));
  }

  // ----------------------------------------------------------- efectos ------

  void _bump(Player p, CardColor c, int n) {
    p.setValue(c, p.value(c) + n);
    _checkBurn(p, c);
  }

  void _assign(Player p, CardColor c, int v) {
    p.setValue(c, v);
    _checkBurn(p, c);
  }

  void _checkBurn(Player p, CardColor c) {
    final v = p.value(c);
    if (v > 13 || v < 0) {
      if (rules.softBurn) {
        final clamped = v.clamp(0, 13);
        p.setValue(c, clamped);
        _log(
          '${p.name} rozó el límite: ${colorName(c)} queda en $clamped.',
          loud: true,
        );
      } else {
        p.setValue(c, _drawValue());
        final key = '${p.id}-${c.index}';
        burnTokens[key] = (burnTokens[key] ?? 0) + 1;
        _log('${p.name} se quemó la ${colorName(c)} y robó una nueva.',
            loud: true);
        _emit(Fx(FxKind.burn, playerId: p.id, color: c));
      }
    }
  }

  // ------------------------------------------------------------ elección ----

  Future<Object?> ask({
    required String title,
    String desc = '',
    required List<ChoiceOption> options,
    double? seconds,
    int playerId = 0,
  }) {
    final c = Completer<Object?>();
    choice = ChoiceRequest(
      title: title,
      desc: desc,
      options: options,
      completer: c,
      seconds: seconds,
      playerId: playerId,
    );
    _touch();
    if (seconds != null) {
      Timer(Duration(milliseconds: (seconds * 1000).round()), () {
        if (choice != null && choice!.completer == c && !c.isCompleted) {
          choice = null;
          c.complete(null);
          _touch();
        }
      });
    }
    return c.future;
  }

  void answer(Object? value) {
    final c = choice;
    if (c == null) return;
    choice = null;
    _touch();
    if (!c.completer.isCompleted) c.completer.complete(value);
  }

  void cancelChoice() => answer(null);

  /// Junta los objetivos que la carta necesita preguntándole al jugador.
  Future<Targets?> collectTargets(String cardId, Player actor) async {
    final card = kCards[cardId]!;
    final q = Targets();
    for (final need in card.needs) {
      if (need == Need.own || need == Need.color) {
        final r = await ask(
          title: '${card.name}: elegí una carta tuya',
          desc: card.desc,
          options: [
            ChoiceOption('Roja · ${actor.red}', CardColor.red,
                tint: CardColor.red),
            ChoiceOption('Azul · ${actor.blue}', CardColor.blue,
                tint: CardColor.blue),
          ],
        );
        if (r == null) return null;
        if (need == Need.own) {
          q.own = r as CardColor;
        } else {
          q.color = r as CardColor;
        }
      } else {
        final r = await ask(
          title: '${card.name}: elegí un rival',
          desc: card.desc,
          options:
              foesOf(actor.id).map((f) => ChoiceOption(f.name, f.id)).toList(),
        );
        if (r == null) return null;
        q.foe = r as int;

        if (need == Need.foeCard) {
          final f = players[q.foe!];
          String tag(CardColor c) =>
              seesCard(f.id, c) ? ' · ${f.value(c)}' : ' · ?';
          final r2 = await ask(
            title: '${card.name}: ¿qué carta de ${f.name}?',
            desc: card.desc,
            options: [
              ChoiceOption('Roja${tag(CardColor.red)}', CardColor.red,
                  tint: CardColor.red),
              ChoiceOption('Azul${tag(CardColor.blue)}', CardColor.blue,
                  tint: CardColor.blue),
            ],
          );
          if (r2 == null) return null;
          q.foeColor = r2 as CardColor;
        }
      }
    }
    return q;
  }

  // ----------------------------------------------------------- reacción -----

  Future<String?> _reactionWindow(int actorId, ReactKind kind,
      {String cardName = ''}) async {
    for (final p in _othersFrom(actorId)) {
      if (_dead) continue;
      final opts = p.hand
          .toSet()
          .where((k) => kCards[k]!.react == kind && kCards[k]!.cost <= p.mana)
          .toList();
      if (opts.isEmpty) continue;

      String? chosen;
      if (p.human) {
        final list = <ChoiceOption>[
          for (final k in opts)
            ChoiceOption('${kCards[k]!.name} · ${kCards[k]!.cost} lucidez', k),
          const ChoiceOption('Dejar pasar', null),
        ];
        final r = await ask(
          playerId: p.id,
          title: kind == ReactKind.sing
              ? '${players[actorId].name} intenta recordar'
              : '${players[actorId].name} juega $cardName',
          desc: kind == ReactKind.sing
              ? 'Última chance de frenarlo.'
              : 'Podés cancelarla antes de que se resuelva.',
          options: list,
          seconds: rules.reactionSeconds,
        );
        chosen = r as String?;
      } else {
        final blockChance = kind == ReactKind.sing ? 0.45 : 0.35;
        if (_rng.nextDouble() < blockChance) {
          if (kind == ReactKind.sing) {
            chosen = opts.contains('desmentir') ? 'desmentir' : opts.first;
          } else {
            chosen = opts.first;
          }
        }
      }

      if (chosen != null) {
        p.mana -= kCards[chosen]!.cost;
        p.hand.remove(chosen);
        _log('${p.name} responde con ${kCards[chosen]!.name}.', loud: true);
        _emit(Fx(FxKind.block, playerId: p.id, actorName: p.name));
        return chosen;
      }
    }
    return null;
  }

  // -------------------------------------------------------------- jugar -----

  Future<void> playCard(Player actor, String cardId, Targets? q) async {
    final card = kCards[cardId]!;
    if (actor.free > 0) {
      actor.free--;
    } else {
      actor.mana -= card.cost;
    }
    actor.hand.remove(cardId);

    busy = true;
    _emit(Fx(FxKind.play, cardId: cardId, actorName: actor.name));
    _touch();
    await _wait(140);

    final blocked =
        await _reactionWindow(actor.id, ReactKind.card, cardName: card.name);

    if (blocked != null) {
      _log('${card.name} de ${actor.name} queda cancelada.');
      if (blocked == 'congelar') {
        actor.frozen = true;
        _log('${actor.name} queda congelado por este turno.');
      }
    } else {
      _log('${actor.name} jugó ${card.name}.');
      card.effect?.call(_Ctx(this, actor, q ?? Targets()));
    }

    busy = false;
    _touch();
  }

  Future<bool> humanPlay(int handIndex) async {
    if (!myTurn) return false;
    final p = me;
    if (handIndex < 0 || handIndex >= p.hand.length) return false;
    final cardId = p.hand[handIndex];
    final card = kCards[cardId]!;
    if (card.isReaction || p.frozen) return false;
    final cost = p.free > 0 ? 0 : card.cost;
    if (cost > p.mana) return false;

    final q = await collectTargets(cardId, p);
    if (q == null) return false;
    await playCard(p, cardId, q);
    if (p.endNow) await endTurn();
    return true;
  }

  // -------------------------------------------------------------- cantar ----

  Future<bool> sing(int id) async {
    final p = players[id];
    if (winner != null || !canSing(id)) return false;
    final genuine = p.isWin;

    busy = true;
    _log('${p.name} canta ¡Lo recuerdo!', loud: true);
    _emit(Fx(FxKind.sing, playerId: id, actorName: p.name));
    _touch();
    await _wait(500);

    final stop = await _reactionWindow(id, ReactKind.sing);
    if (stop != null) {
      final penalty = genuine ? 1 : 2;
      _log(
        genuine
            ? 'El canto de ${p.name} queda anulado. Suma $penalty a su roja.'
            : 'Desmienten el farol de ${p.name}. Suma $penalty a su roja.',
        loud: true,
      );
      _emit(Fx(FxKind.deny, playerId: id));
      _bump(p, CardColor.red, penalty);
      busy = false;
      _touch();
      return false;
    }

    if (!genuine) {
      _log('Nadie desmintió: ${p.name} gana con el farol.', loud: true);
    }
    winner = p.name;
    busy = false;
    _emit(Fx(p.human ? FxKind.win : FxKind.lose, playerId: id));
    _touch();
    return true;
  }

  // --------------------------------------------------------------- turnos ---

  void _startTurn(int i) {
    if (_dead || winner != null) return;
    turn = i;
    final p = players[i];
    p.mana = p.pending > 0 ? p.pending : rules.manaPerTurn;
    p.pending = 0;
    p.free = 0;
    p.overload = false;
    p.endNow = false;
    p.frozen = false;
    _drawCard(p);
    _log('— Turno de ${p.name} —');
    _emit(Fx(FxKind.turn, playerId: i));
    _touch();
    if (!p.human) {
      unawaited(_botTurn(i));
    }
  }

  Future<void> endTurn() async {
    if (_dead || winner != null) return;
    final p = current;
    if (p.overload) {
      final r = _rng.nextInt(6);
      _log('${p.name} paga Sobrecarga: +$r a su roja.', loud: true);
      _bump(p, CardColor.red, r);
      p.overload = false;
      _touch();
      await _wait(600);
    }
    if (winner != null) return;
    _startTurn((turn + 1) % players.length);
  }

  Future<void> _wait(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  // ------------------------------------------------------------------ IA ----

  Future<void> _botTurn(int i) async {
    final p = players[i];
    await _wait(750);
    for (var step = 0; step < 4; step++) {
      if (_dead || winner != null) return;
      if (canSing(i)) {
        if (p.isWin || (rules.allowBluffSing && _rng.nextDouble() < 0.2)) {
          if (await sing(i)) return;
        }
      }
      if (p.frozen || p.endNow) break;
      final mv = _bestMove(p);
      if (mv == null) break;
      await playCard(p, mv.key, mv.targets);
      if (_dead || winner != null) return;
      await _wait(700);
    }
    if (!_dead && winner == null && canSing(i) && p.isWin) {
      if (await sing(i)) return;
    }
    if (!_dead && winner == null) await endTurn();
  }

  /// Los bots ven sus propias cartas pero no las de nadie más, igual que vos.
  /// Por eso simulan sólo las cartas que se aplican sobre sí mismos, y cuando
  /// atacan eligen objetivo a ciegas.
  _Move? _bestMove(Player p) {
    final cur = p.distance.toDouble();
    _Move? best;

    void consider(String key, Targets q, double score) {
      if (best == null || score < best!.score) best = _Move(key, q, score);
    }

    for (final key in p.hand.toSet()) {
      final card = kCards[key]!;
      if (card.isReaction) continue;
      final cost = p.free > 0 ? 0 : card.cost;
      if (cost > p.mana) continue;

      if (key == 'sobrecarga') {
        if (p.mana <= 1 && cur > 2) consider(key, Targets(), cur - 0.3);
      } else if (key == 'dobleJugada') {
        if (p.mana <= 1 && cur > 3) {
          consider(key, Targets(own: _randomColor()), cur - 0.2);
        }
      } else if (key == 'respiro') {
        if (p.mana == 0) consider(key, Targets(), cur - 0.1);
      } else if (card.blind) {
        consider(key, _randomTargets(p, card), cur - 0.25);
      } else {
        for (final q in _enumerateOwn(card)) {
          final s = _simulate(p, key, q);
          if (s < 90) consider(key, q, s);
        }
      }
    }

    final chosen = best;
    if (chosen == null) return null;
    if (chosen.score >= cur && cur > 0) {
      const utility = {'sobrecarga', 'dobleJugada', 'respiro'};
      if (!utility.contains(chosen.key)) return null;
    }
    return chosen;
  }

  CardColor _randomColor() => _rng.nextBool() ? CardColor.red : CardColor.blue;

  Targets _randomTargets(Player p, ActionCard card) {
    final q = Targets();
    if (card.needs.contains(Need.own)) q.own = _pickBestOwn(p);
    if (card.needs.contains(Need.color)) q.color = _randomColor();
    q.foe = _pickFoe(p);
    if (card.needs.contains(Need.foeCard)) {
      q.foeColor = _pickFoeColor(players[q.foe!], p);
    }
    return q;
  }

  /// Hidden rival values must not influence bot targeting.
  int _pickFoe(Player p) {
    final foes = foesOf(p.id);
    return foes[_rng.nextInt(foes.length)].id;
  }

  CardColor _pickFoeColor(Player foe, Player self) => _randomColor();

  /// Para cartas que también tocan una carta propia, el bot al menos elige la
  /// suya con criterio aunque el objetivo rival sea a ciegas.
  CardColor _pickBestOwn(Player p) {
    final target = (p.red - 6).abs() + (p.blue - 7).abs() <=
            (p.red - 7).abs() + (p.blue - 6).abs()
        ? [6, 7]
        : [7, 6];
    return (p.red - target[0]).abs() >= (p.blue - target[1]).abs()
        ? CardColor.red
        : CardColor.blue;
  }

  List<Targets> _enumerateOwn(ActionCard card) {
    if (card.needs.isEmpty) return [Targets()];
    final out = <Targets>[];
    for (final c in CardColor.values) {
      final q = Targets();
      if (card.needs.contains(Need.own)) q.own = c;
      if (card.needs.contains(Need.color)) q.color = c;
      out.add(q);
    }
    return out;
  }

  double _simulate(Player p, String key, Targets q) {
    final clone = Player(
        id: p.id, name: p.name, human: p.human, red: p.red, blue: p.blue);
    final ctx = _SimCtx(clone, q, rules);
    try {
      kCards[key]!.effect?.call(ctx);
    } catch (_) {
      return 99;
    }
    if (ctx.burned) return 99;
    return clone.distance.toDouble();
  }
}

/// Contexto real: aplica los efectos sobre la partida en curso.
class _Ctx implements EffectCtx {
  final GameEngine e;
  final Player _self;
  final Targets _q;

  _Ctx(this.e, this._self, this._q);

  @override
  List<Player> get players => e.players;
  @override
  Player get self => _self;
  @override
  Targets get q => _q;

  @override
  void bump(Player p, CardColor c, int n) => e._bump(p, c, n);
  @override
  void assign(Player p, CardColor c, int v) => e._assign(p, c, v);
  @override
  int roll(int max) => e._rng.nextInt(max);
  @override
  void log(String text) => e._log(text);

  @override
  void reveal(Player p, CardColor c) {
    if (_self.human) {
      e.knowledge.putIfAbsent(_self.id, () => {}).add('${p.id}-${c.index}');
      e._log('${_self.name} mira la ${colorName(c)} de ${p.name}.', loud: true);
    } else {
      e._log('${_self.name} ojea una carta de ${p.name}.');
    }
  }
}

/// Contexto de simulación para los bots: sólo toca el clon y marca si se
/// hubiera quemado, sin escribir en el log ni tocar la partida.
class _SimCtx implements EffectCtx {
  final Player clone;
  final Targets _q;
  final GameRules rules;
  bool burned = false;

  _SimCtx(this.clone, this._q, this.rules);

  @override
  List<Player> get players => [clone];
  @override
  Player get self => clone;
  @override
  Targets get q => _q;

  void _check(CardColor c) {
    var v = clone.value(c);
    if (v > 13 || v < 0) {
      if (rules.softBurn) {
        clone.setValue(c, v.clamp(0, 13));
      } else {
        burned = true;
      }
    }
  }

  @override
  void bump(Player p, CardColor c, int n) {
    p.setValue(c, p.value(c) + n);
    _check(c);
  }

  @override
  void assign(Player p, CardColor c, int v) {
    p.setValue(c, v);
    _check(c);
  }

  @override
  void reveal(Player p, CardColor c) {}
  @override
  int roll(int max) => max ~/ 2;
  @override
  void log(String text) {}
}
