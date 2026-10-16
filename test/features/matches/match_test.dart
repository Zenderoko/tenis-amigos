import 'package:flutter_test/flutter_test.dart';
import 'package:tenis_amigos/features/matches/domain/match.dart';

void main() {
  group('MatchFormat', () {
    test('singles admite 2 jugadores y dobles 4', () {
      expect(MatchFormat.singles.maxPlayers, 2);
      expect(MatchFormat.doubles.maxPlayers, 4);
    });
  });

  group('Match', () {
    Match buildMatch({
      required MatchFormat format,
      required MatchStatus status,
      required List<MatchParticipant> participants,
    }) {
      return Match(
        id: 'test',
        format: format,
        startsAt: DateTime(2030, 1, 1, 19),
        durationMinutes: 90,
        locationName: 'Cancha de prueba',
        status: status,
        participants: participants,
      );
    }

    test('confirmedPlayers cuenta solo los aceptados', () {
      final Match match = buildMatch(
        format: MatchFormat.doubles,
        status: MatchStatus.awaitingPlayers,
        participants: const <MatchParticipant>[
          MatchParticipant(
            id: 'me',
            name: 'Yo',
            response: ParticipantResponse.accepted,
          ),
          MatchParticipant(
            id: 'u2',
            name: 'Amigo',
            response: ParticipantResponse.invited,
          ),
          MatchParticipant(
            id: 'u3',
            name: 'Otro',
            response: ParticipantResponse.declined,
          ),
        ],
      );

      expect(match.confirmedPlayers, 1);
      expect(match.requiredPlayers, 4);
      expect(match.isFull, isFalse);
    });

    test('isFull es true cuando se completan las plazas', () {
      final Match match = buildMatch(
        format: MatchFormat.singles,
        status: MatchStatus.confirmed,
        participants: const <MatchParticipant>[
          MatchParticipant(
            id: 'me',
            name: 'Yo',
            response: ParticipantResponse.accepted,
          ),
          MatchParticipant(
            id: 'u2',
            name: 'Amigo',
            response: ParticipantResponse.accepted,
          ),
        ],
      );

      expect(match.isFull, isTrue);
    });

    test('hasPendingInvitationFor detecta invitaciones sin responder', () {
      final Match match = buildMatch(
        format: MatchFormat.singles,
        status: MatchStatus.awaitingPlayers,
        participants: const <MatchParticipant>[
          MatchParticipant(
            id: 'u5',
            name: 'Organizador',
            isOrganizer: true,
            response: ParticipantResponse.accepted,
          ),
          MatchParticipant(
            id: 'me',
            name: 'Yo',
            response: ParticipantResponse.invited,
          ),
        ],
      );

      expect(match.hasPendingInvitationFor('me'), isTrue);
      expect(match.hasPendingInvitationFor('u5'), isFalse);
    });

    test('isActive es falso para partidos cancelados o finalizados', () {
      final Match cancelled = buildMatch(
        format: MatchFormat.singles,
        status: MatchStatus.cancelled,
        participants: const <MatchParticipant>[],
      );
      expect(cancelled.isActive, isFalse);

      final Match completed = buildMatch(
        format: MatchFormat.singles,
        status: MatchStatus.completed,
        participants: const <MatchParticipant>[],
      );
      expect(completed.isActive, isFalse);
    });
  });
}
