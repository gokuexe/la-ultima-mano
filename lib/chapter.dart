import 'game_config.dart';

enum MemoryPath { name, door }

abstract final class ChapterOne {
  static const title = '01 / LA HABITACIÓN SIN RELOJ';
  static String clue(MemoryPath path) => path == MemoryPath.name
      ? 'Debajo de la silla encontrás tu nombre. La última letra está escrita por otra mano.'
      : 'La puerta tiene marcas por dentro. Una de ellas está a la altura de tu mano.';
  static String opening(MemoryPath path) => path == MemoryPath.name
      ? 'La Viuda mira la letra que falta. «No dejes que elijan cómo te llamás.»'
      : 'El Testigo mira tus manos. «La puerta siempre estuvo de este lado.»';
  static String ending(MemoryPath path, bool won) {
    if (!won) {
      return 'La puerta se abre para otra persona. Antes de cerrarse, escuchás tu propia voz desde el pasillo.\n\nLa Viuda acerca otra silla. «Todavía podés contar tu versión.»';
    }
    return path == MemoryPath.name
        ? 'Cruzás la puerta llevando el papel. Tu nombre ya está completo.\n\nDel otro lado hay una fotografía de las cuatro sillas. En el reverso dice: «Esta vez, acordate de volver por ellos».\n\nFIN DEL CAPÍTULO 01'
        : 'La puerta se abre hacia la misma habitación, pero las tres sillas están vacías.\n\nBajo la tuya encontrás una llave sin dientes y una nota: «No era la salida lo que estabas buscando».\n\nFIN DEL CAPÍTULO 01';
  }
}

/// A safe practice table, independent from a real match or hidden state.
class MemoryLesson {
  int red = 5;
  int blue = 8;
  int lucidity = const GameRules.classic().manaPerTurn;
  bool get ready => (red == 6 && blue == 7) || (red == 7 && blue == 6);
  bool adjust({required bool redCard, required int delta}) {
    if (lucidity < 1 || (delta != 1 && delta != -1)) return false;
    final next = (redCard ? red : blue) + delta;
    if (next < 0 || next > 13) return false;
    if (redCard) {
      red = next;
    } else {
      blue = next;
    }
    lucidity--;
    return true;
  }

  void reset() {
    red = 5;
    blue = 8;
    lucidity = const GameRules.classic().manaPerTurn;
  }
}
