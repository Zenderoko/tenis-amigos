import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/friend.dart';
import 'friend_repository.dart';

/// Implementación de amistades respaldada por Supabase.
class SupabaseFriendRepository implements FriendRepository {
  const SupabaseFriendRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase {
    final SupabaseClient? client = _client;
    if (client != null) {
      return client;
    }
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw const AppFailure(
        'Supabase no está configurado. Revisa el archivo .env.',
        code: 'supabase_not_configured',
      );
    }
  }

  @override
  Future<FriendsOverview> fetchOverview() async {
    final String userId = _currentUserId();
    try {
      final List<Map<String, dynamic>> rows = await _supabase
          .from('friendships')
          .select('id, user_id, friend_id, status, created_at')
          .or('user_id.eq.$userId,friend_id.eq.$userId')
          .order('created_at', ascending: false);

      final Set<String> profileIds = <String>{};
      for (final Map<String, dynamic> row in rows) {
        final String? status = row['status'] as String?;
        final String? ownerId = row['user_id'] as String?;
        final String? friendId = row['friend_id'] as String?;
        if (ownerId == null || friendId == null) {
          continue;
        }
        if (status == 'accepted') {
          if (ownerId != userId) {
            profileIds.add(ownerId);
          }
          if (friendId != userId) {
            profileIds.add(friendId);
          }
        } else if (status == 'pending') {
          profileIds.add(ownerId == userId ? friendId : ownerId);
        }
      }

      final Map<String, Friend> profiles = <String, Friend>{};
      if (profileIds.isNotEmpty) {
        final List<Map<String, dynamic>> profileRows = await _supabase
            .from('profiles')
            .select('id, display_name, avatar_url, tennis_level, dominant_hand')
            .inFilter('id', profileIds.toList());
        for (final Map<String, dynamic> row in profileRows) {
          final Friend friend = Friend.fromMap(row);
          profiles[friend.id] = friend;
        }
      }

      return FriendsOverview.fromRows(
        currentUserId: userId,
        rows: rows,
        profiles: profiles,
      );
    } on PostgrestException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<FriendRequestResult> sendRequestByEmail({
    required String email,
  }) async {
    try {
      final dynamic response = await _supabase.rpc(
        'send_friend_request_by_email',
        params: <String, dynamic>{'p_email': email.trim()},
      );
      final Map<String, dynamic> row = _firstRow(response);
      final String status = (row['status'] as String?) ?? 'sent';
      final String? targetName = _optionalString(row['target_name']);

      return FriendRequestResult(
        outcome: switch (status) {
          'accepted' => FriendRequestOutcome.accepted,
          'already_friends' => FriendRequestOutcome.alreadyFriends,
          'already_requested' => FriendRequestOutcome.alreadyRequested,
          _ => FriendRequestOutcome.sent,
        },
        targetName: targetName ?? 'tu amigo',
      );
    } on PostgrestException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<void> respondToRequest({
    required String requestId,
    required bool accept,
  }) async {
    try {
      await _supabase.rpc(
        'respond_friend_request',
        params: <String, dynamic>{
          'p_friendship_id': requestId,
          'p_accept': accept,
        },
      );
    } on PostgrestException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<void> cancelRequest({required String requestId}) async {
    try {
      await _supabase.rpc(
        'cancel_friend_request',
        params: <String, dynamic>{'p_friendship_id': requestId},
      );
    } on PostgrestException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<void> removeFriend({required String friendId}) async {
    try {
      await _supabase.rpc(
        'remove_friend',
        params: <String, dynamic>{'p_friend_id': friendId},
      );
    } on PostgrestException catch (error) {
      throw _failureFor(error);
    }
  }

  String _currentUserId() {
    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AppFailure(
        'Tu sesión expiró. Inicia sesión de nuevo.',
        code: 'no_session',
      );
    }
    return user.id;
  }

  Map<String, dynamic> _firstRow(dynamic response) {
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    throw const AppFailure(
      'Supabase no devolvió el resultado esperado.',
      code: 'unexpected_rpc_response',
    );
  }

  AppFailure _failureFor(PostgrestException error) {
    debugPrint('Friendship error: ${error.code} ${error.message}');
    final String message = error.message.toLowerCase();

    if (error.code == '42P01' || message.contains('could not find the table')) {
      return const AppFailure(
        'No encontramos las tablas de amigos. Aplica las migraciones de '
        'Supabase.',
        code: 'friendships_table_missing',
      );
    }
    if (error.code == '42883' ||
        error.code == 'PGRST202' ||
        message.contains('could not find the function') ||
        message.contains('schema cache')) {
      return const AppFailure(
        'Falta aplicar la migración de amigos en Supabase.',
        code: 'friendships_function_missing',
      );
    }
    if (message.contains('profile_not_found')) {
      return const AppFailure(
        'No encontramos una cuenta con ese correo.',
        code: 'profile_not_found',
      );
    }
    if (message.contains('cannot_add_self')) {
      return const AppFailure(
        'No puedes enviarte una solicitud a ti mismo.',
        code: 'cannot_add_self',
      );
    }
    if (message.contains('email_required')) {
      return const AppFailure(
        'Ingresa el correo de tu amigo.',
        code: 'email_required',
      );
    }
    if (message.contains('not_authenticated')) {
      return const AppFailure(
        'Tu sesión expiró. Inicia sesión de nuevo.',
        code: 'not_authenticated',
      );
    }
    if (message.contains('friendship_not_found')) {
      return const AppFailure(
        'La amistad ya no existe. Actualiza la lista.',
        code: 'friendship_not_found',
      );
    }
    if (message.contains('friendship_not_accepted')) {
      return const AppFailure(
        'La amistad ya no está activa. Actualiza la lista.',
        code: 'friendship_not_accepted',
      );
    }
    if (message.contains('request_not_found')) {
      return const AppFailure(
        'La solicitud ya no existe. Actualiza la lista.',
        code: 'request_not_found',
      );
    }
    if (message.contains('not_request_recipient')) {
      return const AppFailure(
        'No puedes responder esa solicitud.',
        code: 'not_request_recipient',
      );
    }
    if (message.contains('not_request_sender')) {
      return const AppFailure(
        'No puedes cancelar esa solicitud.',
        code: 'not_request_sender',
      );
    }
    if (message.contains('request_not_pending')) {
      return const AppFailure(
        'La solicitud ya fue respondida. Actualiza la lista.',
        code: 'request_not_pending',
      );
    }
    if (error.code == '23505') {
      return const AppFailure(
        'Ya existe una solicitud o amistad con esa persona. Actualiza la '
        'lista.',
        code: 'friendship_duplicate',
      );
    }
    if (error.code == '42501') {
      return const AppFailure(
        'No tienes permisos para realizar esta acción.',
        code: 'friendship_permission_denied',
      );
    }

    return const AppFailure(
      'No pudimos completar la acción. Intenta de nuevo.',
      code: 'friendship_error',
    );
  }
}

String? _optionalString(Object? value) {
  if (value is! String) {
    return null;
  }
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
