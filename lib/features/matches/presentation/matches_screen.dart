import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/match.dart';
import 'matches_providers.dart';
import 'widgets/match_card.dart';

/// Pantalla de Partidos: reúne los partidos en curso, las invitaciones
/// pendientes y el historial de finalizados y cancelados.
class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Match>> matches = ref.watch(matchesProvider);
    final AuthUser? user = ref.watch(authControllerProvider).value;

    final int pendingInvitations = matches.maybeWhen(
      data: (List<Match> data) {
        final String? userId = user?.id;
        if (userId == null) return 0;
        return data
            .where((Match match) => match.hasPendingInvitationFor(userId))
            .length;
      },
      orElse: () => 0,
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Partidos'),
          bottom: TabBar(
            tabs: <Widget>[
              const Tab(text: 'En curso'),
              Tab(
                child: _InvitationsTabLabel(count: pendingInvitations),
              ),
              const Tab(text: 'Historial'),
            ],
          ),
        ),
        body: matches.when(
          loading: () => const LoadingView(message: 'Cargando partidos…'),
          error: (Object error, StackTrace stack) => ListView(
            children: <Widget>[
              const SizedBox(height: 120),
              ErrorView(
                message: error is AppFailure
                    ? error.message
                    : 'No pudimos cargar tus partidos.',
                onRetry: () => ref.invalidate(matchesProvider),
              ),
            ],
          ),
          data: (List<Match> data) => TabBarView(
            children: <Widget>[
              _ActiveTab(matches: data),
              _InvitationsTab(matches: data, currentUserId: user?.id),
              _HistoryTab(matches: data),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitationsTabLabel extends StatelessWidget {
  const _InvitationsTabLabel({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return const Text('Invitaciones');
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text('Invitaciones'),
        const SizedBox(width: 6),
        Badge.count(count: count),
      ],
    );
  }
}

class _ActiveTab extends ConsumerWidget {
  const _ActiveTab({required this.matches});

  final List<Match> matches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Match> active = matches.where((Match match) => match.isActive).toList()
      ..sort((Match a, Match b) => a.startsAt.compareTo(b.startsAt));

    return RefreshIndicator(
      onRefresh: () => ref.read(matchesProvider.notifier).refresh(),
      child: active.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: const <Widget>[
                SizedBox(height: 80),
                EmptyView(
                  title: 'No tienes partidos en curso',
                  message: 'Los partidos activos e invitaciones aparecerán aquí.',
                  icon: Icons.sports_tennis_outlined,
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: <Widget>[
                for (final Match match in active) ...<Widget>[
                  MatchCard(
                    match: match,
                    onTap: () => context.push('/partido/${match.id}'),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _InvitationsTab extends ConsumerStatefulWidget {
  const _InvitationsTab({required this.matches, required this.currentUserId});

  final List<Match> matches;
  final String? currentUserId;

  @override
  ConsumerState<_InvitationsTab> createState() => _InvitationsTabState();
}

class _InvitationsTabState extends ConsumerState<_InvitationsTab> {
  final Set<String> _busyMatchIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final String? userId = widget.currentUserId;
    final List<Match> invitations =
        widget.matches
            .where(
              (Match match) =>
                  userId != null && match.hasPendingInvitationFor(userId),
            )
            .toList()
          ..sort((Match a, Match b) => a.startsAt.compareTo(b.startsAt));

    return RefreshIndicator(
      onRefresh: () => ref.read(matchesProvider.notifier).refresh(),
      child: invitations.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: const <Widget>[
                SizedBox(height: 80),
                EmptyView(
                  title: 'No tienes invitaciones pendientes',
                  message: 'Cuando te inviten a un partido, aparecerá aquí.',
                  icon: Icons.mail_outline,
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: <Widget>[
                for (final Match match in invitations) ...<Widget>[
                  MatchCard(
                    match: match,
                    onTap: () => context.push('/partido/${match.id}'),
                    footer: _InvitationActions(
                      busy: _busyMatchIds.contains(match.id),
                      onAccept: () => _respond(match, accept: true),
                      onDecline: () => _respond(match, accept: false),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }

  Future<void> _respond(Match match, {required bool accept}) async {
    setState(() => _busyMatchIds.add(match.id));
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
      if (mounted) {
        setState(() => _busyMatchIds.remove(match.id));
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({required this.matches});

  final List<Match> matches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Match> history = matches.where((Match match) => !match.isActive).toList()
      ..sort((Match a, Match b) => b.startsAt.compareTo(a.startsAt));

    return RefreshIndicator(
      onRefresh: () => ref.read(matchesProvider.notifier).refresh(),
      child: history.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: const <Widget>[
                SizedBox(height: 80),
                EmptyView(
                  title: 'Sin historial todavía',
                  message: 'Aquí verás los partidos finalizados y cancelados.',
                  icon: Icons.history,
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: <Widget>[
                for (final Match match in history) ...<Widget>[
                  MatchCard(
                    match: match,
                    onTap: () => context.push('/partido/${match.id}'),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _InvitationActions extends StatelessWidget {
  const _InvitationActions({
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy ? null : onDecline,
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
            label: const Text('Aceptar'),
          ),
        ),
      ],
    );
  }
}
