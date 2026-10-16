/// Modelo del perfil de usuario.
///
/// En la Etapa 2 se vinculará al usuario de Supabase Auth mediante su id
/// ([id]), no mediante el correo ni el nombre.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.memberSince,
    this.avatarUrl,
    this.tennisLevel,
    this.dominantHand,
  });

  final String id;
  final String displayName;
  final String email;
  final DateTime memberSince;

  /// Foto de perfil opcional.
  final String? avatarUrl;

  /// Nivel de tenis opcional.
  final String? tennisLevel;

  /// Mano dominante opcional ("Diestro" / "Zurdo").
  final String? dominantHand;
}
