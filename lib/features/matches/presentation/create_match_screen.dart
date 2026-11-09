import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/utils/match_time.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/section_header.dart';
import '../../friends/domain/friend.dart';
import '../../friends/presentation/friends_providers.dart';
import '../domain/match.dart';
import 'matches_providers.dart';

/// Pantalla para crear un partido con sus invitaciones.
class CreateMatchScreen extends ConsumerStatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  ConsumerState<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends ConsumerState<CreateMatchScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  MatchFormat _format = MatchFormat.doubles;
  DateTime? _date;
  TimeOfDay? _time;
  int _durationMinutes = 90;
  Set<String> _selectedFriendIds = <String>{};
  bool _saving = false;

  static const List<int> _durationOptions = <int>[60, 75, 90, 120];

  int get _maxInvitees => _format.maxPlayers - 1;

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
              onSelectionChanged: (Set<MatchFormat> selection) {
                final MatchFormat next = selection.first;
                setState(() {
                  _format = next;
                  _selectedFriendIds = _selectedFriendIds
                      .take(next.maxPlayers - 1)
                      .toSet();
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              '${_format.label}: ${_format.maxPlayers} jugadores en total '
              '(tú ocupas una plaza).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Fecha y hora'),
            Text(
              'El horario se muestra y se guarda para la zona '
              '$kDefaultMatchTimezone.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 24),
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
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Jugadores',
              subtitle:
                  'Elige hasta $_maxInvitees '
                  '${_maxInvitees == 1 ? 'amistad' : 'amistades'}. '
                  'Solo aparecen amistades aceptadas.',
            ),
            const SizedBox(height: 12),
            _FriendSelector(
              maxSelection: _maxInvitees,
              selectedIds: _selectedFriendIds,
              onChanged: (Set<String> selected) {
                setState(() => _selectedFriendIds = selected);
              },
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Creando partido…' : 'Crear partido'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime now = MatchTime.nowIn(kDefaultMatchTimezone);
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
        _date = DateTime(picked.year, picked.month, picked.day);
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
        _timeController.text = MaterialLocalizations.of(context)
            .formatTimeOfDay(picked, alwaysUse24HourFormat: true);
      });
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFriendIds.isEmpty) {
      _showMessage('Selecciona al menos una amistad para invitar.');
      return;
    }
    if (_selectedFriendIds.length > _maxInvitees) {
      _showMessage(
        'La modalidad ${_format.label} admite $_maxInvitees '
        'invitados como máximo.',
      );
      return;
    }

    final DateTime date = _date!;
    final TimeOfDay time = _time!;
    final DateTime startsAtUtc = MatchTime.toUtc(
      local: DateTime(date.year, date.month, date.day, time.hour, time.minute),
      timezone: kDefaultMatchTimezone,
    );

    if (!startsAtUtc.isAfter(DateTime.now().toUtc())) {
      _showMessage('La fecha y la hora deben ser posteriores a ahora.');
      return;
    }

    setState(() => _saving = true);
    try {
      final String matchId = await ref
          .read(matchesProvider.notifier)
          .createMatch(
            format: _format,
            startsAtUtc: startsAtUtc,
            timezone: kDefaultMatchTimezone,
            durationMinutes: _durationMinutes,
            locationName: _locationController.text.trim(),
            locationDetails: _detailsController.text.trim(),
            inviteeIds: _selectedFriendIds.toList(),
          );
      if (!mounted) return;
      context.pushReplacement('${AppRoutes.matchDetail}/$matchId');
    } on AppFailure catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('No pudimos crear el partido. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FriendSelector extends ConsumerWidget {
  const _FriendSelector({
    required this.maxSelection,
    required this.selectedIds,
    required this.onChanged,
  });

  final int maxSelection;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<FriendsOverview> friends = ref.watch(friendsProvider);

    return friends.when(
      loading: () => const LinearProgressIndicator(),
      error: (Object error, StackTrace stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'No pudimos cargar tus amistades.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => ref.invalidate(friendsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      data: (FriendsOverview overview) {
        if (overview.friends.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Todavía no tienes amistades aceptadas.',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Agrega amigos para poder invitarlos a tus partidos.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => context.go(AppRoutes.friends),
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Ir a amigos'),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${selectedIds.length} de $maxSelection seleccionados',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final Friend friend in overview.friends)
                      _FriendChip(
                        friend: friend,
                        selected: selectedIds.contains(friend.id),
                        enabled:
                            selectedIds.contains(friend.id) ||
                            selectedIds.length < maxSelection,
                        onSelected: (bool selected) {
                          final Set<String> next = <String>{...selectedIds};
                          if (selected) {
                            next.add(friend.id);
                          } else {
                            next.remove(friend.id);
                          }
                          onChanged(next);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FriendChip extends StatelessWidget {
  const _FriendChip({
    required this.friend,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final Friend friend;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: enabled ? onSelected : null,
      avatar: InitialsAvatar(
        name: friend.displayName,
        radius: 12,
        imageUrl: friend.avatarUrl,
      ),
      label: Text(friend.displayName),
    );
  }
}
