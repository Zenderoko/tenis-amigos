/// Mano dominante con la que juega el usuario.
enum DominantHand {
  right('right', 'Diestro'),
  left('left', 'Zurdo');

  const DominantHand(this.value, this.label);

  final String value;
  final String label;

  static DominantHand? fromValue(String? rawValue) {
    final String value = rawValue?.trim().toLowerCase() ?? '';
    return switch (value) {
      'right' || 'diestro' || 'derecha' => DominantHand.right,
      'left' || 'zurdo' || 'izquierda' => DominantHand.left,
      _ => null,
    };
  }
}
