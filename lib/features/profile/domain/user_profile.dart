/// Modelo del perfil de usuario.
///
/// Se vincula al usuario de Supabase Auth mediante su id ([id]), no mediante
/// el correo ni el nombre.
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

  factory UserProfile.fromMap(
    Map<String, dynamic> map, {
    required String email,
  }) {
    final String? displayName = (map['display_name'] as String?)?.trim();
    final DateTime? createdAt = DateTime.tryParse(
      map['created_at']?.toString() ?? '',
    );

    return UserProfile(
      id: map['id'] as String,
      displayName: displayName != null && displayName.isNotEmpty
          ? displayName
          : _nameFromEmail(email),
      email: email,
      memberSince: (createdAt ?? DateTime.now()).toLocal(),
      avatarUrl: _optionalString(map['avatar_url']),
      tennisLevel: _optionalString(map['tennis_level']),
      dominantHand: _optionalString(map['dominant_hand']),
    );
  }

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

String _nameFromEmail(String email) {
  final int at = email.indexOf('@');
  return at > 0 ? email.substring(0, at) : email;
}

String? _optionalString(Object? value) {
  if (value is! String) {
    return null;
  }
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
