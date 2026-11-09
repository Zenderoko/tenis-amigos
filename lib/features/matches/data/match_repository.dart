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
}
