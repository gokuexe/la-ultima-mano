import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../engine.dart';
import '../dialogue.dart';
import 'dialogue_box.dart';
import '../game_config.dart';
import '../model.dart';
import '../sfx.dart';
import '../theme.dart';
import '../story.dart';
import 'number_card.dart';
import 'overlays.dart';
import 'pieces.dart';
import 'pile.dart';

class GameScreen extends StatefulWidget {
  final GameRules rules;
  final GameEngine? session;

  const GameScreen({super.key, this.rules = const GameRules(), this.session});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late final GameEngine engine =
      widget.session ?? GameEngine(rules: widget.rules);

  final List<PlayedEntry> _pile = [];
  int _seq = 0;
  final DialogueDirector _dialogue = DialogueDirector();
  DialogueLine _line = DialogueDirector.opening;
  final ScrollController _handScroll = ScrollController();

  late final AnimationController _singFlash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  String _singActor = '';

  @override
  void initState() {
    super.initState();
    engine.onFx = _handleFx;
    engine.addListener(_onEngine);
    Sfx.i.init();
  }

  void _onEngine() {
    if (mounted) setState(() {});
  }

  void _handleFx(Fx fx) {
    final actor = fx.actorName ??
        (fx.playerId == null ? '' : engine.players[fx.playerId!].name);
    final line = _dialogue.react(fx, widget.session == null ? actor : '');
    if (line != null && mounted) setState(() => _line = line);
    switch (fx.kind) {
      case FxKind.play:
        final id = fx.cardId;
        if (id != null) {
          setState(() {
            _pile.add(PlayedEntry.scattered(_seq++, id, fx.actorName ?? ''));
            if (_pile.length > 12) _pile.removeAt(0);
          });
        }
        Sfx.i.play('play');
        Sfx.i.tap();
        break;
      case FxKind.draw:
        Sfx.i.play('draw', volume: 0.5);
        break;
      case FxKind.mana:
        Sfx.i.play('mana', volume: 0.6);
        break;
      case FxKind.burn:
        Sfx.i.play('burn');
        if (fx.playerId == 0) Sfx.i.heavy();
        break;
      case FxKind.block:
        // Denying an escape does not cancel the previous card on the table.
        if (_pile.isNotEmpty && fx.cardId != 'desmentir') {
          setState(() => _pile.last.blocked = true);
        }
        Sfx.i.play('block');
        Sfx.i.thump();
        break;
      case FxKind.sing:
        setState(() => _singActor = fx.actorName ?? '');
        _singFlash.forward(from: 0);
        Sfx.i.play('sing');
        Sfx.i.thump();
        break;
      case FxKind.deny:
        Sfx.i.play('deny');
        Sfx.i.heavy();
        break;
      case FxKind.win:
        Sfx.i.play('win');
        Sfx.i.heavy();
        break;
      case FxKind.lose:
        Sfx.i.play('lose');
        break;
      case FxKind.turn:
        if (fx.playerId == 0) {
          Sfx.i.play('turn', volume: 0.5);
          Sfx.i.play('mana', volume: 0.35);
        }
        break;
    }
  }

  @override
  void dispose() {
    engine.removeListener(_onEngine);
    engine.onFx = null;
    engine.dispose();
    _singFlash.dispose();
    _handScroll.dispose();
    super.dispose();
  }

  void _restart() {
    if (widget.session != null) {
      Navigator.of(context).pop();
      return;
    }
    Sfx.i.tap();
    setState(() {
      _pile.clear();
      _seq = 0;
      _line = DialogueDirector.opening;
    });
    engine.newGame();
  }

  @override
  Widget build(BuildContext context) {
    final me = engine.me;
    final myTurn = engine.myTurn;

    return Scaffold(
      body: Container(
        decoration: SS.tableBg(),
        child: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: Center(
                    child: SizedBox(
                      width: constraints.maxWidth.clamp(0.0, 1000.0),
                      height: constraints.maxHeight < 1000
                          ? 1000
                          : constraints.maxHeight,
                      child: _table(me, myTurn),
                    ),
                  ),
                ),
              ),
              SingFlash(anim: _singFlash, actor: _singActor),
              if (engine.choice != null)
                ChoiceOverlay(
                  key: ValueKey(engine.choice),
                  request: engine.choice!,
                  onPick: engine.answer,
                ),
              if (engine.winner != null)
                EndOverlay(
                  winner: engine.winner!,
                  youWon: engine.winner == engine.me.name,
                  onAgain: _restart,
                  againLabel: widget.session == null
                      ? 'Volver a despertar'
                      : 'Salir de la sala',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _table(Player me, bool myTurn) {
    return Padding(
      // el margen inferior queda generoso a propósito: en
      // Windows maximizado no hay garantía de que el borde de la
      // ventana sea clickeable hasta el último píxel
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: 10),
          _rivals(),
          const SizedBox(height: 8),
          DialogueBox(line: _line),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: PlayedPile(entries: _pile)),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: LogView(entries: engine.logs)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _myCards(me),
          const SizedBox(height: 8),
          _status(me),
          const SizedBox(height: 8),
          _hand(me, myTurn),
          const SizedBox(height: 8),
          _buttons(me, myTurn),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(Story.title, style: SS.title),
              const SizedBox(height: 2),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  engine.winner != null
                      ? 'Partida terminada'
                      : engine.statusMessage ??
                          'Turno de ${engine.current.name}',
                  key: ValueKey('${engine.turn}-${engine.winner}'),
                  style: SS.sub.copyWith(
                    color: engine.myTurn ? SS.win : SS.mute,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text('Modo ${engine.rules.label}', style: SS.sub),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Salir de la mesa',
          icon: const Icon(Icons.exit_to_app, color: SS.mute, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        IconButton(
          onPressed: () => setState(() => Sfx.i.muted = !Sfx.i.muted),
          icon: Icon(
            Sfx.i.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: SS.mute,
            size: 21,
          ),
          tooltip: Sfx.i.muted ? 'Activar sonido' : 'Silenciar',
        ),
      ],
    );
  }

  Widget _rivals() {
    final foes = engine.foesOf(0);
    return Row(
      children: [
        for (var i = 0; i < foes.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: RivalPanel(
              player: foes[i],
              active: engine.turn == foes[i].id,
              seesRed: engine.seesCard(foes[i].id, CardColor.red),
              seesBlue: engine.seesCard(foes[i].id, CardColor.blue),
            ),
          ),
        ],
      ],
    );
  }

  Widget _myCards(Player me) {
    return Row(
      children: [
        Expanded(
          child: NumberCard(
            isRed: true,
            value: me.red,
            win: me.isWin,
            burnToken: engine.burnTokens['0-${CardColor.red.index}'] ?? 0,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: NumberCard(
            isRed: false,
            value: me.blue,
            win: me.isWin,
            burnToken: engine.burnTokens['0-${CardColor.blue.index}'] ?? 0,
          ),
        ),
      ],
    );
  }

  Widget _status(Player me) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text('Lucidez ', style: SS.sub),
            ManaPips(value: me.mana, max: 7),
            const SizedBox(width: 8),
            Text(
              me.free > 0 ? '${me.mana} · ${me.free} gratis' : '${me.mana}',
              style: SS.sub,
            ),
          ],
        ),
        Text(
          me.isWin ? 'lo recordás' : 'distancia: ${me.distance}',
          style: SS.sub.copyWith(color: me.isWin ? SS.win : SS.mute),
        ),
      ],
    );
  }

  /// En Windows/desktop una lista horizontal no responde ni a la rueda del
  /// mouse ni al arrastre por defecto: sin esto, las cartas que no entran en
  /// pantalla quedan inalcanzables. Este listener traduce la rueda vertical
  /// en desplazamiento horizontal.
  void _onHandWheel(PointerSignalEvent event) {
    if (event is PointerScrollEvent && _handScroll.hasClients) {
      final delta = event.scrollDelta.dy.abs() > event.scrollDelta.dx.abs()
          ? event.scrollDelta.dy
          : event.scrollDelta.dx;
      _handScroll.jumpTo(
        (_handScroll.offset + delta).clamp(
          0.0,
          _handScroll.position.maxScrollExtent,
        ),
      );
    }
  }

  Widget _hand(Player me, bool myTurn) {
    return SizedBox(
      height: 326,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DeckStack(count: engine.deck.length),
          const SizedBox(width: 10),
          Expanded(
            child: Listener(
              onPointerSignal: _onHandWheel,
              child: ScrollConfiguration(
                behavior: _DragAnywhereScrollBehavior(),
                child: Scrollbar(
                  controller: _handScroll,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: ListView.separated(
                    controller: _handScroll,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 14),
                    itemCount: me.hand.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final card = kCards[me.hand[i]]!;
                      final cost = me.free > 0 ? 0 : card.cost;
                      final enabled = myTurn &&
                          !me.frozen &&
                          !card.isReaction &&
                          cost <= me.mana;
                      return HandCard(
                        card: card,
                        enabled: enabled,
                        onTap: () => engine.humanPlay(i),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buttons(Player me, bool myTurn) {
    final canSing = myTurn && engine.canSing(0);
    final bluffOnly = canSing && !me.isWin;
    return Row(
      children: [
        Expanded(
          child: _Btn(
            label: bluffOnly ? 'Fingir recordar' : 'Intentar salir',
            enabled: canSing,
            filled: true,
            onTap: () {
              Sfx.i.tap();
              engine.sing(0);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Btn(
            label: 'Ceder la palabra',
            enabled: myTurn,
            onTap: () {
              Sfx.i.tap();
              engine.endTurn();
            },
          ),
        ),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool filled;
  final VoidCallback onTap;

  const _Btn({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && filled;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? SS.win : SS.surface,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: active ? SS.win : SS.line),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: SS.win.withValues(alpha: 0.4),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? const Color(0xFF0D2419) : SS.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Por default Flutter solo deja arrastrar listas con el dedo; en el
/// ejecutable de Windows no hay dedo, así que sin esto la mano quedaría
/// atrapada detrás del borde de la ventana.
class _DragAnywhereScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}
