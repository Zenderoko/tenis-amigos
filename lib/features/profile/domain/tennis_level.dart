/// Nivel de tenis declarado por el jugador.
///
/// Los valores se guardan en Supabase como claves estables en inglés para no
/// depender de las etiquetas visibles en español.
enum TennisLevel {
  beginner('beginner', 'Principiante'),
  intermediate('intermediate', 'Intermedio'),
  advanced('advanced', 'Avanzado'),
  competitive('competitive', 'Competitivo');

  const TennisLevel(this.value, this.label);

  final String value;
  final String label;

  static TennisLevel? fromValue(String? rawValue) {
    final String value = rawValue?.trim().toLowerCase() ?? '';
    if (value.isEmpty) {
      return null;
    }

    for (final TennisLevel level in values) {
      if (level.value == value || level.label.toLowerCase() == value) {
        return level;
      }
    }

    return switch (value) {
      'iniciación' || 'iniciacion' => beginner,
      _ => null,
    };
  }
}
