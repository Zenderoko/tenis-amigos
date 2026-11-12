import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/match_repository.dart';
import '../data/matches_realtime.dart';
import '../data/supabase_match_repository.dart';
import '../domain/match.dart';

/// Repositorio de partidos respaldado por Supabase.
final Provider<MatchRepository> matchRepositoryProvider =
    Provider<MatchRepository>((Ref ref) => const SupabaseMatchRepository());

/// Escucha cambios remotos para mantener los partidos sincronizados.
final Provider<MatchesRealtime> matchesRealtimeProvider =
    Provider<MatchesRealtime>((Ref ref) => SupabaseMatchesRealtime());

/// Lista de partidos del usuario actual.
final AsyncNotifierProvider<MatchesNotifier, List<Match>> matchesProvider =
    AsyncNotifierProvider<MatchesNotifier, List<Match>>(MatchesNotifier.new);

class MatchesNotifier extends AsyncNotifier<List<Match>> {
  MatchRepository get _repository => ref.read(matchRepositoryProvider);

  @override
  Future<List<Match>> build() async {
    final AuthUser? user = await ref.watch(authControllerProvider.future);
    if (user == null) {
      throw const AppFailure(
        'No hay una sesión activa. Inicia sesión para ver tus partidos.',
        code: 'no_active_session',
      );
    }

    final MatchesRealtime realtime = ref.watch(matchesRealtimeProvider);
    bool active = true;
    try {
      realtime.start(() {
        if (active) {
          unawaited(_reload());
        }
      });
    } catch (error) {
      debugPrint('Matches realtime unavailable: $error');
    }
    ref.onDispose(() {
      active = false;
      realtime.stop();
    });

    return _repository.fetchMatches();
  }

  Future<String> createMatch({
    required MatchFormat format,
    required DateTime startsAtUtc,
    required String timezone,
    required int durationMinutes,
    required String locationName,
    String? locationDetails,
    required List<String> inviteeIds,
  }) async {
    final String matchId = await _repository.createMatch(
      format: format,
      startsAtUtc: startsAtUtc,
      timezone: timezone,
      durationMinutes: durationMinutes,
      locationName: locationName,
      locationDetails: locationDetails,
      inviteeIds: inviteeIds,
    );
    await _reload();
    return matchId;
  }

  Future<void> respondToInvitation({
    required String matchId,
    required bool accept,
  }) async {
    await _repository.respondToInvitation(matchId: matchId, accept: accept);
    await _reload();
  }

  Future<void> invitePlayers({
    required String matchId,
    required List<String> inviteeIds,
  }) async {
    await _repository.invitePlayers(matchId: matchId, inviteeIds: inviteeIds);
    await _reload();
  }

  Future<void> cancelMatch(String matchId) async {
    await _repository.cancelMatch(matchId);
    await _reload();
  }

  Future<void> withdrawFromMatch(String matchId) async {
    await _repository.withdrawFromMatch(matchId);
    await _reload();
  }

  Future<void> removePlayer({
    required String matchId,
    required String playerId,
  }) async {
    await _repository.removeMatchPlayer(
      matchId: matchId,
      playerId: playerId,
    );
    await _reload();
  }

  Future<void> proposeReschedule({
    required String matchId,
    required DateTime startsAtUtc,
    required String timezone,
  }) async {
    await _repository.proposeReschedule(
      matchId: matchId,
      startsAtUtc: startsAtUtc,
      timezone: timezone,
    );
    await _reload();
  }

  Future<void> respondToReschedule({
    required String proposalId,
    required bool accept,
  }) async {
    await _repository.respondToReschedule(
      proposalId: proposalId,
      accept: accept,
    );
    await _reload();
  }

  Future<void> cancelReschedule(String proposalId) async {
    await _repository.cancelReschedule(proposalId);
    await _reload();
  }

  Future<void> refresh() => _reload();

  Future<void> _reload() async {
    state = await AsyncValue.guard(_repository.fetchMatches);
  }
}

/// Detalle de un partido. Se recarga cuando cambia la lista o por Realtime.
final matchByIdProvider = FutureProvider.family<Match?, String>((
  Ref ref,
  String id,
) async {
  ref.watch(matchesProvider);
  return ref.watch(matchRepositoryProvider).fetchMatchById(id);
});
