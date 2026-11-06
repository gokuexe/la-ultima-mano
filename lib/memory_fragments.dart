/// Authored fiction, not device data. Discoveries never grant competitive power.
class MemoryFragment {
  final String id;
  final String title;
  final String text;
  final int art;
  const MemoryFragment(this.id, this.title, this.text, this.art);
}

const memoryFragments = <MemoryFragment>[
  MemoryFragment(
      'dinner-photo',
      'La quinta cena',
      'Hay cinco platos en la fotografía. Solo reconocés cuatro sillas. En el reverso alguien escribió: «No le guardes lugar».',
      0),
  MemoryFragment(
      'witness-note',
      'La hora tachada',
      'El Testigo anotó la misma hora antes y después del golpe. Una de las dos está escrita con tu letra.',
      1),
  MemoryFragment(
      'mirror-shard',
      'El reflejo que espera',
      'En este fragmento, las cuatro figuras siguen sentadas. Tu reflejo todavía no eligió una carta.',
      2),
  MemoryFragment(
      'lost-key',
      'Una llave sin puerta',
      'La etiqueta dice 067. La llave no entra en la cerradura de la habitación. Tiene la forma de una casa que casi recordás.',
      3),
  MemoryFragment(
      'seat-ticket',
      'Asiento cero',
      'El billete no tiene fecha. Tu asiento figura como ocupado desde antes de que llegaras. El destino fue recortado.',
      1),
  MemoryFragment(
      'burnt-letter',
      'Lo que quedó del nombre',
      '«No se trataba de salir primero. Se trataba de que alguien quedara para recordarnos». Debajo hay seis letras quemadas.',
      4),
];

MemoryFragment? memoryById(String id) {
  for (final memory in memoryFragments) {
    if (memory.id == id) return memory;
  }
  return null;
}
