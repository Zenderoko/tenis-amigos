import '../../../core/constants/mock_data.dart';
import '../domain/match.dart';

/// Repositorio de partidos con datos FICTICIOS, solo para prototipos visuales.
///
/// NO representa datos reales del backend. Se reemplazará por una
/// implementación contra Supabase en la Etapa 4 (con la misma interfaz
/// pública: [fetchMatches] y [fetchMatchById]).
class MockMatchRepository {
  const MockMatchRepository();

  /// Simula una llamada de red devolviendo la lista de partidos.
  Future<List<Match>> fetchMatches() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return _buildMatches();
  }

  /// Simula la carga del detalle de un partido por su identificador.
  Future<Match?> fetchMatchById(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final List<Match> matches = _buildMatches();
    for (final Match match in matches) {
      if (match.id == id) return match;
    }
    return null;
  }

  List<Match> _buildMatches() {
    final DateTime now = DateTime.now();

    DateTime atTime(DateTime day, int hour, int minute) =>
        DateTime(day.year, day.month, day.day, hour, minute);

    final DateTime today = DateTime(now.year, now.month, now.day);

    return <Match>[
      Match(
        id: 'm1',
        format: MatchFormat.doubles,
        startsAt: atTime(today.add(const Duration(days: 1)), 19, 0),
        durationMinutes: 90,
        locationName: 'Club de Tenis Providencia',
        locationDetails: 'Cancha 3 · arcilla',
        status: MatchStatus.confirmed,
        participants: <MatchParticipant>[
          const MatchParticipant(
            id: kMockCurrentUserId,
            name: kMockCurrentUserName,
            isOrganizer: true,
            response: ParticipantResponse.accepted,
          ),
          const MatchParticipant(
            id: 'u2',
            name: 'Camila Rojas',
            response: ParticipantResponse.accepted,
          ),
          const MatchParticipant(
            id: 'u3',
            name: 'Matías Fuentes',
            response: ParticipantResponse.accepted,
          ),
          const MatchParticipant(
            id: 'u4',
            name: 'Josefa Herrera',
            response: ParticipantResponse.accepted,
          ),
        ],
      ),
      Match(
        id: 'm2',
        format: MatchFormat.singles,
        startsAt: atTime(today.add(const Duration(days: 3)), 9, 30),
        durationMinutes: 60,
        locationName: 'Canchas Municipales Ñuñoa',
        locationDetails: 'Cancha 1 · cemento',
        status: MatchStatus.awaitingPlayers,
        participants: <MatchParticipant>[
          const MatchParticipant(
            id: 'u5',
            name: 'Diego Soto',
            isOrganizer: true,
            response: ParticipantResponse.accepted,
          ),
          const MatchParticipant(
            id: kMockCurrentUserId,
            name: kMockCurrentUserName,
            response: ParticipantResponse.invited,
          ),
        ],
      ),
      Match(
        id: 'm3',
        format: MatchFormat.doubles,
        startsAt: atTime(today.add(const Duration(days: 5)), 20, 0),
        durationMinutes: 120,
        locationName: 'Estadio Español',
        locationDetails: 'Cancha 5 · arcilla',
        status: MatchStatus.awaitingPlayers,
        participants: <MatchParticipant>[
          const MatchParticipant(
            id: kMockCurrentUserId,
            name: kMockCurrentUserName,
            isOrganizer: true,
            response: ParticipantResponse.accepted,
          ),
          const MatchParticipant(
            id: 'u3',
            name: 'Matías Fuentes',
            response: ParticipantResponse.accepted,
          ),
          const MatchParticipant(
            id: 'u6',
            name: 'Valentina Paz',
            response: ParticipantResponse.invited,
          ),
        ],
      ),
      Match(
        id: 'm4',
        format: MatchFormat.singles,
        startsAt: atTime(today.add(const Duration(days: 8)), 18, 0),
        durationMinutes: 60,
        locationName: 'Club de Tenis Providencia',
        status: MatchStatus.awaitingPlayers,
        participants: <MatchParticipant>[
          const MatchParticipant(
            id: 'u2',
            name: 'Camila Rojas',
            isOrganizer: true,
            response: ParticipantResponse.accepted,
          ),
          const MatchParticipant(
            id: kMockCurrentUserId,
            name: kMockCurrentUserName,
            response: ParticipantResponse.invited,
          ),
        ],
      ),
      Match(
        id: 'm5',
        format: MatchFormat.doubles,
        startsAt: atTime(today.subtract(const Duration(days: 2)), 19, 0),
        durationMinutes: 90,
        locationName: 'Canchas Municipales Ñuñoa',
        status: MatchStatus.cancelled,
        participants: <MatchParticipant>[
          const MatchParticipant(
            id: kMockCurrentUserId,
            name: kMockCurrentUserName,
            isOrganizer: true,
            response: ParticipantResponse.accepted,
          ),
          const MatchParticipant(
            id: 'u4',
            name: 'Josefa Herrera',
            response: ParticipantResponse.declined,
          ),
        ],
      ),
      Match(
        id: 'm6',
        format: MatchFormat.singles,
        startsAt: atTime(today.subtract(const Duration(days: 7)), 20, 30),
        durationMinutes: 75,
        locationName: 'Estadio Español',
        status: MatchStatus.completed,
        participants: <MatchParticipant>[
          const MatchParticipant(
            id: kMockCurrentUserId,
            name: kMockCurrentUserName,
            isOrganizer: true,
            response: ParticipantResponse.accepted,
          ),
          const MatchParticipant(
            id: 'u5',
            name: 'Diego Soto',
            response: ParticipantResponse.accepted,
          ),
        ],
      ),
    ];
  }
}
