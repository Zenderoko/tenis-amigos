import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_friend_repository.dart';
import '../domain/friend.dart';

/// Repositorio de amigos (mock). En la Etapa 3 se reemplazará por Supabase.
final Provider<MockFriendRepository> friendRepositoryProvider =
    Provider<MockFriendRepository>((Ref ref) => const MockFriendRepository());

/// Lista de amigos confirmados (mock).
final FutureProvider<List<Friend>> friendsProvider =
    FutureProvider<List<Friend>>((Ref ref) async {
  return ref.watch(friendRepositoryProvider).fetchFriends();
});

/// Solicitudes de amistad pendientes.
///
/// Se modela con un [AsyncNotifier] porque, además de cargarse de forma
/// asíncrona, el usuario puede aceptarlas o rechazarlas. Por ahora el cambio
/// es solo en memoria (prototipo); en la Etapa 3 se persistirá en el backend.
final AsyncNotifierProvider<FriendRequestsNotifier, List<FriendRequest>>
    friendRequestsProvider =
    AsyncNotifierProvider<FriendRequestsNotifier, List<FriendRequest>>(
      FriendRequestsNotifier.new,
    );

class FriendRequestsNotifier extends AsyncNotifier<List<FriendRequest>> {
  @override
  Future<List<FriendRequest>> build() {
    return ref.read(friendRepositoryProvider).fetchRequests();
  }

  void accept(String id) => _remove(id);

  void reject(String id) => _remove(id);

  void _remove(String id) {
    final List<FriendRequest> current =
        state.value ?? const <FriendRequest>[];
    state = AsyncData<List<FriendRequest>>(
      current
          .where((FriendRequest request) => request.id != id)
          .toList(),
    );
  }
}
