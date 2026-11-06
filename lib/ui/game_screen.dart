import 'dart:async';
import '../l10n/game_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../engine.dart';
import '../online/online_connection.dart';
import '../play_preferences.dart';
import '../chapter.dart';
import '../story_progress.dart';
import '../portal/portal_ads.dart';
import 'options_screen.dart';
import '../dialogue.dart';
import '../habit_dialogue.dart';
import '../memory_fragments.dart';
import 'album_screen.dart';
import '../tension.dart';
import '../local_stage_hint.dart';
import 'tension_atmosphere.dart';
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
import 'pulse_strip.dart';
import '../collection_progress.dart';

class GameScreen extends StatefulWidget {
  final GameRules rules;
  final GameEngine? session;
  final MemoryPath? chapterMemory;

  const GameScreen(
      {super.key,
      this.rules = const GameRules.balanced(),
      this.session,
      this.chapterMemory});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late final GameEngine engine =
      widget.session ?? GameEngine(rules: widget.rules);

  final List<PlayedEntry> _pile = [];
  int _seq = 0;
  bool _rewarded = false;
  int _earnedPoints = 0;
  int _rewardGeneration = 0;
  MemoryFragment? _newMemory;
  final HabitDialogue _habits = HabitDialogue();
  final DialogueDirector _dialogue = DialogueDirector();
  final TensionDirector _tension = TensionDirector();
  bool _deviceTextVisible = false;
  int _hintSequence = 0;
  late DialogueLine _line = _dialogue.beginRound(1);
  final ScrollController _handScroll = ScrollController();

  late final AnimationController _singFlash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  String _singActor = '';

  @override
  void initState() {
    super.initState();
    engine.confirmHumanPlays = true;
    if (widget.chapterMemory != null) {
      _line = DialogueLine(
          'La habitación', ChapterOne.opening(widget.chapterMemory!));
    }
    if (engine is! RemoteGameEngine) PortalAds.instance.attach(engine);
    engine.onFx = _handleFx;
    engine.addListener(_onEngine);
    PlayPreferences.instance.addListener(_preferencesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onEngine();
    });
    CollectionProgress.instance.addListener(_collectionChanged);
    Sfx.i.init();
  }

  void _collectionChanged() {
    if (mounted) setState(() {});
  }

  void _preferencesChanged() {
    if ((!PlayPreferences.instance.deviceHints && _deviceTextVisible) ||
        (!PlayPreferences.instance.tension && _tension.level > 0)) {
      // Immediately remove any optional device text when the option is disabled.
      _line = DialogueDirector.opening;
      _deviceTextVisible = false;
    }
    if (!PlayPreferences.instance.tension) {
      if (_habits.holdsDialogue) _line = DialogueDirector.opening;
      _habits.reset();
    }
    _onEngine();
  }

  int _round = 1;
  void _onEngine() {
    final remote =
        engine is RemoteGameEngine ? engine as RemoteGameEngine : null;
    if (remote != null && remote.round != _round) {
      _round = remote.round;
      _rewarded = false;
      _earnedPoints = 0;
      _newMemory = null;
      _rewardGeneration++;
      _habits.reset();
      _pile.clear();
      _seq = 0;
      _line = _dialogue.beginRound(_round);
      _tension.reset();
      _singFlash.reset();
    }
    if (engine.winner != null && !_rewarded) {
      _rewarded = true;
      final won = engine.winner == engine.me.name;
      _earnedPoints = won ? 30 : 10;
      final generation = _rewardGeneration;
      unawaited(CollectionProgress.instance.awardMatch(won: won).then((memory) {
        if (mounted &&
            generation == _rewardGeneration &&
            engine.winner != null) {
          setState(() => _newMemory = memory);
        }
      }));
    }
    final cue = _tension.observe(
      distance: engine.me.distance,
      enabled: PlayPreferences.instance.tension,
      settled: !engine.busy && engine.choice == null && !engine.paused,
      finished: engine.winner != null,
      npcVoices: engine is! RemoteGameEngine,
      deviceHints: PlayPreferences.instance.deviceHints,
      readDeviceHint: (index) => localStageHint(
          _hintSequence++ + DateTime.now().minute,
          language: PlayPreferences.instance.language),
    );
    if (cue != null) {
      _line = cue;
      _deviceTextVisible = PlayPreferences.instance.deviceHints;
      Sfx.i.play('tension', volume: .36);
    }
    final habit = _habits.takeCue(
      allowed: PlayPreferences.instance.tension &&
          !_tension.holdsDialogue &&
          !engine.busy &&
          engine.choice == null &&
          !engine.paused &&
          engine.winner == null,
      npcVoices: engine is! RemoteGameEngine,
    );
    if (habit != null) {
      _line = habit;
      _deviceTextVisible = false;
    }
    if (mounted) setState(() {});
  }

  void _handleFx(Fx fx) {
    final actor = fx.actorName ??
        (fx.playerId == null ? '' : engine.players[fx.playerId!].name);
    final ownAction = fx.playerId == 0 ||
        (fx.playerId == null && fx.actorName == engine.me.name);
    if (ownAction && PlayPreferences.instance.tension) {
      if (fx.kind == FxKind.play && fx.cardId != null) {
        _habits.played(fx.cardId!);
      }
      if (fx.kind == FxKind.deny) _habits.escapeDenied();
    }
    final line =
        _dialogue.react(fx, actor, allowNpcVoice: widget.session == null);
    if (line != null &&
        mounted &&
        ((!_tension.holdsDialogue && !_habits.holdsDialogue) ||
            fx.kind == FxKind.win ||
            fx.kind == FxKind.lose ||
            fx.kind == FxKind.sing)) {
      _deviceTextVisible = false;
      setState(() => _line = line);
    }
    switch (fx.kind) {
      case FxKind.play:
        final id = fx.cardId;
        if (id != null) {
          setState(() {
            _pile.add(PlayedEntry.scattered(_seq++, id, fx.actorName ?? ''));
            if (_pile.length > 12) _pile.removeAt(0);
          });
        }
        final family = id == null ? null : engine.cards[id]?.family;
        Sfx.i.play(
            family == CardFamily.riesgo
                ? 'risk'
                : family == CardFamily.reaccion
                    ? 'reaction'
                    : 'memory',
            volume: .6);
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
        Sfx.i.play('reaction', volume: .65);
        Sfx.i.thump();
        break;
      case FxKind.sing:
        setState(() => _singActor = fx.actorName ?? '');
        if (!MediaQuery.disableAnimationsOf(context)) {
          _singFlash.forward(from: 0);
        }
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
      case FxKind.pulse:
        Sfx.i.play('anchor', volume: .6);
        if (!_tension.holdsDialogue && !_habits.holdsDialogue) {
          setState(() => _line = const DialogueLine(
              'La habitación', 'Un latido. El recuerdo vuelve a su sitio.'));
        }
        if (fx.playerId == 0) Sfx.i.tap();
        break;
      case FxKind.charge:
        if (fx.playerId == 0 && engine.me.pulse == 3) {
          Sfx.i.play('pulse_ready', volume: .55);
        }
        break;
      case FxKind.exchange:
        Sfx.i.play('exchange', volume: .5);
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
    PortalAds.instance.detach(engine);
    engine.removeListener(_onEngine);
    PlayPreferences.instance.removeListener(_preferencesChanged);
    CollectionProgress.instance.removeListener(_collectionChanged);
    engine.onFx = null;
    engine.dispose();
    _singFlash.dispose();
    _handScroll.dispose();
    super.dispose();
  }

  Future<void> _chooseCard(int index) async {
    final generation = _rewardGeneration;
    final played = await engine.humanPlay(index);
    if (mounted &&
        generation == _rewardGeneration &&
        !played &&
        engine.winner == null &&
        PlayPreferences.instance.tension) {
      _habits.cancelled();
      _onEngine();
    }
  }

  void _openAlbum() {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => AlbumScreen(focusId: _newMemory?.id)));
  }

  bool _allowPop = false;
  bool _exitDialogOpen = false;
  bool _leaving = false;

  Future<void> _leaveTable({bool home = false, bool? result}) async {
    if (_leaving) return;
    _leaving = true;
    if (home &&
        widget.chapterMemory != null &&
        engine.winner == engine.me.name) {
      await StoryProgress.instance.update(chapterComplete: true);
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (home) {
      navigator.popUntil((route) => route.isFirst);
    } else {
      navigator.pop(result);
    }
  }

  Future<void> _requestExit() async {
    if (_leaving || _exitDialogOpen) return;
    if (engine.winner != null) {
      await _leaveTable(home: true);
      return;
    }
    _exitDialogOpen = true;
    final pauseLocal = engine is! RemoteGameEngine && !engine.paused;
    if (pauseLocal) engine.setPaused(true);
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const GameText('¿Salir de la partida?'),
        content: GameText(engine is RemoteGameEngine
            ? 'Saldrás de la sala. La partida online sigue mientras decidís.'
            : 'La partida en curso no se guarda. ¿Querés salir?'),
        actions: [
          TextButton(
            key: const ValueKey('stay-in-game'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const GameText('SEGUIR JUGANDO'),
          ),
          TextButton(
            key: const ValueKey('confirm-exit-game'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const GameText('SALIR DE LA PARTIDA'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (!mounted) return;
    if (leave == true) {
      await _leaveTable();
    } else if (pauseLocal) {
      engine.setPaused(false);
    }
  }

  void _handleBack(bool didPop, Object? result) {
    if (didPop || _allowPop || _leaving) return;
    if (engine.choice != null && engine.choice!.seconds == null) {
      engine.cancelChoice();
    } else {
      _requestExit();
    }
  }

  bool _restarting = false;
  Future<void> _restart() async {
    if (_restarting || engine.winner == null) return;
    if (widget.chapterMemory != null) {
      await _leaveTable(result: engine.winner == engine.me.name);
      return;
    }
    if (engine is RemoteGameEngine) {
      (engine as RemoteGameEngine).requestRematch();
      return;
    }
    _restarting = true;
    _rewardGeneration++;
    Sfx.i.tap();
    await PortalAds.instance.requestBreak();
    if (!mounted) return;
    setState(() {
      _pile.clear();
      _seq = 0;
      _rewarded = false;
      _earnedPoints = 0;
      _newMemory = null;
      _habits.reset();
      _line = _dialogue.beginRound(1);
    });
    _tension.reset();
    engine.newGame();
    _restarting = false;
  }

  @override
  Widget build(BuildContext context) {
    final me = engine.me;
    final myTurn = engine.myTurn;

    return PopScope<Object?>(
        canPop: _allowPop,
        onPopInvokedWithResult: _handleBack,
        child: Scaffold(
          body: Container(
            decoration: SS.tableBg(),
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(child: _table(me, myTurn)),
                  Positioned.fill(
                      child: TensionAtmosphere(
                    level: engine.paused ||
                            engine.winner != null ||
                            !PlayPreferences.instance.tension
                        ? 0
                        : _tension.level,
                  )),
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
                      pointsEarned: _earnedPoints,
                      memoryTitle: _newMemory?.title,
                      onAlbum: _openAlbum,
                      youWon: engine.winner == engine.me.name,
                      onAgain: _restart,
                      againLabel: widget.chapterMemory != null
                          ? 'LEER DESENLACE'
                          : engine is RemoteGameEngine
                              ? (engine as RemoteGameEngine).votedRematch
                                  ? 'Esperando al resto…'
                                  : 'QUIERO REVANCHA'
                              : 'JUGAR OTRA PARTIDA',
                      againEnabled: !_restarting &&
                          (engine is! RemoteGameEngine ||
                              !(engine as RemoteGameEngine).votedRematch),
                      onExit: () => _leaveTable(home: true),
                      status: engine is RemoteGameEngine
                          ? engine.statusMessage ??
                              'Revancha: ${(engine as RemoteGameEngine).rematchCount}/${(engine as RemoteGameEngine).humanCount}'
                          : null,
                    ),
                ],
              ),
            ),
          ),
        ));
  }

  Widget _table(Player me, bool myTurn) {
    final urgentDialogue =
        (_tension.level > 0 && _tension.holdsDialogue) || _habits.holdsDialogue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('table-scroll'),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  const SizedBox(height: 12),
                  _rivals(),
                  const SizedBox(height: 12),
                  _myCards(me),
                  const SizedBox(height: 12),
                  _status(me),
                  if (engine.rules.isBalanced) ...[
                    const SizedBox(height: 4),
                    PulseStrip(engine: engine),
                  ],
                  const SizedBox(height: 12),
                  if (urgentDialogue) ...[
                    DialogueBox(line: _line),
                    const SizedBox(height: 12),
                  ],
                  _hand(me, myTurn),
                  const SizedBox(height: 12),
                  if (!urgentDialogue) DialogueBox(line: _line),
                  const SizedBox(height: 12),
                  SizedBox(
                      height: 200,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 3, child: PlayedPile(entries: _pile)),
                          const SizedBox(width: 8),
                          Expanded(
                              flex: 2, child: LogView(entries: engine.logs)),
                        ],
                      )),
                ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: _buttons(me, myTurn),
        ),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GameText(Story.title, style: SS.title),
              const SizedBox(height: 2),
              AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
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
                child: GameText(
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
              GameText(
                  'Modo ${engine.rules.label}${widget.chapterMemory == null ? '' : ' · Capítulo 01'}',
                  style: SS.sub),
              GameText(
                  engine.rules.isBalanced
                      ? 'EDICIÓN PULSO'
                      : 'REGLAS ORIGINALES',
                  style: SS.sub),
            ],
          ),
        ),
        IconButton(
          tooltip: context.tr('Salir de la mesa'),
          icon: const Icon(Icons.exit_to_app, color: SS.mute, size: 20),
          onPressed: _requestExit,
        ),
        IconButton(
          tooltip: context.tr('Ajustes y guía'),
          icon: const Icon(Icons.tune, color: SS.mute, size: 20),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => OptionsScreen(cards: engine.cards))),
        ),
        IconButton(
          onPressed: () =>
              PlayPreferences.instance.update(volume: Sfx.i.muted ? 1 : 0),
          icon: Icon(
            Sfx.i.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: SS.mute,
            size: 21,
          ),
          tooltip: context.tr(Sfx.i.muted ? 'Activar sonido' : 'Silenciar'),
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
              hostile: _tension.level > 0 && engine is! RemoteGameEngine,
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
            win: me.isWin && engine.winner == null,
            burnToken: engine.burnTokens['0-${CardColor.red.index}'] ?? 0,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: NumberCard(
            isRed: false,
            value: me.blue,
            win: me.isWin && engine.winner == null,
            burnToken: engine.burnTokens['0-${CardColor.blue.index}'] ?? 0,
          ),
        ),
      ],
    );
  }

  Widget _status(Player me) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        const GameText('Lucidez ', style: SS.sub),
        ManaPips(value: me.mana, max: 7),
        GameText(me.free > 0 ? '${me.mana} · ${me.free} gratis' : '${me.mana}',
            style: SS.sub),
        GameText(
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
      height: HandCard.heightFor(context) + 20,
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
                      final card = engine.cards[me.hand[i]]!;
                      final enabled = myTurn && engine.canPlayCard(me, card);
                      return HandCard(
                        card: card,
                        effectiveCost: me.free > 0 ? 0 : card.cost,
                        disabledReason: engine.rules.isBalanced &&
                                card.id == 'sobrecarga' &&
                                me.insomniaUsed
                            ? 'UN USO POR TURNO'
                            : null,
                        enabled: enabled,
                        onTap: () => _chooseCard(i),
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
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
          child: GameText(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
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
