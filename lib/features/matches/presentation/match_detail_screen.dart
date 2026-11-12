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
import 'widgets/reschedule_sheet.dart';

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
  bool _actionBusy = false;
  bool _proposing = false;
  bool _proposalBusy = false;

  Match get match => widget.match;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? userId = widget.currentUserId;
    final bool isOrganizer = userId != null && match.isOrganizer(userId);
    final bool canRespond = userId != null && match.canRespond(userId);
    final bool canInvite =
        isOrganizer && match.isActive && match.availableSlots > 0;
    final bool canCancel = userId != null && match.canCancel(userId);
    final bool canWithdraw = userId != null && match.canWithdraw(userId);
    final bool canPropose =
        userId != null && match.canProposeReschedule(userId);
    final bool canManagePlayers = isOrganizer && match.isActive && !_actionBusy;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        _DetailHeader(match: match),
        if (match.pendingProposal != null) ...<Widget>[
          const SizedBox(height: 16),
          _ProposalCard(
            match: match,
            currentUserId: userId,
            busy: _proposalBusy,
            onAccept: () => _respondToProposal(accept: true),
            onReject: () => _respondToProposal(accept: false),
            onCancel: _cancelProposal,
          ),
        ],
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
                  onRemove:
                      canManagePlayers &&
                          match.canRemovePlayer(
                            userId,
                            match.participants[i].id,
                          )
                      ? () => _removePlayer(match.participants[i])
                      : null,
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
        if (canPropose) ...<Widget>[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _proposing ? null : _proposeReschedule,
            icon: _proposing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.event_repeat),
            label: Text(
              _proposing ? 'Enviando propuesta…' : 'Proponer nuevo horario',
            ),
          ),
        ],
        if (canWithdraw) ...<Widget>[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _actionBusy ? null : _withdraw,
            icon: const Icon(Icons.logout),
            label: const Text('Retirarme del partido'),
          ),
        ],
        if (canCancel) ...<Widget>[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _actionBusy ? null : _cancelMatch,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancelar partido'),
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

  Future<void> _cancelMatch() async {
    final bool confirmed = await _confirm(
      title: 'Cancelar partido',
      message:
          'Se cancelará el partido para todos los jugadores. Esta acción no '
          'se puede deshacer.',
      confirmLabel: 'Cancelar partido',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _actionBusy = true);
    try {
      await ref.read(matchesProvider.notifier).cancelMatch(match.id);
      _showMessage('El partido quedó cancelado.');
    } on AppFailure catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('No pudimos cancelar el partido. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _withdraw() async {
    final bool confirmed = await _confirm(
      title: 'Retirarme del partido',
      message:
          'Tu plaza quedará libre y el organizador podrá invitar a otra '
          'persona.',
      confirmLabel: 'Retirarme',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _actionBusy = true);
    try {
      await ref.read(matchesProvider.notifier).withdrawFromMatch(match.id);
      _showMessage('Te retiraste del partido.');
    } on AppFailure catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('No pudimos retirarte del partido. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _removePlayer(MatchParticipant participant) async {
    final bool confirmed = await _confirm(
      title: 'Eliminar jugador',
      message:
          '¿Eliminar a ${participant.name} del partido? Su plaza quedará libre '
          'y podrás invitar a otra persona.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _actionBusy = true);
    try {
      await ref
          .read(matchesProvider.notifier)
          .removePlayer(matchId: match.id, playerId: participant.id);
      _showMessage('${participant.name} fue eliminado del partido.');
    } on AppFailure catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('No pudimos eliminar al jugador. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _proposeReschedule() async {
    final RescheduleRequest? request = await showRescheduleSheet(
      context: context,
      match: match,
    );
    if (request == null || !mounted) return;

    setState(() => _proposing = true);
    try {
      await ref
          .read(matchesProvider.notifier)
          .proposeReschedule(
            matchId: match.id,
            startsAtUtc: request.startsAtUtc,
            timezone: request.timezone,
          );
      _showMessage('Propuesta de nuevo horario enviada.');
    } on AppFailure catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('No pudimos enviar la propuesta. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _proposing = false);
    }
  }

  Future<void> _respondToProposal({required bool accept}) async {
    final MatchProposal? proposal = match.pendingProposal;
    if (proposal == null) return;

    setState(() => _proposalBusy = true);
    try {
      await ref
          .read(matchesProvider.notifier)
          .respondToReschedule(proposalId: proposal.id, accept: accept);
      _showMessage(
        accept
            ? 'Aprobaste el nuevo horario.'
            : 'Rechazaste el nuevo horario.',
      );
    } on AppFailure catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('No pudimos registrar tu respuesta. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _proposalBusy = false);
    }
  }

  Future<void> _cancelProposal() async {
    final MatchProposal? proposal = match.pendingProposal;
    if (proposal == null) return;

    setState(() => _proposalBusy = true);
    try {
      await ref
          .read(matchesProvider.notifier)
          .cancelReschedule(proposal.id);
      _showMessage('Retiraste la propuesta de reprogramación.');
    } on AppFailure catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('No pudimos retirar la propuesta. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _proposalBusy = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final ThemeData theme = Theme.of(context);
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
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
    this.onRemove,
  });

  final MatchParticipant participant;
  final bool isCurrentUser;

  /// Si no es nulo, el organizador puede eliminar a este jugador.
  final VoidCallback? onRemove;

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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ResponseChip(response: participant.response),
          if (onRemove != null) ...<Widget>[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Eliminar del partido',
              icon: const Icon(Icons.person_remove_outlined),
              onPressed: onRemove,
            ),
          ],
        ],
      ),
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
      MatchEventType.rescheduleRejected => Icons.event_busy_outlined,
      MatchEventType.withdrawn => Icons.logout,
      MatchEventType.removed => Icons.person_remove_outlined,
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
    ParticipantResponse.removed => AppColors.statusCancelled,
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

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.match,
    required this.currentUserId,
    required this.busy,
    required this.onAccept,
    required this.onReject,
    required this.onCancel,
  });

  final Match match;
  final String? currentUserId;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MatchProposal proposal = match.pendingProposal!;
    final String? userId = currentUserId;
    final DateTime proposedLocal = MatchTime.inZone(
      proposal.proposedStartsAt,
      proposal.timezone,
    );
    final bool canRespond =
        userId != null && match.canRespondToProposal(userId);
    final bool canCancel = userId != null && match.canCancelProposal(userId);
    final int required = match.proposalVotersRequired(match.organizerId);

    return Card(
      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.event_repeat, color: theme.colorScheme.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reprogramación pendiente',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${AppDateFormatters.capitalize(AppDateFormatters.fullDate(proposedLocal))} '
              'a las ${AppDateFormatters.time(proposedLocal)}',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Propuesta por ${_proposerName()}. '
              '${proposal.acceptedVotes} de $required '
              '${required == 1 ? 'aprobación' : 'aprobaciones'}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (canRespond) ...<Widget>[
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onReject,
                      icon: const Icon(Icons.close),
                      label: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : onAccept,
                      icon: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Aprobar'),
                    ),
                  ),
                ],
              ),
            ] else if (userId != null && proposal.hasVoted(userId)) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                proposal.voteFor(userId)!.accepted
                    ? 'Aprobaste este cambio.'
                    : 'Rechazaste este cambio.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (canCancel) ...<Widget>[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: busy ? null : onCancel,
                icon: const Icon(Icons.undo),
                label: const Text('Retirar propuesta'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _proposerName() {
    final MatchParticipant? proposer = match.participantFor(
      match.pendingProposal!.proposedBy,
    );
    if (proposer == null) return 'el organizador';
    return match.pendingProposal!.proposedBy == currentUserId
        ? 'ti'
        : proposer.name;
  }
}
