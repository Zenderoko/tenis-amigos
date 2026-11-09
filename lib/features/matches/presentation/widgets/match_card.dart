import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/date_formatters.dart';
import '../../../../core/utils/match_time.dart';
import '../../../../core/widgets/initials_avatar.dart';
import '../../domain/match.dart';
import 'match_status_badge.dart';

/// Tarjeta resumen de un partido. Se reutiliza en Inicio, Invitaciones y
/// Calendario.
class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, this.onTap, this.footer});

  final Match match;
  final VoidCallback? onTap;

  /// Acciones opcionales que se muestran al pie de la tarjeta.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime localStart = MatchTime.inZone(
      match.startsAt,
      match.timezone,
    );
    final String when =
        '${AppDateFormatters.capitalize(AppDateFormatters.weekdayDayMonth(localStart))} · '
        '${AppDateFormatters.timeRange(localStart, match.durationMinutes)}';

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
                  _CapacityChip(match: match),
                ],
              ),
              if (footer != null) ...<Widget>[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CapacityChip extends StatelessWidget {
  const _CapacityChip({required this.match});

  final Match match;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    if (match.isFull) {
      label = 'Cupo completo';
      color = AppColors.statusConfirmed;
    } else if (!match.isActive) {
      label = '${match.confirmedPlayers}/${match.requiredPlayers} jugadores';
      color = AppColors.statusCompleted;
    } else if (match.pendingPlayers > 0) {
      label =
          '${match.pendingPlayers} '
          '${match.pendingPlayers == 1 ? 'pendiente' : 'pendientes'}';
      color = AppColors.statusPending;
    } else {
      label = 'Faltan ${match.availableSlots}';
      color = AppColors.clay;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
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
                  imageUrl: shown[i].avatarUrl,
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
