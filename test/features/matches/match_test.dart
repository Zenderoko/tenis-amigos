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

    test('calcula plazas activas, pendientes y libres', () {
      final Match match = buildMatch(
        format: MatchFormat.doubles,
        status: MatchStatus.awaitingPlayers,
        participants: const <MatchParticipant>[
          MatchParticipant(
            id: 'me',
            name: 'Yo',
            isOrganizer: true,
            response: ParticipantResponse.accepted,
          ),
          MatchParticipant(
            id: 'u2',
            name: 'Invitado',
            response: ParticipantResponse.invited,
          ),
          MatchParticipant(
            id: 'u3',
            name: 'Rechazó',
            response: ParticipantResponse.declined,
          ),
        ],
      );

      expect(match.activePlayers, 2);
      expect(match.pendingPlayers, 1);
      expect(match.availableSlots, 2);
      expect(match.organizer?.id, 'me');
    });

    test('canRespond solo permite responder invitaciones pendientes', () {
      final Match match = buildMatch(
        format: MatchFormat.singles,
        status: MatchStatus.awaitingPlayers,
        participants: const <MatchParticipant>[
          MatchParticipant(
            id: 'u1',
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

      expect(match.canRespond('me'), isTrue);
      expect(match.canRespond('u1'), isFalse);
      expect(match.isOrganizer('u1'), isTrue);
      expect(match.isParticipant('u2'), isFalse);
    });
  });

  group('Valores de base de datos', () {
    test('convierte los valores almacenados en Supabase', () {
      expect(MatchFormat.fromValue('doubles'), MatchFormat.doubles);
      expect(MatchStatus.fromValue('confirmed'), MatchStatus.confirmed);
      expect(
        ParticipantResponse.fromValue('declined'),
        ParticipantResponse.declined,
      );
      expect(MatchEventType.fromValue('responded'), MatchEventType.responded);
    });

    test('usa valores seguros ante datos desconocidos', () {
      expect(MatchFormat.fromValue('desconocido'), MatchFormat.singles);
      expect(MatchStatus.fromValue('desconocido'), MatchStatus.awaitingPlayers);
      expect(
        ParticipantResponse.fromValue('desconocido'),
        ParticipantResponse.invited,
      );
      expect(MatchEventType.fromValue('desconocido'), MatchEventType.created);
    });
  });
}
