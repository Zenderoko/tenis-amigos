import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/prototype_banner.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../matches/domain/match.dart';
import '../../matches/presentation/matches_providers.dart';
import '../../matches/presentation/widgets/match_card.dart';

/// Pantalla de Inicio: próximos partidos e invitaciones pendientes.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Match>> matches = ref.watch(matchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Inicio')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/nuevo-partido'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo partido'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(matchesProvider),
        child: matches.when(
          loading: () => const LoadingView(message: 'Cargando tus partidos…'),
          error: (Object error, StackTrace stack) => ListView(
            children: <Widget>[
              const SizedBox(height: 120),
              ErrorView(
                message: 'No pudimos cargar tus partidos.\n$error',
                onRetry: () => ref.invalidate(matchesProvider),
              ),
            ],
          ),
          data: (List<Match> data) => _HomeContent(matches: data),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.matches});

  final List<Match> matches;

  @override
  Widget build(BuildContext context) {
    final List<Match> invitations = matches
        .where((Match m) => m.hasPendingInvitationFor(kMockCurrentUserId))
        .toList()
      ..sort((Match a, Match b) => a.startsAt.compareTo(b.startsAt));

    final List<Match> upcoming = matches
        .where(
          (Match m) =>
              m.isActive && !m.hasPendingInvitationFor(kMockCurrentUserId),
        )
        .toList()
      ..sort((Match a, Match b) => a.startsAt.compareTo(b.startsAt));

    if (invitations.isEmpty && upcoming.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const _Greeting(),
          const SizedBox(height: 24),
          const SizedBox(height: 100),
          EmptyView(
            title: 'Aún no tienes partidos',
            message:
                'Cuando organices o te inviten a un partido, aparecerá aquí.',
            action: FilledButton.icon(
              onPressed: () => context.push('/nuevo-partido'),
              icon: const Icon(Icons.add),
              label: const Text('Crear partido'),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: <Widget>[
        const _Greeting(),
        const SizedBox(height: 12),
        const PrototypeBanner(),
        const SizedBox(height: 20),
        if (invitations.isNotEmpty) ...<Widget>[
          SectionHeader(title: 'Invitaciones pendientes (${invitations.length})'),
          for (final Match match in invitations) ...<Widget>[
            MatchCard(
              match: match,
              onTap: () => context.push('/partido/${match.id}'),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
        ],
        if (upcoming.isNotEmpty) ...<Widget>[
          const SectionHeader(title: 'Próximos partidos'),
          for (final Match match in upcoming) ...<Widget>[
            MatchCard(
              match: match,
              onTap: () => context.push('/partido/${match.id}'),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String today = AppDateFormatters.capitalize(
      AppDateFormatters.weekdayDayMonth(DateTime.now()),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.courtGreen, AppColors.courtGreenDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Hola, $kMockCurrentUserName',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            today,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
