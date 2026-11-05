import 'package:flutter/foundation.dart';

/// No files, identifiers, sensors or network calls. Not invoked when device hints are disabled.
String localStageHint(int index, {required String language, DateTime? now}) {
  switch (index % 3) {
    case 0:
      final time = now ?? DateTime.now();
      final stamp =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      return 'Son las $stamp en tu reloj. Acá todavía es la misma noche.';
    case 1:
      final platform = kIsWeb
          ? 'Web'
          : switch (defaultTargetPlatform) {
              TargetPlatform.android => 'Android',
              TargetPlatform.linux => 'Linux',
              TargetPlatform.windows => 'Windows',
              TargetPlatform.macOS => 'macOS',
              TargetPlatform.iOS => 'iOS',
              TargetPlatform.fuchsia => 'Fuchsia',
            };
      return 'Tu pantalla dice $platform. La puerta no conoce ese nombre.';
    default:
      return language == 'en'
          ? 'Elegiste inglés. Hay cosas que no necesitan traducción.'
          : 'Elegiste español. Hay cosas que no necesitan traducción.';
  }
}
