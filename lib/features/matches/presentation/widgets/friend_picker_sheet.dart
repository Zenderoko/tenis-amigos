import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/initials_avatar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../friends/domain/friend.dart';
import '../../../friends/presentation/friends_providers.dart';

/// Abre el selector de amistades y devuelve los ids elegidos.
///
/// Se usa tanto al crear un partido como al invitar jugadores desde el
/// detalle. [excludedIds] contiene a quienes ya ocupan una plaza activa.
Future<List<String>?> showFriendPickerSheet({
  required BuildContext context,
  required String title,
  required int maxSelection,
  required Set<String> excludedIds,
  String confirmLabel = 'Invitar',
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) => _FriendPickerSheet(
      title: title,
      maxSelection: maxSelection,
      excludedIds: excludedIds,
      confirmLabel: confirmLabel,
    ),
  );
}

class _FriendPickerSheet extends ConsumerStatefulWidget {
  const _FriendPickerSheet({
    required this.title,
    required this.maxSelection,
    required this.excludedIds,
    required this.confirmLabel,
  });

  final String title;
  final int maxSelection;
  final Set<String> excludedIds;
  final String confirmLabel;

  @override
  ConsumerState<_FriendPickerSheet> createState() => _FriendPickerSheetState();
}

class _FriendPickerSheetState extends ConsumerState<_FriendPickerSheet> {
  final Set<String> _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<FriendsOverview> friends = ref.watch(friendsProvider);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Selecciona hasta ${widget.maxSelection} '
                        '${widget.maxSelection == 1 ? 'jugador' : 'jugadores'}.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: friends.when(
              loading: () =>
                  const LoadingView(message: 'Cargando tus amistades…'),
              error: (Object error, StackTrace stack) => ErrorView(
                message: 'No pudimos cargar tus amistades.\n$error',
                onRetry: () => ref.invalidate(friendsProvider),
              ),
              data: (FriendsOverview overview) {
                final List<Friend> available = overview.friends
                    .where(
                      (Friend friend) =>
                          !widget.excludedIds.contains(friend.id),
                    )
                    .toList();

                if (available.isEmpty) {
                  return const EmptyView(
                    title: 'No hay amistades disponibles',
                    message:
                        'Solo puedes invitar amistades aceptadas que todavía '
                        'no estén en el partido.',
                    icon: Icons.group_off_outlined,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: available.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (BuildContext context, int index) {
                    final Friend friend = available[index];
                    final bool selected = _selected.contains(friend.id);
                    final bool canSelect =
                        selected || _selected.length < widget.maxSelection;
                    return CheckboxListTile(
                      value: selected,
                      onChanged: canSelect
                          ? (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selected.add(friend.id);
                                } else {
                                  _selected.remove(friend.id);
                                }
                              });
                            }
                          : null,
                      controlAffinity: ListTileControlAffinity.trailing,
                      secondary: InitialsAvatar(
                        name: friend.displayName,
                        imageUrl: friend.avatarUrl,
                      ),
                      title: Text(
                        friend.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        friend.tennisLevel?.label ?? 'Sin nivel declarado',
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_selected.toList()),
                  icon: const Icon(Icons.send_outlined),
                  label: Text(
                    _selected.isEmpty
                        ? widget.confirmLabel
                        : '${widget.confirmLabel} (${_selected.length})',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
