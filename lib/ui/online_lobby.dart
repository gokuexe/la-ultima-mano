import '../l10n/game_text.dart';
import 'dart:async';
import '../platform/connection_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game_config.dart';
import '../online/online_connection.dart';
import '../online/server_endpoint.dart';
import '../theme.dart';
import 'game_screen.dart';

class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({super.key});
  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  final _address = TextEditingController(
      text: ServerEndpoint.configured.isEmpty
          ? 'ws://127.0.0.1:8080/ws'
          : ServerEndpoint.configured);
  final _name = TextEditingController();
  final _code = TextEditingController();
  OnlineConnection? _connection;
  bool _connecting = false;
  bool _playing = false;
  String? _error;
  GameMode _mode = GameMode.classic;
  @override
  void dispose() {
    _connection?.removeListener(_update);
    _connection?.dispose();
    _address.dispose();
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  void _update() {
    if (!mounted) return;
    setState(() {});
    if (_connection!.game != null && !_playing) {
      _playing = true;
      Navigator.of(context)
          .push(MaterialPageRoute<void>(
              builder: (_) => GameScreen(
                  session: _connection!.game, rules: _connection!.game!.rules)))
          .then((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  void _resetConnection() {
    _connection?.removeListener(_update);
    _connection?.dispose();
    setState(() {
      _connection = null;
      _error = null;
    });
  }

  Future<void> _connect(bool create) async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Elegí cómo te llaman en la mesa.');
      return;
    }
    final code = _code.text.trim().toUpperCase();
    if (!create && !RegExp(r'^[A-HJ-NP-Z2-9]{6}$').hasMatch(code)) {
      setState(() =>
          _error = 'Ingresá el código de seis letras y números de la sala.');
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });
    _connection?.removeListener(_update);
    _connection?.dispose();
    final connection = OnlineConnection()..addListener(_update);
    _connection = connection;
    try {
      await connection.connect(_address.text.trim(), {
        'type': create ? 'create' : 'join',
        'name': _name.text.trim(),
        'code': code,
        'mode': _mode.index
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on TimeoutException {
      if (mounted) {
        setState(() => _error =
            'El servidor tarda en responder. Esperá un momento y volvé a intentar.');
      }
    } on ConnectionFailure {
      if (mounted) {
        setState(() => _error =
            'No se pudo llegar al servidor. Comprobá Internet y la dirección.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'No se pudo abrir la mesa. Intentá de nuevo en un momento.');
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lobby = _connection?.lobby;
    final error = _error ?? _connection?.error;
    return Scaffold(
      appBar: AppBar(title: const GameText('LA MESA COMPARTIDA')),
      body: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              const GameText('Hay otras voces en la habitación.',
                  style: SS.title),
              const SizedBox(height: 12),
              if (lobby == null) ...[
                const GameText(
                    'Creá una sala privada o usá el código de otra persona. Sin cuentas.',
                    style: SS.body),
                const SizedBox(height: 20),
                if (ServerEndpoint.configured.isEmpty)
                  TextField(
                      controller: _address,
                      decoration: InputDecoration(
                          labelText: context.tr('Servidor (ws:// o wss://)'),
                          helperText: context.tr(
                              'En otra notebook, usá la IP del anfitrión.\n127.0.0.1 solo conecta dentro de este equipo.'),
                          helperMaxLines: 2))
                else
                  ExpansionTile(
                    title: const GameText('Opciones de conexión'),
                    children: [
                      TextField(
                          controller: _address,
                          decoration: InputDecoration(
                              labelText: context.tr('Servidor seguro'))),
                    ],
                  ),
                TextField(
                    controller: _name,
                    maxLength: 20,
                    decoration: InputDecoration(
                        labelText: context.tr('Tu nombre en la mesa'))),
                DropdownButton<GameMode>(
                    value: _mode,
                    isExpanded: true,
                    items: GameMode.values
                        .map((m) => DropdownMenuItem(
                            value: m, child: GameText(GameRules(m).label)))
                        .toList(),
                    onChanged: (m) => setState(() => _mode = m!)),
                FilledButton(
                    onPressed: _connecting ? null : () => _connect(true),
                    child: const GameText('CREAR SALA')),
                const SizedBox(height: 16),
                TextField(
                    controller: _code,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                        labelText: context.tr('Código de invitación'))),
                OutlinedButton(
                    onPressed: _connecting ? null : () => _connect(false),
                    child: const GameText('ENTRAR A LA SALA')),
              ] else ...[
                const GameText('Compartí este código con tus invitados:',
                    style: SS.body),
                SelectableText(lobby['code'] as String,
                    style: SS.title.copyWith(fontSize: 36)),
                TextButton(
                    onPressed: () => Clipboard.setData(
                        ClipboardData(text: lobby['code'] as String)),
                    child: const GameText('Copiar código')),
                GameText('Servidor: ${_address.text.trim()}', style: SS.sub),
                for (final p in lobby['players'] as List)
                  ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: GameText(p['name'] as String, translate: false),
                      subtitle: GameText(p['connected'] == false
                          ? 'Reconectando…'
                          : p['seat'] == 0
                              ? 'Anfitrión'
                              : 'Invitado')),
                const GameText(
                    'De 2 a 4 personas. Los lugares vacíos los ocupan ecos controlados por el juego.',
                    style: SS.sub),
                if (lobby['seat'] == 0)
                  FilledButton(
                      onPressed: !(_connection?.connected ?? false) ||
                              (lobby['players'] as List).length < 2 ||
                              (lobby['players'] as List)
                                  .any((p) => p['connected'] == false)
                          ? null
                          : () => _connection!.send({'type': 'start'}),
                      child: const GameText('ABRIR LA PARTIDA'))
                else
                  const GameText('Esperando al anfitrión…', style: SS.body),
              ],
              if (lobby != null && !(_connection?.connected ?? false))
                OutlinedButton(
                  onPressed: _resetConnection,
                  child: const GameText('VOLVER A ENTRAR'),
                ),
              if (_connecting) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                GameText(_connection?.connectionStatus ?? 'Buscando la mesa…',
                    style: SS.sub),
              ],
              if (error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: GameText(error,
                        style: const TextStyle(color: SS.rojoUp))),
            ]),
      )),
    );
  }
}
