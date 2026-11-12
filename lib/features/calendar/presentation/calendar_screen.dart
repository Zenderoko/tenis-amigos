import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/utils/match_time.dart';
import '../../../core/widgets/state_views.dart';
import '../../matches/domain/match.dart';
import '../../matches/presentation/matches_providers.dart';
import '../../matches/presentation/widgets/match_card.dart';

/// Modo de visualización del calendario.
enum CalendarViewMode { week, month }

/// Pantalla de Calendario con vista semanal y mensual.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarViewMode _mode = CalendarViewMode.week;
  late DateTime _weekStart;
  late DateTime _monthAnchor;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final DateTime today = _dateOnly(DateTime.now());
    _weekStart = _mondayOf(today);
    _monthAnchor = DateTime(today.year, today.month);
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<CalendarViewMode>(
              segments: const <ButtonSegment<CalendarViewMode>>[
                ButtonSegment<CalendarViewMode>(
                  value: CalendarViewMode.week,
                  label: Text('Semana'),
                  icon: Icon(Icons.view_week_outlined),
                ),
                ButtonSegment<CalendarViewMode>(
                  value: CalendarViewMode.month,
                  label: Text('Mes'),
                  icon: Icon(Icons.calendar_month_outlined),
                ),
              ],
              selected: <CalendarViewMode>{_mode},
              onSelectionChanged: (Set<CalendarViewMode> selection) {
                setState(() => _mode = selection.first);
              },
            ),
          ),
          if (_mode == CalendarViewMode.week)
            _WeekHeader(
              weekStart: _weekStart,
              onPrevious: () => _changeWeek(-7),
              onNext: () => _changeWeek(7),
            )
          else
            _MonthHeader(
              anchor: _monthAnchor,
              onPrevious: () => _changeMonth(-1),
              onNext: () => _changeMonth(1),
            ),
          _CalendarGrid(
            mode: _mode,
            weekStart: _weekStart,
            monthAnchor: _monthAnchor,
            selectedDay: _selectedDay,
            matches: matches.value ?? const <Match>[],
            onSelect: (DateTime day) => setState(() => _selectedDay = day),
          ),
          const _StatusLegend(),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(matchesProvider.notifier).refresh(),
              child: matches.when(
                loading: () =>
                    const LoadingView(message: 'Cargando el calendario…'),
                error: (Object error, StackTrace stack) => ListView(
                  children: <Widget>[
                    const SizedBox(height: 80),
                    ErrorView(
                      message: error is AppFailure
                          ? error.message
                          : 'No pudimos cargar el calendario.',
                      onRetry: () => ref.invalidate(matchesProvider),
                    ),
                  ],
                ),
                data: (List<Match> data) {
                  final List<Match> dayMatches =
                      data
                          .where(
                            (Match m) => _isSameDay(
                              MatchTime.inZone(m.startsAt, m.timezone),
                              _selectedDay,
                            ),
                          )
                          .toList()
                        ..sort(
                          (Match a, Match b) =>
                              a.startsAt.compareTo(b.startsAt),
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

  void _changeMonth(int delta) {
    setState(() {
      _monthAnchor = DateTime(_monthAnchor.year, _monthAnchor.month + delta);
      _selectedDay = _monthAnchor;
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

    return _PeriodHeader(
      title: label,
      subtitle:
          '${AppDateFormatters.dayMonthShort(weekStart)} – '
          '${AppDateFormatters.dayMonthShort(weekEnd)}',
      onPrevious: onPrevious,
      onNext: onNext,
      theme: theme,
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.anchor,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime anchor;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _PeriodHeader(
      title: AppDateFormatters.capitalize(
        AppDateFormatters.monthYear(anchor),
      ),
      subtitle: '${DateTime(anchor.year, anchor.month + 1, 0).day} días',
      onPrevious: onPrevious,
      onNext: onNext,
      theme: theme,
    );
  }
}

class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({
    required this.title,
    required this.subtitle,
    required this.onPrevious,
    required this.onNext,
    required this.theme,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Anterior',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Siguiente',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.mode,
    required this.weekStart,
    required this.monthAnchor,
    required this.selectedDay,
    required this.matches,
    required this.onSelect,
  });

  final CalendarViewMode mode;
  final DateTime weekStart;
  final DateTime monthAnchor;
  final DateTime selectedDay;
  final List<Match> matches;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    return mode == CalendarViewMode.week
        ? _WeekStrip(
            weekStart: weekStart,
            selectedDay: selectedDay,
            matches: matches,
            onSelect: onSelect,
          )
        : _MonthGrid(
            anchor: monthAnchor,
            selectedDay: selectedDay,
            matches: matches,
            onSelect: onSelect,
          );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.weekStart,
    required this.selectedDay,
    required this.matches,
    required this.onSelect,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final List<Match> matches;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final DateTime today = _CalendarScreenState._dateOnly(DateTime.now());
    final DateFormat weekdayFormat = DateFormat('EEEE', 'es');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < 7; i++)
            Expanded(
              child: _DayCell(
                day: weekStart.add(Duration(days: i)),
                weekdayLabel: AppDateFormatters.capitalize(
                  weekdayFormat.format(weekStart.add(Duration(days: i))),
                ).substring(0, 3),
                isSelected: _CalendarScreenState._isSameDay(
                  weekStart.add(Duration(days: i)),
                  selectedDay,
                ),
                isToday: _CalendarScreenState._isSameDay(
                  weekStart.add(Duration(days: i)),
                  today,
                ),
                statuses: _statusesFor(
                  matches,
                  weekStart.add(Duration(days: i)),
                ),
                onTap: () => onSelect(weekStart.add(Duration(days: i))),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.anchor,
    required this.selectedDay,
    required this.matches,
    required this.onSelect,
  });

  final DateTime anchor;
  final DateTime selectedDay;
  final List<Match> matches;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime today = _CalendarScreenState._dateOnly(DateTime.now());
    final DateTime first = DateTime(anchor.year, anchor.month);
    final int daysInMonth = DateTime(anchor.year, anchor.month + 1, 0).day;
    final int leading = first.weekday - 1;
    final int totalCells = ((leading + daysInMonth) / 7).ceil() * 7;
    final DateFormat weekdayFormat = DateFormat('EEEE', 'es');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              for (int i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      AppDateFormatters.capitalize(
                        weekdayFormat.format(
                          DateTime(2024, 1, 1 + i),
                        ),
                      ).substring(0, 3),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (int week = 0; week < totalCells ~/ 7; week++)
            Row(
              children: <Widget>[
                for (int i = 0; i < 7; i++)
                  Expanded(
                    child: _buildCell(
                      index: week * 7 + i,
                      leading: leading,
                      daysInMonth: daysInMonth,
                      today: today,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCell({
    required int index,
    required int leading,
    required int daysInMonth,
    required DateTime today,
  }) {
    final int dayNumber = index - leading + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 46);
    }
    final DateTime day = DateTime(anchor.year, anchor.month, dayNumber);
    return _DayCell(
      day: day,
      weekdayLabel: null,
      isSelected: _CalendarScreenState._isSameDay(day, selectedDay),
      isToday: _CalendarScreenState._isSameDay(day, today),
      statuses: _statusesFor(matches, day),
      onTap: () => onSelect(day),
      compact: true,
    );
  }
}

List<MatchStatus> _statusesFor(List<Match> matches, DateTime day) {
  final List<MatchStatus> statuses = <MatchStatus>[];
  for (final Match match in matches) {
    if (_CalendarScreenState._isSameDay(
      MatchTime.inZone(match.startsAt, match.timezone),
      day,
    )) {
      statuses.add(match.status);
    }
  }
  return statuses;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.weekdayLabel,
    required this.isSelected,
    required this.isToday,
    required this.statuses,
    required this.onTap,
    this.compact = false,
  });

  final DateTime day;
  final String? weekdayLabel;
  final bool isSelected;
  final bool isToday;
  final List<MatchStatus> statuses;
  final VoidCallback onTap;
  final bool compact;

  static const Map<MatchStatus, Color> _statusColors = <MatchStatus, Color>{
    MatchStatus.awaitingPlayers: AppColors.statusPending,
    MatchStatus.confirmed: AppColors.statusConfirmed,
    MatchStatus.cancelled: AppColors.statusCancelled,
    MatchStatus.completed: AppColors.statusCompleted,
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color background = isSelected
        ? scheme.primary
        : (isToday ? scheme.primaryContainer : Colors.transparent);
    final Color foreground = isSelected
        ? scheme.onPrimary
        : (isToday ? scheme.onPrimaryContainer : scheme.onSurface);

    final List<Color> dots = statuses
        .map((MatchStatus status) => _statusColors[status]!)
        .take(3)
        .toList();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        padding: EdgeInsets.symmetric(vertical: compact ? 6 : 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: <Widget>[
            if (weekdayLabel != null) ...<Widget>[
              Text(
                weekdayLabel!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: foreground.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 4),
            ],
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (final Color color in dots)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLegend extends StatelessWidget {
  const _StatusLegend();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: <Widget>[
          _LegendItem(color: AppColors.statusPending, label: 'Faltan jugadores'),
          _LegendItem(color: AppColors.statusConfirmed, label: 'Confirmado'),
          _LegendItem(color: AppColors.statusCancelled, label: 'Cancelado'),
          _LegendItem(color: AppColors.statusCompleted, label: 'Finalizado'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
