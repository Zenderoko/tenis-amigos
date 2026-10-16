import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/prototype_banner.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/match.dart';
import 'matches_providers.dart';
import 'widgets/match_status_badge.dart';

/// Detalle de un partido. Punto de entrada de la creación/reprogramación y
/// del historial en etapas posteriores.
class MatchDetailScreen extends ConsumerWidget {
  const MatchDetailScreen({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Match?> match = ref.watch(matchByIdProvider(matchId));

    return Scaffold(
      appBar: AppBar(title: const Text('Partido')),
      body: match.when(
        loading: () => const LoadingView(message: 'Cargando el partido…'),
        error: (Object error, StackTrace stack) => ErrorView(
          message: 'No pudimos cargar el partido.',
          onRetry: () => ref.invalidate(matchByIdProvider(matchId)),
        ),
        data: (Match? data) => data == null
            ? const EmptyView(
                title: 'Partido no encontrado',
                message: 'Es posible que el partido ya no exista.',
                icon: Icons.search_off,
              )
            : _MatchDetail(match: data),
      ),
    );
  }
}

class _MatchDetail extends StatelessWidget {
  const _MatchDetail({required this.match});

  final Match match;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isOrganizer = match.participants.any(
      (MatchParticipant p) => p.id == kMockCurrentUserId && p.isOrganizer,
    );
    final bool canRespond = match.hasPendingInvitationFor(kMockCurrentUserId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        const PrototypeBanner(),
        const SizedBox(height: 20),
        _DetailHeader(match: match),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Jugadores'),
        Card(
          child: Column(
            children: <Widget>[
              for (int i = 0; i < match.participants.length; i++) ...<Widget>[
                _ParticipantRow(participant: match.participants[i]),
                if (i < match.participants.length - 1)
                  const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Historial'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: match.events.isEmpty
                ? Text(
                    'El historial de eventos estará disponible en la Etapa 5.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    children: <Widget>[
                      for (final MatchEvent event in match.events)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history),
                          title: Text(event.type.label),
                          subtitle: Text(event.description),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 24),
        if (canRespond) ...<Widget>[
          FilledButton.icon(
            onPressed: () => _mock(context, 'Respuesta "Aceptar" (prototipo).'),
            icon: const Icon(Icons.check),
            label: const Text('Aceptar invitación'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () =>
                _mock(context, 'Respuesta "Rechazar" (prototipo).'),
            icon: const Icon(Icons.close),
            label: const Text('Rechazar invitación'),
          ),
        ] else if (isOrganizer && match.isActive) ...<Widget>[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            onPressed: () => _mock(
              context,
              'Cancelar el partido estará disponible en la Etapa 5.',
            ),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancelar partido'),
          ),
        ],
      ],
    );
  }

  void _mock(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.match});

  final Match match;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.sports_tennis, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  match.format.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                MatchStatusBadge(status: match.status),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.event,
              text: AppDateFormatters.capitalize(
                AppDateFormatters.fullDate(match.startsAt),
              ),
            ),
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.schedule,
              text:
                  '${AppDateFormatters.timeRange(match.startsAt, match.durationMinutes)} '
                  '(${match.durationMinutes} min)',
            ),
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.place_outlined,
              text: match.locationDetails == null
                  ? match.locationName
                  : '${match.locationName} · ${match.locationDetails}',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: theme.textTheme.bodyLarge),
        ),
      ],
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({required this.participant});

  final MatchParticipant participant;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: InitialsAvatar(name: participant.name),
      title: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              participant.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (participant.isOrganizer) ...<Widget>[
            const SizedBox(width: 8),
            Icon(
              Icons.star,
              size: 16,
              color: theme.colorScheme.tertiary,
            ),
          ],
        ],
      ),
      subtitle: participant.isOrganizer ? const Text('Organizador') : null,
      trailing: _ResponseChip(response: participant.response),
    );
  }
}

class _ResponseChip extends StatelessWidget {
  const _ResponseChip({required this.response});

  final ParticipantResponse response;

  Color get _color => switch (response) {
    ParticipantResponse.accepted => AppColors.statusConfirmed,
    ParticipantResponse.invited => AppColors.statusPending,
    ParticipantResponse.declined => AppColors.statusCancelled,
    ParticipantResponse.withdrawn => AppColors.statusCancelled,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        response.label,
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
