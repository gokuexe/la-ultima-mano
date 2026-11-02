import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<Map<String, dynamic>> next(StreamIterator<dynamic> stream, String type,
    [bool Function(Map<String, dynamic>)? test]) async {
  while (await stream.moveNext().timeout(const Duration(seconds: 5))) {
    final message =
        jsonDecode(stream.current as String) as Map<String, dynamic>;
    if (message['type'] == type && (test?.call(message) ?? true))
      return message;
  }
  throw StateError('Connection closed before $type');
}

void check(bool value, String description) {
  if (!value) throw StateError(description);
}

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/compiled_smoke.dart /path/to/server');
    exitCode = 64;
    return;
  }
  final process = await Process.start(args.single, const [],
      environment: {'HOST': '127.0.0.1', 'PORT': '0'});
  final port = Completer<int>();
  process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
    final found = RegExp(r'servidor en 127\.0\.0\.1:(\d+)').firstMatch(line);
    if (found != null && !port.isCompleted) port.complete(int.parse(found[1]!));
  });
  process.stderr.transform(utf8.decoder).listen(stderr.write);
  WebSocket? host, guest;
  try {
    final address =
        'ws://127.0.0.1:${await port.future.timeout(const Duration(seconds: 5))}/ws';
    host = await WebSocket.connect(address);
    final hs = StreamIterator<dynamic>(host);
    guest = await WebSocket.connect(address);
    final gs = StreamIterator<dynamic>(guest);
    host.add(jsonEncode({'type': 'create', 'name': 'Uno', 'mode': 0}));
    final lobby = await next(hs, 'lobby');
    guest.add(
        jsonEncode({'type': 'join', 'name': 'Dos', 'code': lobby['code']}));
    await next(gs, 'lobby');
    host.add(jsonEncode({'type': 'start'}));
    final h = await next(hs, 'state');
    final g = await next(gs, 'state');
    check(h['players'][0]['hand'] != null && h['players'][1]['hand'] == null,
        'host privacy');
    check(g['players'][1]['hand'] != null && g['players'][0]['red'] == null,
        'guest privacy');
    host.add(jsonEncode({'type': 'end'}));
    await next(gs, 'state', (m) => m['turn'] == 1 && m['busy'] == false);
    await host.close();
    await next(gs, 'closed');
    await guest.close();
    stdout.writeln(
        'Compiled server: two connections, privacy, turn transfer and disconnection OK');
  } finally {
    await host?.close();
    await guest?.close();
    process.kill(ProcessSignal.sigint);
    await process.exitCode.timeout(const Duration(seconds: 5));
  }
}
