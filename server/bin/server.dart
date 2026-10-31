import 'dart:io';
import 'package:la_ultima_mano_server/room_server.dart';

Future<void> main() async {
  final server = RoomServer();
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final host = Platform.environment['HOST'] ?? '127.0.0.1';
  await server.start(host: host, port: port);
  stdout.writeln('La Última Mano: ws://$host:${server.port}/ws');
  ProcessSignal.sigint.watch().listen((_) async {
    await server.close();
    exit(0);
  });
}
