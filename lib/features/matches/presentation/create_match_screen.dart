import 'package:flutter/material.dart';

import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/prototype_banner.dart';
import '../../../core/widgets/section_header.dart';
import '../domain/match.dart';

/// Pantalla para crear un partido.
///
/// En la Etapa 1 es solo un formulario de prototipo: valida los datos pero no
/// los guarda. La persistencia real y las invitaciones llegan en la Etapa 4.
class CreateMatchScreen extends StatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  MatchFormat _format = MatchFormat.doubles;
  DateTime? _date;
  TimeOfDay? _time;
  int _durationMinutes = 90;

  static const List<int> _durationOptions = <int>[60, 75, 90, 120];

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _locationController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo partido')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            const PrototypeBanner(
              message:
                  'Prototipo visual · el partido no se guarda todavía (Etapa 4)',
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Modalidad'),
            SegmentedButton<MatchFormat>(
              segments: <ButtonSegment<MatchFormat>>[
                for (final MatchFormat format in MatchFormat.values)
                  ButtonSegment<MatchFormat>(
                    value: format,
                    label: Text(format.label),
                    icon: Icon(
                      format == MatchFormat.singles
                          ? Icons.person
                          : Icons.groups,
                    ),
                  ),
              ],
              selected: <MatchFormat>{_format},
              onSelectionChanged: (Set<MatchFormat> selection) =>
                  setState(() => _format = selection.first),
            ),
            const SizedBox(height: 8),
            Text(
              '${_format.label}: ${_format.maxPlayers} jugadores en total '
              '(tú ocupas una plaza).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Fecha y hora'),
            TextFormField(
              controller: _dateController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Fecha',
                prefixIcon: Icon(Icons.event),
                hintText: 'Selecciona una fecha',
              ),
              validator: (String? value) =>
                  (value == null || value.isEmpty) ? 'Elige una fecha' : null,
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _timeController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Hora de inicio',
                prefixIcon: Icon(Icons.schedule),
                hintText: 'Selecciona una hora',
              ),
              validator: (String? value) =>
                  (value == null || value.isEmpty) ? 'Elige una hora' : null,
              onTap: _pickTime,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _durationMinutes,
              decoration: const InputDecoration(
                labelText: 'Duración',
                prefixIcon: Icon(Icons.timelapse),
              ),
              items: <DropdownMenuItem<int>>[
                for (final int minutes in _durationOptions)
                  DropdownMenuItem<int>(
                    value: minutes,
                    child: Text('$minutes minutos'),
                  ),
              ],
              onChanged: (int? value) {
                if (value != null) setState(() => _durationMinutes = value);
              },
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Lugar'),
            TextFormField(
              controller: _locationController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre del lugar o club',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              validator: (String? value) =>
                  (value == null || value.trim().isEmpty)
                      ? 'Indica el lugar del partido'
                      : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _detailsController,
              decoration: const InputDecoration(
                labelText: 'Detalles (opcional)',
                hintText: 'Cancha, superficie, referencias…',
                prefixIcon: Icon(Icons.info_outline),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label: const Text('Crear partido'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime initial = _date ?? now.add(const Duration(days: 1));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('es'),
      helpText: 'Selecciona la fecha',
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _dateController.text = AppDateFormatters.capitalize(
          AppDateFormatters.fullDate(picked),
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay initial = _time ?? const TimeOfDay(hour: 19, minute: 0);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Selecciona la hora',
    );
    if (picked != null) {
      setState(() {
        _time = picked;
        _timeController.text = MaterialLocalizations.of(
          context,
        ).formatTimeOfDay(picked, alwaysUse24HourFormat: true);
      });
    }
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final DateTime date = _date!;
    final TimeOfDay time = _time!;
    final DateTime startsAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (!startsAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha y la hora deben ser posteriores a ahora.'),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Prototipo'),
        content: Text(
          'Se creará un partido de ${_format.label.toLowerCase()} en '
          '${_locationController.text.trim()} '
          'el ${AppDateFormatters.fullDate(startsAt)} a las '
          '${AppDateFormatters.time(startsAt)}.\n\n'
          'En esta etapa todavía no se guarda ni se envían invitaciones '
          '(disponible en la Etapa 4).',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
