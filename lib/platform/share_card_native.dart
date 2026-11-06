import 'dart:io';
import 'package:flutter/services.dart';

Future<String?> exportResultCard(Uint8List bytes, String filename) async {
  if (!RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(filename)) {
    throw const FormatException('Invalid filename');
  }
  if (Platform.isAndroid) {
    await const MethodChannel('com.gokuexe.la_ultima_mano/share')
        .invokeMethod<void>('sharePng', {'bytes': bytes, 'filename': filename});
    return null;
  }
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  final directory =
      home == null ? Directory.systemTemp : Directory('$home/Downloads');
  await directory.create(recursive: true);
  final file = File('${directory.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
