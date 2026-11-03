/// Modelos del módulo de amigos.
library;

import '../../profile/domain/dominant_hand.dart';
import '../../profile/domain/tennis_level.dart';

/// Una persona con la que existe (o existirá) una relación de amistad.
class Friend {
  const Friend({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.tennisLevel,
    this.dominantHand,
  });

  factory Friend.fromMap(Map<String, dynamic> map) {
    final String? displayName = _optionalString(map['display_name']);
    return Friend(
      id: map['id'] as String,
      displayName: displayName ?? 'Usuario',
      avatarUrl: _optionalString(map['avatar_url']),
      tennisLevel: TennisLevel.fromValue(map['tennis_level'] as String?),
      dominantHand: DominantHand.fromValue(map['dominant_hand'] as String?),
    );
  }

  final String id;
  final String displayName;

  /// Foto de perfil opcional.
  final String? avatarUrl;

  /// Nivel de tenis declarado (opcional).
  final TennisLevel? tennisLevel;

  /// Mano dominante (opcional).
  final DominantHand? dominantHand;
}

/// Una solicitud de amistad recibida y pendiente de responder.
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.sender,
    required this.receivedAt,
  });

  final String id;
  final Friend sender;
  final DateTime receivedAt;
}

/// Una solicitud de amistad enviada y pendiente de respuesta.
class SentFriendRequest {
  const SentFriendRequest({
    required this.id,
    required this.recipient,
    required this.sentAt,
  });

  final String id;
  final Friend recipient;
  final DateTime sentAt;
}

/// Vista consolidada de amistades y solicitudes del usuario actual.
class FriendsOverview {
  const FriendsOverview({
    this.friends = const <Friend>[],
    this.incomingRequests = const <FriendRequest>[],
    this.outgoingRequests = const <SentFriendRequest>[],
  });

  /// Construye la vista a partir de las filas de `friendships` y los perfiles
  /// ya resueltos. Se separa del repositorio para poder probarla sin Supabase.
  factory FriendsOverview.fromRows({
    required String currentUserId,
    required List<Map<String, dynamic>> rows,
    required Map<String, Friend> profiles,
  }) {
    final List<Friend> friends = <Friend>[];
    final Set<String> friendIds = <String>{};
    final List<FriendRequest> incoming = <FriendRequest>[];
    final List<SentFriendRequest> outgoing = <SentFriendRequest>[];

    for (final Map<String, dynamic> row in rows) {
      final String? id = row['id'] as String?;
      final String? userId = row['user_id'] as String?;
      final String? friendId = row['friend_id'] as String?;
      final String? status = row['status'] as String?;
      if (id == null || userId == null || friendId == null) {
        continue;
      }

      final DateTime createdAt =
          DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now();

      if (status == 'accepted') {
        final String? otherId = userId == currentUserId
            ? friendId
            : (friendId == currentUserId ? userId : null);
        if (otherId == null || !friendIds.add(otherId)) {
          continue;
        }
        friends.add(profiles[otherId] ?? _unknown(otherId));
      } else if (status == 'pending') {
        if (friendId == currentUserId) {
          incoming.add(
            FriendRequest(
              id: id,
              sender: profiles[userId] ?? _unknown(userId),
              receivedAt: createdAt,
            ),
          );
        } else if (userId == currentUserId) {
          outgoing.add(
            SentFriendRequest(
              id: id,
              recipient: profiles[friendId] ?? _unknown(friendId),
              sentAt: createdAt,
            ),
          );
        }
      }
    }

    friends.sort(
      (Friend a, Friend b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    incoming.sort(
      (FriendRequest a, FriendRequest b) =>
          b.receivedAt.compareTo(a.receivedAt),
    );
    outgoing.sort(
      (SentFriendRequest a, SentFriendRequest b) =>
          b.sentAt.compareTo(a.sentAt),
    );

    return FriendsOverview(
      friends: friends,
      incomingRequests: incoming,
      outgoingRequests: outgoing,
    );
  }

  final List<Friend> friends;
  final List<FriendRequest> incomingRequests;
  final List<SentFriendRequest> outgoingRequests;

  bool get isEmpty =>
      friends.isEmpty && incomingRequests.isEmpty && outgoingRequests.isEmpty;
}

/// Resultado de intentar enviar una solicitud de amistad.
enum FriendRequestOutcome { sent, accepted, alreadyFriends, alreadyRequested }

class FriendRequestResult {
  const FriendRequestResult({required this.outcome, required this.targetName});

  final FriendRequestOutcome outcome;
  final String targetName;
}

Friend _unknown(String id) => Friend(id: id, displayName: 'Usuario');

String? _optionalString(Object? value) {
  if (value is! String) {
    return null;
  }
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
