import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Escucha cambios de partidos e invitaciones para refrescar la interfaz.
abstract interface class MatchesRealtime {
  void start(void Function() onChanged);

  void stop();
}

/// Implementación basada en Supabase Realtime.
class SupabaseMatchesRealtime implements MatchesRealtime {
  SupabaseMatchesRealtime([this._client]);

  final SupabaseClient? _client;
  RealtimeChannel? _channel;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  @override
  void start(void Function() onChanged) {
    stop();
    final RealtimeChannel channel = _supabase.channel(
      'matches-${DateTime.now().microsecondsSinceEpoch}',
    );
    _channel = channel;
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'matches',
          callback: (PostgresChangePayload payload) => onChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'match_participants',
          callback: (PostgresChangePayload payload) => onChanged(),
        )
        .subscribe();
    debugPrint('Matches realtime: escuchando partidos e invitaciones.');
  }

  @override
  void stop() {
    final RealtimeChannel? channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(channel.unsubscribe());
      debugPrint('Matches realtime: suscripción cerrada.');
    }
  }
}
