import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../platform/connection_failure.dart';
import '../portal/portal_ads.dart';
import 'package:flutter/foundation.dart';
import '../engine.dart';
import '../game_config.dart';
import '../model.dart';
import 'server_endpoint.dart';
import 'server_readiness.dart';

class OnlineConnection extends ChangeNotifier {
  OnlineConnection() {
    PortalAds.instance.blockOnline(this);
  }
  WebSocketChannel? _socket;
  String? _endpoint;
  Map<String, dynamic>? _resumeRequest;
  bool _retrying = false;
  bool _terminal = false;
  RemoteGameEngine? game;
  String? error;
  Map<String, dynamic>? lobby;
  bool connected = false;
  String? connectionStatus;
  Completer<void>? _joining;
  bool _disposed = false;
  Future<void> connect(String endpoint, Map<String, dynamic> request) async {
    _endpoint = endpoint;
    final target = ServerEndpoint.parse(endpoint);
    if (target.secure && request['type'] != 'resume') {
      connectionStatus =
          'Despertando la habitación… puede tardar hasta un minuto.';
      notifyListeners();
      await waitForServer(target.health, cancelled: () => _disposed);
    }
    if (_disposed) return;
    connectionStatus = 'Conectando con la mesa…';
    notifyListeners();
    final socket = WebSocketChannel.connect(target.websocket);
    try {
      await socket.ready.timeout(const Duration(seconds: 12));
    } catch (_) {
      unawaited(socket.sink.close());
      throw const ConnectionFailure(
          'No se pudo abrir la conexión con el servidor.');
    }
    if (_disposed) {
      await socket.sink.close();
      return;
    }
    _socket = socket;
    connected = true;
    connectionStatus = null;
    socket.stream.listen((raw) {
      if (identical(_socket, socket)) _receive(raw);
    }, onDone: () {
      if (identical(_socket, socket)) {
        _lost('Se perdió la conexión con la sala.');
      }
    }, onError: (_) {
      if (identical(_socket, socket)) _lost('No se pudo mantener la conexión.');
    });
    connectionStatus = 'Esperando la confirmación de la sala…';
    final joining = Completer<void>();
    _joining = joining;
    send(request);
    notifyListeners();
    try {
      await joining.future.timeout(const Duration(seconds: 12));
    } catch (_) {
      connected = false;
      unawaited(socket.sink.close());
      rethrow;
    } finally {
      _joining = null;
      connectionStatus = null;
    }
  }

  void send(Map<String, dynamic> message) {
    if (_socket != null && connected) {
      try {
        _socket!.sink.add(jsonEncode(message));
      } on StateError {/* Socket is closing. */}
    }
  }

  void _receive(dynamic raw) {
    if (_disposed) return;
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      switch (data['type']) {
        case 'session':
          _resumeRequest = {
            'type': 'resume',
            'code': data['code'],
            'token': data['token']
          };
        case 'lobby':
          lobby = data;
          error = null;
          if (!(_joining?.isCompleted ?? true)) _joining!.complete();
        case 'state':
          if (!(_joining?.isCompleted ?? true)) _joining!.complete();
          game ??= RemoteGameEngine(
              this, GameRules(GameMode.values[data['mode'] as int]));
          game!.apply(data);
        case 'fx':
          game?.receiveFx(data);
        case 'error':
          error = data['message'] as String;
          if (!(_joining?.isCompleted ?? true)) {
            _joining!.completeError(FormatException(error!));
          }
          game?.showError(error!);
        case 'closed':
          _terminal = true;
          _resumeRequest = null;
          _lost(data['message'] as String);
      }
      notifyListeners();
    } catch (_) {
      _lost('El servidor envió una respuesta incompatible.');
    }
  }

  void _lost(String message) {
    if (_disposed || !connected) return;
    connected = false;
    if (!(_joining?.isCompleted ?? true)) {
      _joining!.completeError(ConnectionFailure(message));
    }
    error = message;
    unawaited(_socket?.sink.close() ?? Future<void>.value());
    game?.disconnected(message);
    notifyListeners();
    if (!_terminal &&
        _resumeRequest != null &&
        !_retrying &&
        _joining == null) {
      unawaited(_reconnect());
    }
  }

  Future<void> _reconnect() async {
    _retrying = true;
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (!_disposed && !_terminal && DateTime.now().isBefore(deadline)) {
      error = 'Intentando recuperar tu asiento…';
      game?.disconnected(error!);
      notifyListeners();
      try {
        await connect(_endpoint!, _resumeRequest!);
        if (_disposed) break;
        error = null;
        notifyListeners();
        _retrying = false;
        return;
      } on FormatException catch (e) {
        _terminal = true;
        error = e.message;
        break;
      } catch (_) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    _retrying = false;
    if (!_disposed) {
      error ??= 'No se pudo recuperar la sala. Volvé al menú para crear otra.';
      if (!_terminal) {
        error = 'No se pudo recuperar la sala. Volvé al menú para crear otra.';
      }
      game?.disconnected(error!);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    PortalAds.instance.unblockOnline(this);
    send({'type': 'leave'});
    _disposed = true;
    if (!(_joining?.isCompleted ?? true)) {
      _joining!.completeError(const ConnectionFailure('Conexión cancelada.'));
    }
    unawaited(_socket?.sink.close() ?? Future<void>.value());
    game?.dispose();
    super.dispose();
  }
}

/// Adapts server seats so the existing table always shows this player as 0.
class RemoteGameEngine extends GameEngine {
  final OnlineConnection connection;
  int seat = 0;
  int round = 1;
  int rematchCount = 0;
  int humanCount = 0;
  bool votedRematch = false;
  void requestRematch() {
    if (connection.connected && winner != null && !votedRematch) {
      connection.send({'type': 'rematch'});
    }
  }

  int? _choiceId;
  ChoiceRequest? _remoteChoice;
  bool _disposed = false;
  RemoteGameEngine(this.connection, GameRules rules) : super(rules: rules);
  int _local(int id) => (id - seat + 4) % 4;
  int _server(int id) => (id + seat) % 4;

  void apply(Map<String, dynamic> data) {
    if (_disposed) return;
    seat = data['seat'] as int;
    round = data['round'] as int? ?? 1;
    final votes = data['rematchVotes'] as List? ?? [];
    rematchCount = votes.length;
    humanCount = data['humanCount'] as int? ?? 0;
    votedRematch = votes.contains(seat);
    final nextPlayers = <Player>[];
    known.clear();
    for (final raw in data['players'] as List) {
      final id = _local(raw['id'] as int);
      final player = Player(
          id: id,
          name: raw['name'] as String,
          human: id == 0,
          red: raw['red'] as int? ?? 0,
          blue: raw['blue'] as int? ?? 0);
      player.mana = raw['mana'] as int;
      player.free = raw['free'] as int;
      player.frozen = raw['frozen'] as bool;
      player.hand.addAll(raw['hand'] == null
          ? List.filled(raw['handCount'] as int, '?')
          : List<String>.from(raw['hand'] as List));
      for (final c in CardColor.values) {
        if (raw[c == CardColor.red ? 'red' : 'blue'] != null) {
          known.add('$id-${c.index}');
        }
      }
      nextPlayers.add(player);
    }
    nextPlayers.sort((a, b) => a.id.compareTo(b.id));
    players = nextPlayers;
    turn = _local(data['turn'] as int);
    busy = data['busy'] as bool;
    statusMessage = data['paused'] == true
        ? 'La mesa espera a ${(data['missing'] as List).join(', ')}. Guardamos su asiento hasta 60 segundos.'
        : null;
    winner = data['winner'] as String?;
    deck = List.filled(data['deckCount'] as int, '?');
    logs
      ..clear()
      ..addAll((data['logs'] as List)
          .map((l) => LogEntry(l['text'] as String, loud: l['loud'] as bool)));
    final pending = data['choice'] as Map<String, dynamic>?;
    if (pending != null) {
      if (_choiceId != pending['id']) {
        if (choice != null && !identical(choice, _remoteChoice)) {
          super.answer(null);
        }
        _choiceId = pending['id'] as int;
        _remoteChoice = ChoiceRequest(
            title: pending['title'] as String,
            desc: pending['desc'] as String,
            completer: Completer<Object?>(),
            seconds: (pending['seconds'] as num?)?.toDouble(),
            options: (pending['options'] as List)
                .map((o) => ChoiceOption(o['label'] as String, o['value']))
                .toList());
        choice = _remoteChoice;
      }
    } else if (identical(choice, _remoteChoice)) {
      choice = null;
      _remoteChoice = null;
      _choiceId = null;
    } else if (turn != 0 || busy) {
      super.answer(null);
    }
    notifyListeners();
  }

  void receiveFx(Map<String, dynamic> data) {
    if (_disposed) return;
    var kind = FxKind.values[data['kind'] as int];
    final actual = data['player'] as int?;
    if (kind == FxKind.win || kind == FxKind.lose) {
      kind = actual == seat ? FxKind.win : FxKind.lose;
    }
    final local = actual == null ? null : _local(actual);
    final color = data['color'] as int?;
    if (kind == FxKind.burn && local != null && color != null) {
      final key = '$local-$color';
      burnTokens[key] = (burnTokens[key] ?? 0) + 1;
    }
    onFx?.call(Fx(kind,
        playerId: local,
        color: color == null ? null : CardColor.values[color],
        cardId: data['card'] as String?,
        actorName: data['actor'] as String?));
  }

  void showError(String message) {
    statusMessage = message;
    logs.add(LogEntry(message, loud: true));
    notifyListeners();
  }

  void disconnected(String message) {
    busy = true;
    super.answer(null);
    _choiceId = null;
    _remoteChoice = null;
    showError(message);
  }

  void _send(Map<String, dynamic> data) {
    statusMessage = null;
    busy = true;
    notifyListeners();
    connection.send(data);
  }

  @override
  Future<bool> humanPlay(int handIndex) async {
    if (!myTurn || handIndex < 0 || handIndex >= me.hand.length) return false;
    final key = me.hand[handIndex];
    final card = kCards[key]!;
    if (card.isReaction ||
        me.frozen ||
        (me.free > 0 ? 0 : card.cost) > me.mana) {
      return false;
    }
    final q = await collectTargets(key, me);
    if (q == null || !myTurn) return false;
    _send({
      'type': 'play',
      'card': key,
      'targets': {
        'own': q.own?.index,
        'color': q.color?.index,
        'foe': q.foe == null ? null : _server(q.foe!),
        'foeColor': q.foeColor?.index
      }
    });
    return true;
  }

  @override
  Future<void> endTurn() async {
    if (myTurn) _send({'type': 'end'});
  }

  @override
  Future<bool> sing(int id) async {
    if (!myTurn || !canSing(0)) return false;
    _send({'type': 'sing'});
    return true;
  }

  @override
  void answer(Object? value) {
    if (_remoteChoice != null && identical(choice, _remoteChoice)) {
      connection.send({'type': 'answer', 'choice': _choiceId, 'value': value});
    } else {
      super.answer(value);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
