import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/friend_repository.dart';
import '../data/friends_realtime.dart';
import '../data/supabase_friend_repository.dart';
import '../domain/friend.dart';

/// Repositorio de amigos respaldado por Supabase.
final Provider<FriendRepository> friendRepositoryProvider =
    Provider<FriendRepository>((Ref ref) => const SupabaseFriendRepository());

/// Escucha cambios remotos para mantener la lista sincronizada entre usuarios.
final Provider<FriendsRealtime> friendsRealtimeProvider =
    Provider<FriendsRealtime>((Ref ref) => SupabaseFriendsRealtime());

/// Amigos y solicitudes del usuario actual.
final AsyncNotifierProvider<FriendsNotifier, FriendsOverview> friendsProvider =
    AsyncNotifierProvider<FriendsNotifier, FriendsOverview>(
      FriendsNotifier.new,
    );

class FriendsNotifier extends AsyncNotifier<FriendsOverview> {
  FriendRepository get _repository => ref.read(friendRepositoryProvider);

  @override
  Future<FriendsOverview> build() async {
    // Depende de la sesión para no reutilizar los amigos de otra cuenta
    // cuando el provider sigue vivo entre inicios y cierres de sesión.
    final AuthUser? user = await ref.watch(authControllerProvider.future);
    if (user == null) {
      throw const AppFailure(
        'No hay una sesión activa. Inicia sesión para ver tus amigos.',
        code: 'no_active_session',
      );
    }

    final FriendsRealtime realtime = ref.watch(friendsRealtimeProvider);
    bool active = true;
    try {
      realtime.start(() {
        if (active) {
          unawaited(_reload());
        }
      });
    } catch (error) {
      debugPrint('Friends realtime unavailable: $error');
    }
    ref.onDispose(() {
      active = false;
      realtime.stop();
    });

    return _repository.fetchOverview();
  }

  Future<FriendRequestResult> sendRequest(String email) async {
    final FriendRequestResult result = await _repository.sendRequestByEmail(
      email: email,
    );
    await _reload();
    return result;
  }

  Future<void> respond(String requestId, {required bool accept}) async {
    await _repository.respondToRequest(requestId: requestId, accept: accept);
    await _reload();
  }

  Future<void> cancel(String requestId) async {
    await _repository.cancelRequest(requestId: requestId);
    await _reload();
  }

  Future<void> removeFriend(String friendId) async {
    await _repository.removeFriend(friendId: friendId);
    await _reload();
  }

  Future<void> _reload() async {
    state = await AsyncValue.guard(_repository.fetchOverview);
  }
}
