import '../domain/friend.dart';

/// Repositorio de amigos con datos FICTICIOS, solo para prototipos visuales.
///
/// Se reemplazará por consultas reales a Supabase en la Etapa 3.
class MockFriendRepository {
  const MockFriendRepository();

  Future<List<Friend>> fetchFriends() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return <Friend>[
      const Friend(
        id: 'u2',
        displayName: 'Camila Rojas',
        tennisLevel: 'Intermedio',
        isFavorite: true,
      ),
      const Friend(
        id: 'u3',
        displayName: 'Matías Fuentes',
        tennisLevel: 'Avanzado',
      ),
      const Friend(
        id: 'u4',
        displayName: 'Josefa Herrera',
        tennisLevel: 'Principiante',
      ),
      const Friend(
        id: 'u5',
        displayName: 'Diego Soto',
        tennisLevel: 'Intermedio',
      ),
      const Friend(
        id: 'u6',
        displayName: 'Valentina Paz',
      ),
    ];
  }

  Future<List<FriendRequest>> fetchRequests() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final DateTime now = DateTime.now();
    return <FriendRequest>[
      FriendRequest(
        id: 'r1',
        displayName: 'Tomás Vergara',
        receivedAt: now.subtract(const Duration(days: 1)),
      ),
      FriendRequest(
        id: 'r2',
        displayName: 'Fernanda Silva',
        receivedAt: now.subtract(const Duration(hours: 5)),
      ),
    ];
  }
}
