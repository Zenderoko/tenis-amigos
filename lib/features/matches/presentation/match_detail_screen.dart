import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/utils/match_time.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/match.dart';
import 'matches_providers.dart';
import 'widgets/friend_picker_sheet.dart';
import 'widgets/match_status_badge.dart';

/// Detalle de un partido con acciones para responder e invitar jugadores.
class MatchDetailScreen extends ConsumerWidget {
  const MatchDetailScreen({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Match?> match = ref.watch(matchByIdProvider(matchId));
    final AuthUser? user = ref.watch(authControllerProvider).value;

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
            : _MatchDetail(match: data, currentUserId: user?.id),
      ),
    );
  }
}

class _MatchDetail extends ConsumerStatefulWidget {
  const _MatchDetail({required this.match, required this.currentUserId});

  final Match match;
  final String? currentUserId;

  @override
  ConsumerState<_MatchDetail> createState() => _MatchDetailState();
}

class _MatchDetailState extends ConsumerState<_MatchDetail> {
  bool _responding = false;
  bool _inviting = false;

  Match get match => widget.match;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? userId = widget.currentUserId;
    final bool isOrganizer = userId != null && match.isOrganizer(userId);
    final bool canRespond = userId != null && match.canRespond(userId);
    final bool canInvite =
        isOrganizer && match.isActive && match.availableSlots > 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        _DetailHeader(match: match),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Jugadores'),
        Card(
          child: Column(
            children: <Widget>[
              for (int i = 0; i < match.participants.length; i++) ...<Widget>[
                _ParticipantRow(
                  participant: match.participants[i],
                  isCurrentUser:
                      match.participants[i].id == widget.currentUserId,
                ),
                if (i < match.participants.length - 1) const Divider(height: 1),
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
                    'Todavía no hay eventos registrados.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    children: <Widget>[
                      for (int i = 0; i < match.events.length; i++) ...<Widget>[
                        _EventRow(event: match.events[i]),
                        if (i < match.events.length - 1)
                          const Divider(height: 24),
                      ],
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 24),
        if (canRespond) ...<Widget>[
          FilledButton.icon(
            onPressed: _responding ? null : () => _respond(accept: true),
            icon: _responding
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_responding ? 'Respondiendo…' : 'Aceptar invitación'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _responding ? null : () => _respond(accept: false),
            icon: const Icon(Icons.close),
            label: const Text('Rechazar invitación'),
          ),
        ] else if (canInvite) ...<Widget>[
          OutlinedButton.icon(
            onPressed: _inviting ? null : _invitePlayers,
            icon: _inviting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_alt_1_outlined),
            label: Text(_inviting ? 'Invitando…' : 'Invitar jugadores'),
          ),
        ] else if (isOrganizer && match.isActive && match.isFull) ...<Widget>[
          Text(
            'El partido está completo.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _respond({required bool accept}) async {
    setState(() => _responding = true);
    try {
      await ref
          .read(matchesProvider.notifier)
          .respondToInvitation(matchId: match.id, accept: accept);
      _showMessage(
        accept
            ? 'Aceptaste la invitación al partido.'
            : 'Rechazaste la invitación al partido.',
      );
    } on AppFailure catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('No pudimos enviar tu respuesta. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _responding = false);
    }
  }

  Future<void> _invitePlayers() async {
    final Set<String> excludedIds = match.participants
        .where(
          (MatchParticipant participant) =>
              participant.response == ParticipantResponse.accepted ||
              participant.response == ParticipantResponse.invited,
        )
        .map((MatchParticipant participant) => participant.id)
        .toSet();

    final List<String>? selected = await showFriendPickerSheet(
      context: context,
      title: 'Invitar jugadores',
      maxSelection: match.availableSlots,
      excludedIds: excludedIds,
      confirmLabel: 'Enviar invitación',
    );
    if (selected == null || selected.isEmpty || !mounted) {
      return;
    }

    setState(() => _inviting = true);
    try {
      await ref
          .read(matchesProvider.notifier)
          .invitePlayers(matchId: match.id, inviteeIds: selected);
      _showMessage(
        selected.length == 1
            ? 'Invitación enviada.'
            : '${selected.length} invitaciones enviadas.',
      );
    } on AppFailure catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('No pudimos enviar las invitaciones. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.match});

  final Match match;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime localStart = MatchTime.inZone(
      match.startsAt,
      match.timezone,
    );
    final String timezoneLabel = match.timezone == kDefaultMatchTimezone
        ? 'Hora de Chile'
        : match.timezone;

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
                AppDateFormatters.fullDate(localStart),
              ),
            ),
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.schedule,
              text:
                  '${AppDateFormatters.timeRange(localStart, match.durationMinutes)} '
                  '(${match.durationMinutes} min)',
            ),
            const SizedBox(height: 6),
            _InfoRow(icon: Icons.public, text: timezoneLabel, subtle: true),
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.place_outlined,
              text: match.locationDetails == null
                  ? match.locationName
                  : '${match.locationName} · ${match.locationDetails}',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _SummaryChip(
                  label:
                      '${match.confirmedPlayers}/${match.requiredPlayers} confirmados',
                  color: match.isFull
                      ? AppColors.statusConfirmed
                      : AppColors.courtBlue,
                ),
                if (match.pendingPlayers > 0)
                  _SummaryChip(
                    label:
                        '${match.pendingPlayers} '
                        '${match.pendingPlayers == 1 ? 'pendiente' : 'pendientes'}',
                    color: AppColors.statusPending,
                  ),
                if (match.isActive && !match.isFull && match.availableSlots > 0)
                  _SummaryChip(
                    label:
                        '${match.availableSlots} '
                        '${match.availableSlots == 1 ? 'plaza libre' : 'plazas libres'}',
                    color: AppColors.clay,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.subtle = false});

  final IconData icon;
  final String text;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: subtle
                ? theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                : theme.textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.participant,
    required this.isCurrentUser,
  });

  final MatchParticipant participant;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? subtitle = participant.tennisLevel?.label;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: InitialsAvatar(
        name: participant.name,
        imageUrl: participant.avatarUrl,
      ),
      title: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              isCurrentUser ? '${participant.name} (tú)' : participant.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (participant.isOrganizer) ...<Widget>[
            const SizedBox(width: 8),
            Icon(Icons.star, size: 16, color: theme.colorScheme.tertiary),
          ],
        ],
      ),
      subtitle: participant.isOrganizer
          ? Text(subtitle == null ? 'Organizador' : 'Organizador · $subtitle')
          : (subtitle == null ? null : Text(subtitle)),
      trailing: _ResponseChip(response: participant.response),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final MatchEvent event;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(_iconFor(event.type), size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                event.type.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                event.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${AppDateFormatters.dayMonthShort(event.at)} · '
                '${AppDateFormatters.time(event.at)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _iconFor(MatchEventType type) {
    return switch (type) {
      MatchEventType.created => Icons.add_circle_outline,
      MatchEventType.invited => Icons.person_add_alt_1_outlined,
      MatchEventType.responded => Icons.how_to_reg_outlined,
      MatchEventType.proposed => Icons.update,
      MatchEventType.rescheduled => Icons.event_repeat,
      MatchEventType.cancelled => Icons.cancel_outlined,
      MatchEventType.completed => Icons.emoji_events_outlined,
    };
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
