import 'package:flutter/material.dart';

import '../../../../core/utils/date_formatters.dart';
import '../../../../core/widgets/initials_avatar.dart';
import '../../domain/match.dart';
import 'match_status_badge.dart';

/// Tarjeta resumen de un partido. Se reutiliza en Inicio y Calendario.
class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, this.onTap});

  final Match match;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String when =
        '${AppDateFormatters.capitalize(AppDateFormatters.weekdayDayMonth(match.startsAt))} · '
        '${AppDateFormatters.timeRange(match.startsAt, match.durationMinutes)}';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.sports_tennis,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    match.format.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  MatchStatusBadge(status: match.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                when,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      match.locationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(child: _ParticipantAvatars(match: match)),
                  Text(
                    '${match.confirmedPlayers}/${match.requiredPlayers} jugadores',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantAvatars extends StatelessWidget {
  const _ParticipantAvatars({required this.match});

  final Match match;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<MatchParticipant> shown = match.participants.take(4).toList();
    const double size = 28;
    const double overlap = 10;

    return SizedBox(
      height: size,
      child: Stack(
        children: <Widget>[
          for (int i = 0; i < shown.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: InitialsAvatar(
                  name: shown[i].name,
                  radius: (size - 4) / 2,
                  color: shown[i].response == ParticipantResponse.accepted
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
