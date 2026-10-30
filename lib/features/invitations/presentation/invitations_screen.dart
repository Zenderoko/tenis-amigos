import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/mock_data.dart';
import '../../../core/widgets/prototype_banner.dart';
import '../../../core/widgets/state_views.dart';
import '../../matches/domain/match.dart';
import '../../matches/presentation/matches_providers.dart';
import '../../matches/presentation/widgets/match_card.dart';

/// Pantalla de Invitaciones: muestra las invitaciones pendientes del usuario.
class InvitationsScreen extends ConsumerWidget {
  const InvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Match>> matches = ref.watch(matchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Invitaciones')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(matchesProvider),
        child: matches.when(
          loading: () => const LoadingView(message: 'Cargando invitaciones…'),
          error: (Object error, StackTrace stack) => ListView(
            children: <Widget>[
              const SizedBox(height: 120),
              ErrorView(
                message: 'No pudimos cargar las invitaciones.\n$error',
                onRetry: () => ref.invalidate(matchesProvider),
              ),
            ],
          ),
          data: (List<Match> data) => _InvitationsContent(matches: data),
        ),
      ),
    );
  }
}

class _InvitationsContent extends StatelessWidget {
  const _InvitationsContent({required this.matches});

  final List<Match> matches;

  @override
  Widget build(BuildContext context) {
    final List<Match> invitations =
        matches
            .where((Match m) => m.hasPendingInvitationFor(kMockCurrentUserId))
            .toList()
          ..sort((Match a, Match b) => a.startsAt.compareTo(b.startsAt));

    if (invitations.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          PrototypeBanner(),
          SizedBox(height: 24),
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
        const PrototypeBanner(),
        const SizedBox(height: 20),
        for (final Match match in invitations) ...<Widget>[
          MatchCard(
            match: match,
            onTap: () => context.push('/partido/${match.id}'),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
