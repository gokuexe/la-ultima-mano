import 'package:web/web.dart' as web;
import 'local_store_contract.dart';

LocalStore createStore(String name) => BrowserStore('la_ultima_mano.$name');

class BrowserStore implements LocalStore {
  final String key;
  BrowserStore(this.key);
  @override
  Future<String?> read() async {
    try {
      final value = web.window.localStorage.getItem(key);
      if (value != null && value.length > 4096) {
        throw const FormatException('Oversized profile');
      }
      return value;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const StorageFailure(
          'El navegador no permite leer el guardado local.');
    }
  }

  @override
  Future<void> write(String value) async {
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {
      throw const StorageFailure('El navegador no permite guardar el avance.');
    }
  }
}
