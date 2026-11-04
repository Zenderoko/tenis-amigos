import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Escucha cambios en `friendships` para refrescar la lista sin intervención
/// manual. Se abstrae para poder sustituirlo en las pruebas.
abstract interface class FriendsRealtime {
  void start(void Function() onChanged);

  void stop();
}

/// Implementación basada en Supabase Realtime.
class SupabaseFriendsRealtime implements FriendsRealtime {
  SupabaseFriendsRealtime([this._client]);

  final SupabaseClient? _client;
  RealtimeChannel? _channel;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  @override
  void start(void Function() onChanged) {
    stop();
    final RealtimeChannel channel = _supabase.channel(
      'friendships-${DateTime.now().microsecondsSinceEpoch}',
    );
    _channel = channel;
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendships',
          callback: (PostgresChangePayload payload) => onChanged(),
        )
        .subscribe();
    debugPrint('Friends realtime: escuchando cambios de amistades.');
  }

  @override
  void stop() {
    final RealtimeChannel? channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(channel.unsubscribe());
      debugPrint('Friends realtime: suscripción cerrada.');
    }
  }
}
