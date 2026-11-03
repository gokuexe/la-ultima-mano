import 'dart:async';
import 'dart:io';
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

  Future<void> _connect(bool create) async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Elegí cómo te llaman en la mesa.');
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });
    _connection?.dispose();
    final connection = OnlineConnection()..addListener(_update);
    _connection = connection;
    try {
      await connection.connect(_address.text.trim(), {
        'type': create ? 'create' : 'join',
        'name': _name.text.trim(),
        'code': _code.text.trim(),
        'mode': _mode.index
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on TimeoutException {
      if (mounted) {
        setState(() => _error =
            'El servidor tarda en responder. Esperá un momento y volvé a intentar.');
      }
    } on SocketException {
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
      appBar: AppBar(title: const Text('LA MESA COMPARTIDA')),
      body: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              const Text('Hay otras voces en la habitación.', style: SS.title),
              const SizedBox(height: 12),
              if (lobby == null) ...[
                const Text(
                    'Creá una sala privada o usá el código de otra persona. Sin cuentas.',
                    style: SS.body),
                const SizedBox(height: 20),
                if (ServerEndpoint.configured.isEmpty)
                  TextField(
                      controller: _address,
                      decoration: const InputDecoration(
                          labelText: 'Servidor (ws:// o wss://)',
                          helperText:
                              'En otra notebook, usá la IP del anfitrión.\n127.0.0.1 solo conecta dentro de este equipo.',
                          helperMaxLines: 2))
                else
                  ExpansionTile(
                    title: const Text('Opciones de conexión'),
                    children: [
                      TextField(
                          controller: _address,
                          decoration: const InputDecoration(
                              labelText: 'Servidor seguro')),
                    ],
                  ),
                TextField(
                    controller: _name,
                    maxLength: 20,
                    decoration: const InputDecoration(
                        labelText: 'Tu nombre en la mesa')),
                DropdownButton<GameMode>(
                    value: _mode,
                    isExpanded: true,
                    items: GameMode.values
                        .map((m) => DropdownMenuItem(
                            value: m, child: Text(GameRules(m).label)))
                        .toList(),
                    onChanged: (m) => setState(() => _mode = m!)),
                FilledButton(
                    onPressed: _connecting ? null : () => _connect(true),
                    child: const Text('CREAR SALA')),
                const SizedBox(height: 16),
                TextField(
                    controller: _code,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                        labelText: 'Código de invitación')),
                OutlinedButton(
                    onPressed: _connecting ? null : () => _connect(false),
                    child: const Text('ENTRAR A LA SALA')),
              ] else ...[
                const Text('Compartí este código con tus invitados:',
                    style: SS.body),
                SelectableText(lobby['code'] as String,
                    style: SS.title.copyWith(fontSize: 36)),
                TextButton(
                    onPressed: () => Clipboard.setData(
                        ClipboardData(text: lobby['code'] as String)),
                    child: const Text('Copiar código')),
                Text('Servidor: ${_address.text.trim()}', style: SS.sub),
                for (final p in lobby['players'] as List)
                  ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(p['name'] as String),
                      subtitle:
                          Text(p['seat'] == 0 ? 'Anfitrión' : 'Invitado')),
                const Text(
                    'De 2 a 4 personas. Los lugares vacíos los ocupan ecos controlados por el juego.',
                    style: SS.sub),
                if (lobby['seat'] == 0)
                  FilledButton(
                      onPressed: !(_connection?.connected ?? false) ||
                              (lobby['players'] as List).length < 2
                          ? null
                          : () => _connection!.send({'type': 'start'}),
                      child: const Text('ABRIR LA PARTIDA'))
                else
                  const Text('Esperando al anfitrión…', style: SS.body),
              ],
              if (_connecting) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(_connection?.connectionStatus ?? 'Buscando la mesa…',
                    style: SS.sub),
              ],
              if (error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child:
                        Text(error, style: const TextStyle(color: SS.rojoUp))),
            ]),
      )),
    );
  }
}
