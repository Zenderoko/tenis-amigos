import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/prototype_banner.dart';
import '../../../core/widgets/state_views.dart';
import '../../matches/domain/match.dart';
import '../../matches/presentation/matches_providers.dart';
import '../../matches/presentation/widgets/match_card.dart';

/// Pantalla de Calendario con vista semanal.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _weekStart;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final DateTime today = _dateOnly(DateTime.now());
    _weekStart = _mondayOf(today);
    _selectedDay = today;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Match>> matches = ref.watch(matchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: const PrototypeBanner(),
          ),
          _WeekHeader(
            weekStart: _weekStart,
            onPrevious: () => _changeWeek(-7),
            onNext: () => _changeWeek(7),
          ),
          _WeekStrip(
            weekStart: _weekStart,
            selectedDay: _selectedDay,
            matchDates: matches.value ?? const <Match>[],
            onSelect: (DateTime day) => setState(() => _selectedDay = day),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(matchesProvider),
              child: matches.when(
                loading: () => const LoadingView(
                  message: 'Cargando el calendario…',
                ),
                error: (Object error, StackTrace stack) => ListView(
                  children: <Widget>[
                    const SizedBox(height: 80),
                    ErrorView(
                      message: 'No pudimos cargar el calendario.',
                      onRetry: () => ref.invalidate(matchesProvider),
                    ),
                  ],
                ),
                data: (List<Match> data) {
                  final List<Match> dayMatches = data
                      .where((Match m) => _isSameDay(m.startsAt, _selectedDay))
                      .toList()
                    ..sort(
                      (Match a, Match b) => a.startsAt.compareTo(b.startsAt),
                    );

                  if (dayMatches.isEmpty) {
                    return ListView(
                      children: <Widget>[
                        const SizedBox(height: 60),
                        EmptyView(
                          title: 'Sin partidos este día',
                          message:
                              'Selecciona otra fecha o crea un nuevo partido.',
                          icon: Icons.event_available_outlined,
                        ),
                      ],
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: <Widget>[
                      for (final Match match in dayMatches) ...<Widget>[
                        MatchCard(
                          match: match,
                          onTap: () => context.push('/partido/${match.id}'),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _changeWeek(int days) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: days));
      _selectedDay = _weekStart;
    });
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _mondayOf(DateTime date) =>
      _dateOnly(date).subtract(Duration(days: date.weekday - 1));

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.weekStart,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime weekStart;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime weekEnd = weekStart.add(const Duration(days: 6));
    final String label = AppDateFormatters.capitalize(
      AppDateFormatters.monthYear(weekStart),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Semana anterior',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${AppDateFormatters.dayMonthShort(weekStart)} – '
                  '${AppDateFormatters.dayMonthShort(weekEnd)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Semana siguiente',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.weekStart,
    required this.selectedDay,
    required this.matchDates,
    required this.onSelect,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final List<Match> matchDates;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime today = _CalendarScreenState._dateOnly(DateTime.now());
    final DateFormat weekdayFormat = DateFormat('EEEE', 'es');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < 7; i++)
            Expanded(
              child: _DayCell(
                day: weekStart.add(Duration(days: i)),
                weekdayLabel: AppDateFormatters.capitalize(
                  weekdayFormat.format(weekStart.add(Duration(days: i))),
                ).substring(0, 3),
                isSelected:
                    _CalendarScreenState._isSameDay(
                      weekStart.add(Duration(days: i)),
                      selectedDay,
                    ),
                isToday: _CalendarScreenState._isSameDay(
                  weekStart.add(Duration(days: i)),
                  today,
                ),
                statuses: matchDates
                    .where(
                      (Match m) => _CalendarScreenState._isSameDay(
                        m.startsAt,
                        weekStart.add(Duration(days: i)),
                      ),
                    )
                    .map((Match m) => m.status)
                    .toList(),
                onTap: () => onSelect(weekStart.add(Duration(days: i))),
                theme: theme,
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.weekdayLabel,
    required this.isSelected,
    required this.isToday,
    required this.statuses,
    required this.onTap,
    required this.theme,
  });

  final DateTime day;
  final String weekdayLabel;
  final bool isSelected;
  final bool isToday;
  final List<MatchStatus> statuses;
  final VoidCallback onTap;
  final ThemeData theme;

  Color? get _firstDotColor {
    if (statuses.isEmpty) return null;
    final MatchStatus status = statuses.first;
    return switch (status) {
      MatchStatus.awaitingPlayers => AppColors.statusPending,
      MatchStatus.confirmed => AppColors.statusConfirmed,
      MatchStatus.cancelled => AppColors.statusCancelled,
      MatchStatus.completed => AppColors.statusCompleted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = theme.colorScheme;
    final Color background = isSelected
        ? scheme.primary
        : (isToday ? scheme.primaryContainer : Colors.transparent);
    final Color foreground = isSelected
        ? scheme.onPrimary
        : (isToday ? scheme.onPrimaryContainer : scheme.onSurface);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: <Widget>[
            Text(
              weekdayLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: foreground.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${day.day}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 6,
              child: _firstDotColor == null
                  ? null
                  : Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _firstDotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
