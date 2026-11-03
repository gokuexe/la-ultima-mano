import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:game_core/engine.dart';
import 'package:game_core/game_config.dart';
import 'package:game_core/model.dart';

/// Authoritative room server. Private state is projected per connection.
typedef GameFactory = GameEngine Function(
    GameRules rules, Set<int> humanPlayerIds, List<String> playerNames);

class RoomServer {
  final GameFactory _createGame;
  final Duration reconnectGrace;

  RoomServer(
      {GameFactory? createGame,
      this.reconnectGrace = const Duration(seconds: 60)})
      : _createGame = createGame ?? _defaultGame;

  static GameEngine _defaultGame(
          GameRules rules, Set<int> humans, List<String> names) =>
      GameEngine(rules: rules, humanPlayerIds: humans, playerNames: names);

  final _random = Random.secure();
  final Map<String, _Room> _rooms = {};
  final Set<_Peer> _peers = {};
  HttpServer? _http;
  Future<void>? _closing;
  int get port => _http!.port;

  Future<void> start({String host = '127.0.0.1', int port = 8080}) async {
    _http = await HttpServer.bind(host, port);
    _http!.listen((request) async {
      if (_closing != null) {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
      } else if (request.uri.path == '/health') {
        request.response.write('ok');
        await request.response.close();
      } else if (request.uri.path == '/ws' &&
          WebSocketTransformer.isUpgradeRequest(request) &&
          _peers.length < 200) {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.pingInterval = const Duration(seconds: 20);
        final peer = _Peer(socket);
        _peers.add(peer);
        socket.listen((raw) {
          if (raw is! String || raw.length > 4096) {
            socket.close(1009);
            return;
          }
          final now = DateTime.now();
          if (now.difference(peer.window).inSeconds >= 1) {
            peer.window = now;
            peer.messages = 0;
          }
          if (++peer.messages > 20) {
            socket.close(1008);
            return;
          }
          unawaited(_receive(peer, raw));
        }, onDone: () => _leave(peer), onError: (_) => _leave(peer));
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    });
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    final peers = List.of(_peers);
    for (final room in _rooms.values) {
      room.game?.dispose();
      for (final peer in room.peers.values) {
        peer.expiry?.cancel();
      }
      room.peers.clear();
    }
    _rooms.clear();
    _peers.clear();
    for (final peer in peers) {
      peer.room = null;
      peer.send({
        'type': 'closed',
        'message':
            'El servidor se está reiniciando. Volvé a entrar en un momento.'
      });
    }
    await Future.wait(peers.map((peer) async {
      try {
        await peer.socket
            .close(1001, 'Server shutdown')
            .timeout(const Duration(seconds: 3));
      } on TimeoutException {
        // Bound shutdown time when a peer has already lost its network.
      } on SocketException {
        // The peer may have disappeared during shutdown.
      }
    }));
    await _http?.close(force: true);
  }

  Future<void> _receive(_Peer peer, String raw) async {
    try {
      final message = jsonDecode(raw) as Map<String, dynamic>;
      final action = message['type'];
      if (action == 'resume' && peer.room == null) {
        final room = _rooms[message['code']];
        final token = message['token'];
        final matches = room?.peers.values
            .where((p) => token is String && p.token == token);
        if (room == null || matches == null || matches.isEmpty) {
          throw const FormatException(
              'La reserva de tu asiento terminó. Creá otra sala.');
        }
        final previous = matches.first;
        previous.expiry?.cancel();
        peer.name = previous.name;
        peer.seat = previous.seat;
        peer.token = previous.token;
        peer.room = room;
        room.peers[peer.seat] = peer;
        previous.room = null;
        _peers.remove(previous);
        unawaited(previous.socket.close());
        _session(peer);
        room.game?.setPaused(room.peers.values.any((p) => p.expiry != null));
        _broadcast(room);
        return;
      }
      if (action == 'leave') {
        _finishLeave(peer);
        return;
      }
      if (peer.room == null) {
        final name = (message['name'] as String? ?? '').trim();
        if (name.isEmpty || name.length > 20 || name.runes.any((c) => c < 32)) {
          throw const FormatException('Elegí un nombre de 1 a 20 caracteres.');
        }
        _Room room;
        if (action == 'create') {
          if (_rooms.length >= 100) {
            throw const FormatException('El servidor está lleno.');
          }
          String code;
          const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
          do {
            code = List.generate(
                6, (_) => alphabet[_random.nextInt(alphabet.length)]).join();
          } while (_rooms.containsKey(code));
          final mode = message['mode'] as int? ?? 0;
          if (mode < 0 || mode >= GameMode.values.length) {
            throw const FormatException('Modo inválido.');
          }
          room = _Room(code, GameRules(GameMode.values[mode]));
          _rooms[code] = room;
        } else if (action == 'join') {
          final code = (message['code'] as String? ?? '').trim().toUpperCase();
          final existing = _rooms[code];
          if (existing == null ||
              existing.game != null ||
              existing.peers.length >= 4) {
            throw const FormatException('Sala no disponible.');
          }
          room = existing;
        } else {
          throw const FormatException('Creá una sala o ingresá un código.');
        }
        if (room.peers.values
            .any((p) => p.name.toLowerCase() == name.toLowerCase())) {
          throw const FormatException('Ese nombre ya está en la sala.');
        }
        peer.token =
            base64Url.encode(List.generate(32, (_) => _random.nextInt(256)));
        peer.name = name;
        peer.seat = List.generate(4, (i) => i)
            .firstWhere((i) => !room.peers.containsKey(i));
        peer.room = room;
        room.peers[peer.seat] = peer;
        _session(peer);
        _broadcast(room);
        return;
      }
      final room = peer.room!;
      if (room.peers.values.any((p) => p.expiry != null)) {
        throw const FormatException(
            'Esperando a que vuelva una persona a la mesa.');
      }
      if (action == 'rematch') {
        if (room.game?.winner == null || room.commandPending) {
          throw const FormatException(
              'La revancha se decide al terminar la partida.');
        }
        room.rematchVotes.add(peer.seat);
        if (room.rematchVotes.length == room.peers.length) {
          room.rematchVotes.clear();
          room.round++;
          room.game!.newGame();
        }
        _broadcast(room);
        return;
      }
      if (action == 'start') {
        if (peer.seat != 0 || room.game != null || room.peers.length < 2) {
          throw const FormatException(
              'Solo el anfitrión puede empezar, con al menos 2 personas.');
        }
        final names = List.generate(
            4,
            (i) =>
                room.peers[i]?.name ?? 'Eco sin nombre de la silla ${i + 1}');
        final game = _createGame(room.rules, room.peers.keys.toSet(), names);
        room.game = game;
        game.addListener(() => _broadcast(room));
        game.onFx = (fx) {
          for (final p in room.peers.values) {
            p.send({
              'type': 'fx',
              'kind': fx.kind.index,
              'player': fx.playerId,
              'color': fx.color?.index,
              'card': fx.cardId,
              'actor': fx.actorName
            });
          }
        };
        _broadcast(room);
        return;
      }
      final game = room.game;
      if (game == null) throw const FormatException('La partida no empezó.');
      if (action == 'answer') {
        final choice = game.choice;
        if (choice == null ||
            choice.playerId != peer.seat ||
            message['choice'] != room.choiceId ||
            !choice.options.any((o) => o.value == message['value'])) {
          throw const FormatException('Respuesta inválida o fuera de tiempo.');
        }
        game.answer(message['value']);
        return;
      }
      if (room.commandPending ||
          game.busy ||
          game.choice != null ||
          game.winner != null ||
          game.turn != peer.seat) {
        throw const FormatException('Esperá tu turno.');
      }
      final actor = game.players[peer.seat];
      // Validate every field before changing authoritative state.
      if (action == 'play') {
        final key = message['card'];
        final card = kCards[key];
        if (card == null ||
            !actor.hand.contains(key) ||
            card.isReaction ||
            actor.frozen ||
            (actor.free > 0 ? 0 : card.cost) > actor.mana) {
          throw const FormatException('No podés jugar esa carta.');
        }
        final targets = message['targets'] as Map<String, dynamic>? ?? {};
        CardColor? color(String key) {
          final value = targets[key];
          return value is int && value >= 0 && value < 2
              ? CardColor.values[value]
              : null;
        }

        final foe = targets['foe'];
        final q = Targets(
            own: color('own'),
            color: color('color'),
            foe: foe is int && foe >= 0 && foe < 4 && foe != peer.seat
                ? foe
                : null,
            foeColor: color('foeColor'));
        for (final need in card.needs) {
          if ((need == Need.own && q.own == null) ||
              (need == Need.color && q.color == null) ||
              (need == Need.foe && q.foe == null) ||
              (need == Need.foeCard && (q.foe == null || q.foeColor == null))) {
            throw const FormatException('Faltan objetivos válidos.');
          }
        }
        room.commandPending = true;
        try {
          await game.playCard(actor, key as String, q);
          if (actor.endNow) await game.endTurn();
        } finally {
          room.commandPending = false;
          _broadcast(room);
        }
      } else if (action == 'end') {
        room.commandPending = true;
        try {
          await game.endTurn();
        } finally {
          room.commandPending = false;
          _broadcast(room);
        }
      } else if (action == 'sing') {
        if (!game.canSing(peer.seat)) {
          throw const FormatException('Todavía no podés intentar salir.');
        }
        room.commandPending = true;
        try {
          await game.sing(peer.seat);
        } finally {
          room.commandPending = false;
          _broadcast(room);
        }
      } else {
        throw const FormatException('Acción desconocida.');
      }
    } on FormatException catch (e) {
      peer.send({'type': 'error', 'message': e.message});
      if (peer.room != null) _broadcast(peer.room!);
    } catch (_) {
      peer.send({'type': 'error', 'message': 'El mensaje no es válido.'});
    }
  }

  void _broadcast(_Room room) {
    final game = room.game;
    // A lobby has no engine yet. Keep that path separate from game state.
    if (game == null) {
      for (final peer in room.peers.values) {
        peer.send({
          'type': 'lobby',
          'code': room.code,
          'seat': peer.seat,
          'mode': room.rules.mode.index,
          'players': room.peers.values
              .map((p) => {
                    'name': p.name,
                    'seat': p.seat,
                    'connected': p.expiry == null
                  })
              .toList(),
        });
      }
      return;
    }
    if (!identical(room.lastChoice, game.choice)) {
      room.lastChoice = game.choice;
      room.choiceId++;
    }
    for (final peer in room.peers.values) {
      final choice = game.choice;
      peer.send({
        'type': 'state',
        'mode': game.rules.mode.index,
        'round': room.round,
        'rematchVotes': room.rematchVotes.toList(),
        'humanCount': room.peers.length,
        'seat': peer.seat,
        'turn': game.turn,
        'busy': game.busy || room.commandPending || game.paused,
        'paused': game.paused,
        'missing': room.peers.values
            .where((p) => p.expiry != null)
            .map((p) => p.name)
            .toList(),
        'winner': game.winner,
        'deckCount': game.deck.length,
        'players': game.players
            .map((p) => {
                  'id': p.id,
                  'name': p.name,
                  'mana': p.mana,
                  'free': p.free,
                  'frozen': p.frozen,
                  'red': game.seesCard(p.id, CardColor.red, viewerId: peer.seat)
                      ? p.red
                      : null,
                  'blue':
                      game.seesCard(p.id, CardColor.blue, viewerId: peer.seat)
                          ? p.blue
                          : null,
                  'hand': p.id == peer.seat ? p.hand : null,
                  'handCount': p.hand.length,
                })
            .toList(),
        'logs': game.logs.map((l) => {'text': l.text, 'loud': l.loud}).toList(),
        'choice': !game.paused && choice != null && choice.playerId == peer.seat
            ? {
                'id': room.choiceId,
                'title': choice.title,
                'desc': choice.desc,
                'seconds': choice.seconds == null
                    ? null
                    : choice.seconds! * choice.remaining,
                'options': choice.options
                    .map((o) => {'label': o.label, 'value': o.value})
                    .toList(),
              }
            : null,
      });
    }
  }

  void _session(_Peer peer) {
    peer.send(
        {'type': 'session', 'code': peer.room!.code, 'token': peer.token});
  }

  void _leave(_Peer peer) {
    if (!_peers.remove(peer)) return;
    final room = peer.room;
    if (room == null || !identical(room.peers[peer.seat], peer)) return;
    peer.expiry = Timer(reconnectGrace, () => _finishLeave(peer));
    room.game?.setPaused(true);
    _broadcast(room);
  }

  void _finishLeave(_Peer peer) {
    _peers.remove(peer);
    peer.expiry?.cancel();
    final room = peer.room;
    if (room == null || !identical(room.peers[peer.seat], peer)) return;
    room.peers.remove(peer.seat);
    peer.room = null;
    unawaited(peer.socket.close());
    if (room.game != null || peer.seat == 0 || room.peers.isEmpty) {
      _rooms.remove(room.code);
      room.game?.dispose();
      for (final other in room.peers.values) {
        other.expiry?.cancel();
        other.send({
          'type': 'closed',
          'message': 'La sala terminó porque una persona se desconectó o salió.'
        });
        unawaited(other.socket.close());
        other.room = null;
      }
      room.peers.clear();
    } else {
      _broadcast(room);
    }
  }
}

class _Peer {
  final WebSocket socket;
  _Room? room;
  String name = '';
  String token = '';
  Timer? expiry;
  int seat = -1;
  DateTime window = DateTime.now();
  int messages = 0;
  _Peer(this.socket);
  void send(Map<String, dynamic> message) {
    if (socket.readyState != WebSocket.open) return;
    try {
      socket.add(jsonEncode(message));
    } on StateError {/* The peer closed its sink before onDone arrived. */}
  }
}

class _Room {
  final String code;
  final GameRules rules;
  final Map<int, _Peer> peers = {};
  GameEngine? game;
  bool commandPending = false;
  ChoiceRequest? lastChoice;
  int choiceId = 0;
  int round = 1;
  final Set<int> rematchVotes = {};
  _Room(this.code, this.rules);
}
