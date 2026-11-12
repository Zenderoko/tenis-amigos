import '../domain/match.dart';

/// Contrato de acceso a partidos.
abstract interface class MatchRepository {
  Future<List<Match>> fetchMatches();

  Future<Match?> fetchMatchById(String id);

  Future<String> createMatch({
    required MatchFormat format,
    required DateTime startsAtUtc,
    required String timezone,
    required int durationMinutes,
    required String locationName,
    String? locationDetails,
    required List<String> inviteeIds,
  });

  Future<void> respondToInvitation({
    required String matchId,
    required bool accept,
  });

  Future<void> invitePlayers({
    required String matchId,
    required List<String> inviteeIds,
  });

  Future<void> cancelMatch(String matchId);

  Future<void> withdrawFromMatch(String matchId);

  Future<void> removeMatchPlayer({
    required String matchId,
    required String playerId,
  });

  Future<void> proposeReschedule({
    required String matchId,
    required DateTime startsAtUtc,
    required String timezone,
  });

  Future<void> respondToReschedule({
    required String proposalId,
    required bool accept,
  });

  Future<void> cancelReschedule(String proposalId);
}
