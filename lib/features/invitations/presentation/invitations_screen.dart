import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../matches/domain/match.dart';
import '../../matches/presentation/matches_providers.dart';
import '../../matches/presentation/widgets/match_card.dart';

/// Pantalla de Invitaciones: muestra las invitaciones pendientes del usuario.
class InvitationsScreen extends ConsumerWidget {
  const InvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Match>> matches = ref.watch(matchesProvider);
    final AuthUser? user = ref.watch(authControllerProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Invitaciones')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(matchesProvider.notifier).refresh(),
        child: matches.when(
          loading: () => const LoadingView(message: 'Cargando invitaciones…'),
          error: (Object error, StackTrace stack) => ListView(
            children: <Widget>[
              const SizedBox(height: 120),
              ErrorView(
                message: error is AppFailure
                    ? error.message
                    : 'No pudimos cargar las invitaciones.',
                onRetry: () => ref.invalidate(matchesProvider),
              ),
            ],
          ),
          data: (List<Match> data) =>
              _InvitationsContent(matches: data, currentUserId: user?.id),
        ),
      ),
    );
  }
}

class _InvitationsContent extends ConsumerStatefulWidget {
  const _InvitationsContent({
    required this.matches,
    required this.currentUserId,
  });

  final List<Match> matches;
  final String? currentUserId;

  @override
  ConsumerState<_InvitationsContent> createState() =>
      _InvitationsContentState();
}

class _InvitationsContentState extends ConsumerState<_InvitationsContent> {
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

    if (invitations.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          SizedBox(height: 80),
          EmptyView(
            title: 'No tienes invitaciones pendientes',
            message: 'Cuando te inviten a un partido, aparecerá aquí.',
            icon: Icons.mail_outline,
          ),
        ],
      );
    }

    return ListView(
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
