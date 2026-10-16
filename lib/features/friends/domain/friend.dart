/// Modelos del módulo de amigos.
library;

/// Un amigo confirmado.
class Friend {
  const Friend({
    required this.id,
    required this.displayName,
    this.tennisLevel,
    this.isFavorite = false,
  });

  final String id;
  final String displayName;

  /// Nivel de tenis declarado (opcional).
  final String? tennisLevel;
  final bool isFavorite;
}

/// Una solicitud de amistad pendiente de responder.
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.displayName,
    required this.receivedAt,
  });

  final String id;
  final String displayName;
  final DateTime receivedAt;
}
