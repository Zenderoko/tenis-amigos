import 'package:flutter_test/flutter_test.dart';
import 'package:tenis_amigos/features/friends/domain/friend.dart';

void main() {
  const String me = 'user-1';

  final Map<String, Friend> profiles = <String, Friend>{
    'user-2': const Friend(id: 'user-2', displayName: 'Zoe Paz'),
    'user-3': const Friend(id: 'user-3', displayName: 'Ana Soto'),
    'user-4': const Friend(id: 'user-4', displayName: 'Camila Rojas'),
    'user-5': const Friend(id: 'user-5', displayName: 'Diego Fuentes'),
  };

  Map<String, dynamic> row({
    required String id,
    required String userId,
    required String friendId,
    required String status,
    required String createdAt,
  }) {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'friend_id': friendId,
      'status': status,
      'created_at': createdAt,
    };
  }

  test('separa amigos aceptados en ambas direcciones y solicitudes', () {
    final FriendsOverview overview = FriendsOverview.fromRows(
      currentUserId: me,
      rows: <Map<String, dynamic>>[
        row(
          id: 'f1',
          userId: me,
          friendId: 'user-2',
          status: 'accepted',
          createdAt: '2026-11-01T10:00:00Z',
        ),
        row(
          id: 'f2',
          userId: 'user-3',
          friendId: me,
          status: 'accepted',
          createdAt: '2026-11-01T09:00:00Z',
        ),
        row(
          id: 'f3',
          userId: 'user-4',
          friendId: me,
          status: 'pending',
          createdAt: '2026-11-02T09:00:00Z',
        ),
        row(
          id: 'f4',
          userId: me,
          friendId: 'user-5',
          status: 'pending',
          createdAt: '2026-11-02T10:00:00Z',
        ),
        row(
          id: 'f5',
          userId: me,
          friendId: 'user-6',
          status: 'rejected',
          createdAt: '2026-11-02T11:00:00Z',
        ),
      ],
      profiles: profiles,
    );

    expect(overview.friends.map((Friend friend) => friend.id), <String>[
      'user-3',
      'user-2',
    ]);
    expect(overview.incomingRequests.single.sender.id, 'user-4');
    expect(overview.outgoingRequests.single.recipient.id, 'user-5');
    expect(overview.isEmpty, isFalse);
  });

  test('usa un perfil de respaldo si falta la fila visible', () {
    final FriendsOverview overview = FriendsOverview.fromRows(
      currentUserId: me,
      rows: <Map<String, dynamic>>[
        row(
          id: 'f1',
          userId: me,
          friendId: 'user-9',
          status: 'accepted',
          createdAt: '2026-11-01T10:00:00Z',
        ),
      ],
      profiles: const <String, Friend>{},
    );

    expect(overview.friends.single.id, 'user-9');
    expect(overview.friends.single.displayName, 'Usuario');
  });

  test('ordena solicitudes por fecha descendente', () {
    final FriendsOverview overview = FriendsOverview.fromRows(
      currentUserId: me,
      rows: <Map<String, dynamic>>[
        row(
          id: 'f1',
          userId: 'user-4',
          friendId: me,
          status: 'pending',
          createdAt: '2026-11-01T10:00:00Z',
        ),
        row(
          id: 'f2',
          userId: 'user-3',
          friendId: me,
          status: 'pending',
          createdAt: '2026-11-02T10:00:00Z',
        ),
      ],
      profiles: profiles,
    );

    expect(
      overview.incomingRequests.map((FriendRequest request) => request.id),
      <String>['f2', 'f1'],
    );
  });

  test('una vista sin filas está vacía', () {
    const FriendsOverview overview = FriendsOverview();
    expect(overview.isEmpty, isTrue);
  });
}
