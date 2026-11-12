import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../profile/domain/tennis_level.dart';
import '../domain/match.dart';
import 'match_repository.dart';

/// Implementación de partidos respaldada por Supabase.
class SupabaseMatchRepository implements MatchRepository {
  const SupabaseMatchRepository([this._client]);

  static const String _matchColumns =
      'id, organizer_id, format, starts_at, timezone, duration_minutes, '
      'location_name, location_details, status, version';

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
  Future<List<Match>> fetchMatches() async {
    try {
      final List<Map<String, dynamic>> rows = await _supabase
          .from('matches')
          .select(_matchColumns)
          .order('starts_at', ascending: true);

      if (rows.isEmpty) {
        return const <Match>[];
      }

      final List<String> matchIds = rows
          .map((Map<String, dynamic> row) => row['id'] as String)
          .toList();

      final List<Map<String, dynamic>> participantRows = await _supabase
          .from('match_participants')
          .select('match_id, user_id, role, response')
          .inFilter('match_id', matchIds);

      final Map<String, List<Map<String, dynamic>>> byMatch =
          <String, List<Map<String, dynamic>>>{};
      final Set<String> profileIds = <String>{};
      for (final Map<String, dynamic> row in participantRows) {
        final String? matchId = row['match_id'] as String?;
        final String? userId = row['user_id'] as String?;
        if (matchId == null || userId == null) {
          continue;
        }
        byMatch.putIfAbsent(matchId, () => <Map<String, dynamic>>[]).add(row);
        profileIds.add(userId);
      }

      final Map<String, Map<String, dynamic>> profiles = await _fetchProfiles(
        profileIds,
      );

      final Map<String, MatchProposal> proposals =
          await _fetchPendingProposals(matchIds);

      return rows
          .map(
            (Map<String, dynamic> row) => _matchFromRow(
              row,
              byMatch[row['id']] ?? const <Map<String, dynamic>>[],
              profiles,
              pendingProposal: proposals[row['id']],
            ),
          )
          .toList();
    } on PostgrestException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<Match?> fetchMatchById(String id) async {
    try {
      final Map<String, dynamic>? row = await _supabase
          .from('matches')
          .select(_matchColumns)
          .eq('id', id)
          .maybeSingle();

      if (row == null) {
        return null;
      }

      final List<Map<String, dynamic>> participantRows = await _supabase
          .from('match_participants')
          .select('match_id, user_id, role, response')
          .eq('match_id', id);

      final Set<String> profileIds = participantRows
          .map((Map<String, dynamic> row) => row['user_id'] as String?)
          .whereType<String>()
          .toSet();
      final Map<String, Map<String, dynamic>> profiles = await _fetchProfiles(
        profileIds,
      );

      final List<Map<String, dynamic>> eventRows = await _supabase
          .from('match_events')
          .select('type, description, created_at')
          .eq('match_id', id)
          .order('created_at', ascending: true);

      final List<MatchEvent> events = eventRows.map((Map<String, dynamic> row) {
        final DateTime at =
            DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ??
            DateTime.now();
        return MatchEvent(
          type: MatchEventType.fromValue(row['type'] as String?),
          at: at,
          description: row['description'] as String? ?? '',
        );
      }).toList();

      final Map<String, MatchProposal> proposals = await _fetchPendingProposals(
        <String>[id],
      );

      return _matchFromRow(
        row,
        participantRows,
        profiles,
        events: events,
        pendingProposal: proposals[id],
      );
    } on PostgrestException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<String> createMatch({
    required MatchFormat format,
    required DateTime startsAtUtc,
    required String timezone,
    required int durationMinutes,
    required String locationName,
    String? locationDetails,
    required List<String> inviteeIds,
  }) async {
    try {
      final dynamic response = await _supabase.rpc(
        'create_match',
        params: <String, dynamic>{
          'p_format': format.dbValue,
          'p_starts_at': startsAtUtc.toUtc().toIso8601String(),
          'p_timezone': timezone,
          'p_duration_minutes': durationMinutes,
          'p_location_name': locationName.trim(),
          'p_location_details': _optionalString(locationDetails),
          'p_invitee_ids': inviteeIds,
        },
      );
      final Map<String, dynamic> row = _firstRow(response);
      final String? matchId =
          (row['created_match_id'] ?? row['match_id']) as String?;
      if (matchId == null || matchId.isEmpty) {
        throw const AppFailure(
          'Supabase no devolvió el partido creado.',
          code: 'unexpected_create_match_response',
        );
      }
      return matchId;
    } on PostgrestException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<void> respondToInvitation({
    required String matchId,
    required bool accept,
  }) async {
    try {
      await _supabase.rpc(
        'respond_match_invitation',
        params: <String, dynamic>{'p_match_id': matchId, 'p_accept': accept},
      );
    } on PostgrestException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<void> invitePlayers({
    required String matchId,
    required List<String> inviteeIds,
  }) async {
    if (inviteeIds.isEmpty) {
      throw const AppFailure(
        'Selecciona al menos un jugador para invitar.',
        code: 'invitees_required',
      );
    }

    try {
      await _supabase.rpc(
        'invite_match_players',
        params: <String, dynamic>{
          'p_match_id': matchId,
          'p_invitee_ids': inviteeIds,
        },
      );
    } on PostgrestException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<void> cancelMatch(String matchId) async {
    try {
      await _supabase.rpc(
        'cancel_match',
        params: <String, dynamic>{'p_match_id': matchId},
      );
    } on PostgrestException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<void> withdrawFromMatch(String matchId) async {
    try {
      await _supabase.rpc(
        'withdraw_from_match',
        params: <String, dynamic>{'p_match_id': matchId},
      );
    } on PostgrestException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<void> removeMatchPlayer({
    required String matchId,
    required String playerId,
  }) async {
    try {
      await _supabase.rpc(
        'remove_match_player',
        params: <String, dynamic>{
          'p_match_id': matchId,
          'p_user_id': playerId,
        },
      );
    } on PostgrestException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<void> proposeReschedule({
    required String matchId,
    required DateTime startsAtUtc,
    required String timezone,
  }) async {
    try {
      await _supabase.rpc(
        'propose_reschedule',
        params: <String, dynamic>{
          'p_match_id': matchId,
          'p_starts_at': startsAtUtc.toUtc().toIso8601String(),
          'p_timezone': timezone,
        },
      );
    } on PostgrestException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<void> respondToReschedule({
    required String proposalId,
    required bool accept,
  }) async {
    try {
      await _supabase.rpc(
        'respond_reschedule',
        params: <String, dynamic>{
          'p_proposal_id': proposalId,
          'p_accept': accept,
        },
      );
    } on PostgrestException catch (error) {
      throw _failureFor(error);
    }
  }

  @override
  Future<void> cancelReschedule(String proposalId) async {
    try {
      await _supabase.rpc(
        'cancel_reschedule',
        params: <String, dynamic>{'p_proposal_id': proposalId},
      );
    } on PostgrestException catch (error) {
      throw _failureFor(error);
    }
  }

  Future<Map<String, MatchProposal>> _fetchPendingProposals(
    List<String> matchIds,
  ) async {
    if (matchIds.isEmpty) {
      return const <String, MatchProposal>{};
    }

    final List<Map<String, dynamic>> proposalRows = await _supabase
        .from('match_proposals')
        .select(
          'id, match_id, proposed_by, proposed_starts_at, '
          'proposed_timezone, status, created_at',
        )
        .inFilter('match_id', matchIds)
        .eq('status', 'pending');

    if (proposalRows.isEmpty) {
      return const <String, MatchProposal>{};
    }

    final List<String> proposalIds = proposalRows
        .map((Map<String, dynamic> row) => row['id'] as String)
        .toList();

    final List<Map<String, dynamic>> voteRows = await _supabase
        .from('match_proposal_votes')
        .select('proposal_id, user_id, response')
        .inFilter('proposal_id', proposalIds);

    final Map<String, List<MatchProposalVote>> votesByProposal =
        <String, List<MatchProposalVote>>{};
    for (final Map<String, dynamic> row in voteRows) {
      final String? proposalId = row['proposal_id'] as String?;
      final String? userId = row['user_id'] as String?;
      if (proposalId == null || userId == null) {
        continue;
      }
      votesByProposal
          .putIfAbsent(proposalId, () => <MatchProposalVote>[])
          .add(
            MatchProposalVote(
              userId: userId,
              accepted: row['response'] == 'accepted',
            ),
          );
    }

    final Map<String, MatchProposal> result = <String, MatchProposal>{};
    for (final Map<String, dynamic> row in proposalRows) {
      final String id = row['id'] as String;
      final String matchId = row['match_id'] as String;
      result[matchId] = MatchProposal(
        id: id,
        proposedBy: row['proposed_by'] as String? ?? '',
        proposedStartsAt:
            DateTime.tryParse(
              row['proposed_starts_at']?.toString() ?? '',
            )?.toUtc() ??
            DateTime.now().toUtc(),
        timezone:
            _optionalString(row['proposed_timezone']) ?? kDefaultMatchTimezone,
        status: MatchProposalStatus.fromValue(row['status'] as String?),
        createdAt:
            DateTime.tryParse(
              row['created_at']?.toString() ?? '',
            )?.toLocal() ??
            DateTime.now(),
        votes: votesByProposal[id] ?? const <MatchProposalVote>[],
      );
    }
    return result;
  }

  Future<Map<String, Map<String, dynamic>>> _fetchProfiles(
    Set<String> ids,
  ) async {
    if (ids.isEmpty) {
      return const <String, Map<String, dynamic>>{};
    }

    final List<Map<String, dynamic>> rows = await _supabase
        .from('profiles')
        .select('id, display_name, avatar_url, tennis_level')
        .inFilter('id', ids.toList());

    return <String, Map<String, dynamic>>{
      for (final Map<String, dynamic> row in rows) row['id'] as String: row,
    };
  }

  Match _matchFromRow(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> participantRows,
    Map<String, Map<String, dynamic>> profiles, {
    List<MatchEvent> events = const <MatchEvent>[],
    MatchProposal? pendingProposal,
  }) {
    final String organizerId = row['organizer_id'] as String? ?? '';
    final List<MatchParticipant> participants = participantRows.map((
      Map<String, dynamic> participantRow,
    ) {
      final String userId = participantRow['user_id'] as String;
      final Map<String, dynamic>? profile = profiles[userId];
      return MatchParticipant(
        id: userId,
        name: _optionalString(profile?['display_name']) ?? 'Jugador',
        avatarUrl: _optionalString(profile?['avatar_url']),
        tennisLevel: TennisLevel.fromValue(profile?['tennis_level'] as String?),
        isOrganizer:
            participantRow['role'] == 'organizer' || userId == organizerId,
        response: ParticipantResponse.fromValue(
          participantRow['response'] as String?,
        ),
      );
    }).toList()..sort(_compareParticipants);

    return Match(
      id: row['id'] as String,
      organizerId: organizerId,
      format: MatchFormat.fromValue(row['format'] as String?),
      startsAt:
          DateTime.tryParse(row['starts_at']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      timezone: _optionalString(row['timezone']) ?? kDefaultMatchTimezone,
      durationMinutes: (row['duration_minutes'] as num?)?.toInt() ?? 60,
      locationName: _optionalString(row['location_name']) ?? 'Cancha',
      locationDetails: _optionalString(row['location_details']),
      status: MatchStatus.fromValue(row['status'] as String?),
      participants: participants,
      events: events,
      pendingProposal: pendingProposal,
      version: (row['version'] as num?)?.toInt() ?? 1,
    );
  }

  int _compareParticipants(MatchParticipant a, MatchParticipant b) {
    final int byState = _participantRank(a).compareTo(_participantRank(b));
    if (byState != 0) {
      return byState;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  int _participantRank(MatchParticipant participant) {
    if (participant.isOrganizer) return 0;
    return switch (participant.response) {
      ParticipantResponse.accepted => 1,
      ParticipantResponse.invited => 2,
      ParticipantResponse.declined => 3,
      ParticipantResponse.withdrawn => 4,
      ParticipantResponse.removed => 5,
    };
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
    debugPrint('Match error: ${error.code} ${error.message}');
    final String message = error.message.toLowerCase();

    if (error.code == '42P01' || message.contains('could not find the table')) {
      return const AppFailure(
        'No encontramos las tablas de partidos. Aplica las migraciones de '
        'Supabase.',
        code: 'matches_table_missing',
      );
    }
    if (error.code == '42883' ||
        error.code == 'PGRST202' ||
        message.contains('could not find the function') ||
        message.contains('schema cache')) {
      return const AppFailure(
        'Falta aplicar la migración de partidos en Supabase.',
        code: 'matches_function_missing',
      );
    }
    if (message.contains('not_authenticated')) {
      return const AppFailure(
        'Tu sesión expiró. Inicia sesión de nuevo.',
        code: 'not_authenticated',
      );
    }
    if (message.contains('invitee_not_friend')) {
      return const AppFailure(
        'Solo puedes invitar a tus amistades aceptadas.',
        code: 'invitee_not_friend',
      );
    }
    if (message.contains('cannot_invite_self')) {
      return const AppFailure(
        'No puedes invitarte a tu propio partido.',
        code: 'cannot_invite_self',
      );
    }
    if (message.contains('duplicate_invitee')) {
      return const AppFailure(
        'Hay jugadores repetidos en la invitación.',
        code: 'duplicate_invitee',
      );
    }
    if (message.contains('invalid_invitee')) {
      return const AppFailure(
        'Uno de los jugadores seleccionados no es válido.',
        code: 'invalid_invitee',
      );
    }
    if (message.contains('invitees_required')) {
      return const AppFailure(
        'Selecciona al menos un jugador para invitar.',
        code: 'invitees_required',
      );
    }
    if (message.contains('invitee_already_in_match')) {
      return const AppFailure(
        'Uno de los jugadores ya está en el partido. Actualiza la lista.',
        code: 'invitee_already_in_match',
      );
    }
    if (message.contains('too_many_players')) {
      return const AppFailure(
        'No quedan plazas suficientes para esos jugadores.',
        code: 'too_many_players',
      );
    }
    if (message.contains('not_organizer')) {
      return const AppFailure(
        'Solo el organizador puede realizar esta acción.',
        code: 'not_organizer',
      );
    }
    if (message.contains('invitation_not_found')) {
      return const AppFailure(
        'No encontramos tu invitación. Actualiza el partido.',
        code: 'invitation_not_found',
      );
    }
    if (message.contains('invitation_not_pending')) {
      return const AppFailure(
        'La invitación ya fue respondida. Actualiza el partido.',
        code: 'invitation_not_pending',
      );
    }
    if (message.contains('match_not_found')) {
      return const AppFailure(
        'El partido ya no existe o no tienes acceso a él.',
        code: 'match_not_found',
      );
    }
    if (message.contains('match_not_active')) {
      return const AppFailure(
        'El partido ya no está activo.',
        code: 'match_not_active',
      );
    }
    if (message.contains('invalid_start_time')) {
      return const AppFailure(
        'La fecha y la hora deben ser posteriores a ahora.',
        code: 'invalid_start_time',
      );
    }
    if (message.contains('invalid_duration')) {
      return const AppFailure(
        'La duración seleccionada no es válida.',
        code: 'invalid_duration',
      );
    }
    if (message.contains('invalid_location')) {
      return const AppFailure(
        'Indica el lugar del partido.',
        code: 'invalid_location',
      );
    }
    if (message.contains('invalid_timezone')) {
      return const AppFailure(
        'La zona horaria del partido no es válida.',
        code: 'invalid_timezone',
      );
    }
    if (message.contains('invalid_format')) {
      return const AppFailure(
        'La modalidad del partido no es válida.',
        code: 'invalid_format',
      );
    }
    if (message.contains('invalid_response')) {
      return const AppFailure(
        'La respuesta no es válida.',
        code: 'invalid_response',
      );
    }
    if (message.contains('cannot_withdraw_organizer')) {
      return const AppFailure(
        'El organizador no puede retirarse: puede cancelar el partido.',
        code: 'cannot_withdraw_organizer',
      );
    }
    if (message.contains('withdraw_not_allowed')) {
      return const AppFailure(
        'Solo puedes retirarte si ya confirmaste tu asistencia.',
        code: 'withdraw_not_allowed',
      );
    }
    if (message.contains('cannot_remove_self')) {
      return const AppFailure(
        'No puedes eliminarte a ti mismo: para eso cancela el partido.',
        code: 'cannot_remove_self',
      );
    }
    if (message.contains('participant_not_found')) {
      return const AppFailure(
        'Ese jugador ya no está en el partido. Actualiza la lista.',
        code: 'participant_not_found',
      );
    }
    if (message.contains('player_not_removable')) {
      return const AppFailure(
        'Solo puedes eliminar a jugadores invitados o confirmados.',
        code: 'player_not_removable',
      );
    }
    if (message.contains('invalid_player')) {
      return const AppFailure(
        'El jugador seleccionado no es válido.',
        code: 'invalid_player',
      );
    }
    if (message.contains('proposal_not_found')) {
      return const AppFailure(
        'La propuesta ya no existe o no tienes acceso a ella.',
        code: 'proposal_not_found',
      );
    }
    if (message.contains('proposal_not_pending')) {
      return const AppFailure(
        'La propuesta ya fue resuelta. Actualiza el partido.',
        code: 'proposal_not_pending',
      );
    }
    if (message.contains('cannot_vote_own_proposal')) {
      return const AppFailure(
        'Quien propone el cambio no vota su propia propuesta.',
        code: 'cannot_vote_own_proposal',
      );
    }
    if (message.contains('not_accepted_participant')) {
      return const AppFailure(
        'Solo los jugadores confirmados pueden responder la propuesta.',
        code: 'not_accepted_participant',
      );
    }
    if (error.code == '23505') {
      return const AppFailure(
        'Ese jugador ya está en el partido. Actualiza la lista.',
        code: 'match_participant_duplicate',
      );
    }
    if (error.code == '42501') {
      return const AppFailure(
        'No tienes permisos para realizar esta acción.',
        code: 'match_permission_denied',
      );
    }
    if (error.code == 'P0001') {
      return const AppFailure(
        'No pudimos actualizar el partido. Actualiza e intenta de nuevo.',
        code: 'match_conflict',
      );
    }

    return const AppFailure(
      'No pudimos completar la acción. Intenta de nuevo.',
      code: 'match_error',
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
