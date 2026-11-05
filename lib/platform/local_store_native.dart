import 'dart:io';
import 'package:flutter/services.dart';
import 'local_store_contract.dart';

LocalStore createStore(String name) {
  if (Platform.isAndroid) return AndroidStore(name);
  final base = Platform.environment['XDG_CONFIG_HOME'];
  final home = Platform.environment['HOME'];
  final directory = base != null && base.startsWith('/')
      ? base
      : home == null
          ? null
          : '$home/.config';
  return FileStore(
      directory == null ? null : File('$directory/la_ultima_mano/$name.json'));
}

class FileStore implements LocalStore {
  final File? file;
  FileStore(this.file);
  @override
  Future<String?> read() async {
    try {
      if (file == null || !await file!.exists()) return null;
      if (await file!.length() > 4096) {
        throw const FormatException('Oversized profile');
      }
      return await file!.readAsString();
    } on FileSystemException {
      throw const StorageFailure('No se pudo leer el archivo local.');
    }
  }

  @override
  Future<void> write(String value) async {
    try {
      if (file == null) {
        throw const StorageFailure('No hay directorio de configuración.');
      }
      await file!.parent.create(recursive: true);
      final temporary = File('${file!.path}.$pid.tmp');
      await temporary.writeAsString(value, flush: true);
      await temporary.rename(file!.path);
    } on FileSystemException {
      throw const StorageFailure('No se pudo guardar el archivo local.');
    }
  }
}

/// Android provides its private files directory; HOME/XDG are desktop concepts.
class AndroidStore implements LocalStore {
  static const channel = MethodChannel('com.gokuexe.la_ultima_mano/storage');
  final String name;
  AndroidStore(this.name);

  Future<FileStore> _resolve() async {
    try {
      final directory = await channel.invokeMethod<String>('filesDirectory');
      if (directory == null || !directory.startsWith('/')) {
        throw const StorageFailure('No hay directorio de configuración.');
      }
      return FileStore(File('$directory/la_ultima_mano/$name.json'));
    } on PlatformException {
      throw const StorageFailure('No hay directorio de configuración.');
    } on MissingPluginException {
      throw const StorageFailure('No hay directorio de configuración.');
    }
  }

  @override
  Future<String?> read() async => (await _resolve()).read();

  @override
  Future<void> write(String value) async => (await _resolve()).write(value);
}
