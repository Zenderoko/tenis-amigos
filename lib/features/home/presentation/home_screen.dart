import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../matches/domain/match.dart';
import '../../matches/presentation/matches_providers.dart';
import '../../matches/presentation/widgets/match_card.dart';
import '../../profile/data/profile_providers.dart';
import '../../profile/domain/user_profile.dart';

/// Pantalla de Inicio: solo partidos confirmados.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Match>> matches = ref.watch(matchesProvider);
    final AuthUser? user = ref.watch(authControllerProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Inicio')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/nuevo-partido'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo partido'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(matchesProvider.notifier).refresh(),
        child: matches.when(
          loading: () => const LoadingView(message: 'Cargando tus partidos…'),
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
          data: (List<Match> data) =>
              _HomeContent(matches: data, currentUserId: user?.id),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.matches, required this.currentUserId});

  final List<Match> matches;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final String? userId = currentUserId;
    final List<Match> confirmedMatches = matches.where((Match match) {
      if (match.status != MatchStatus.confirmed) {
        return false;
      }
      if (userId == null) {
        return false;
      }
      return match.participantFor(userId)?.response ==
          ParticipantResponse.accepted;
    }).toList()..sort((Match a, Match b) => a.startsAt.compareTo(b.startsAt));

    if (confirmedMatches.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          _Greeting(),
          SizedBox(height: 24),
          SizedBox(height: 100),
          EmptyView(
            title: 'No hay partidos confirmados',
            message: 'Cuando un partido complete su cupo, aparecerá aquí.',
            icon: Icons.event_available_outlined,
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: <Widget>[
        const _Greeting(),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Partidos confirmados'),
        for (final Match match in confirmedMatches) ...<Widget>[
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

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String today = AppDateFormatters.capitalize(
      AppDateFormatters.weekdayDayMonth(DateTime.now()),
    );
    final UserProfile? profile = ref.watch(profileProvider).value;
    final AuthUser? user = ref.watch(authControllerProvider).value;
    final String name = _firstName(
      profile?.displayName ?? user?.displayNameOrEmail ?? '',
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
            name.isEmpty ? 'Hola' : 'Hola, $name',
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

  String _firstName(String value) {
    final List<String> parts = value.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.first;
  }
}
