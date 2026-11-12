import 'package:flutter/material.dart';

import '../../../../core/utils/date_formatters.dart';
import '../../../../core/utils/match_time.dart';
import '../../domain/match.dart';

/// Nuevo horario propuesto para un partido, en UTC y con su zona horaria.
class RescheduleRequest {
  const RescheduleRequest({required this.startsAtUtc, required this.timezone});

  final DateTime startsAtUtc;
  final String timezone;
}

/// Muestra el selector de nuevo horario y devuelve la propuesta elegida.
Future<RescheduleRequest?> showRescheduleSheet({
  required BuildContext context,
  required Match match,
}) {
  return showModalBottomSheet<RescheduleRequest>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => _RescheduleSheet(match: match),
  );
}

class _RescheduleSheet extends StatefulWidget {
  const _RescheduleSheet({required this.match});

  final Match match;

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  DateTime? _date;
  TimeOfDay? _time;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime currentLocal = MatchTime.inZone(
      widget.match.startsAt,
      widget.match.timezone,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Proponer nuevo horario',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Horario actual: '
            '${AppDateFormatters.capitalize(AppDateFormatters.fullDate(currentLocal))} '
            'a las ${AppDateFormatters.time(currentLocal)}. Los jugadores '
            'confirmados deben aprobar el cambio.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event),
            label: Text(
              _date == null
                  ? 'Elegir fecha'
                  : AppDateFormatters.capitalize(
                      AppDateFormatters.fullDate(_date!),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.schedule),
            label: Text(
              _time == null
                  ? 'Elegir hora'
                  : MaterialLocalizations.of(
                      context,
                    ).formatTimeOfDay(_time!, alwaysUse24HourFormat: true),
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send),
              label: const Text('Enviar propuesta'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime now = MatchTime.nowIn(widget.match.timezone);
    final DateTime initial = _date ?? now.add(const Duration(days: 1));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('es'),
      helpText: 'Nueva fecha',
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day);
        _error = null;
      });
    }
  }

  Future<void> _pickTime() async {
    final DateTime currentLocal = MatchTime.inZone(
      widget.match.startsAt,
      widget.match.timezone,
    );
    final TimeOfDay initial =
        _time ?? TimeOfDay(hour: currentLocal.hour, minute: currentLocal.minute);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Nueva hora',
    );
    if (picked != null) {
      setState(() {
        _time = picked;
        _error = null;
      });
    }
  }

  void _submit() {
    if (_date == null || _time == null) {
      setState(() => _error = 'Elige la nueva fecha y la hora.');
      return;
    }

    final DateTime date = _date!;
    final TimeOfDay time = _time!;
    final DateTime startsAtUtc = MatchTime.toUtc(
      local: DateTime(date.year, date.month, date.day, time.hour, time.minute),
      timezone: widget.match.timezone,
    );

    if (!startsAtUtc.isAfter(DateTime.now().toUtc())) {
      setState(() => _error = 'La nueva fecha debe ser posterior a ahora.');
      return;
    }

    Navigator.of(context).pop(
      RescheduleRequest(
        startsAtUtc: startsAtUtc,
        timezone: widget.match.timezone,
      ),
    );
  }
}
