/// Utilidades para mostrar iniciales de una persona en avatares.
abstract final class AvatarUtils {
  /// Devuelve una o dos iniciales en mayúscula para un nombre visible.
  ///
  /// Ejemplos: "Camila Rojas" → "CR"; "Matías" → "M".
  static String initialsFor(String displayName) {
    final List<String> parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
