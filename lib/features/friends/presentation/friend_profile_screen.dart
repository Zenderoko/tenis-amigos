import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/section_header.dart';
import '../domain/friend.dart';
import 'friends_providers.dart';

/// Perfil de un amigo, con la opción de eliminar la amistad.
class FriendProfileScreen extends ConsumerStatefulWidget {
  const FriendProfileScreen({super.key, required this.friend});

  final Friend friend;

  @override
  ConsumerState<FriendProfileScreen> createState() =>
      _FriendProfileScreenState();
}

class _FriendProfileScreenState extends ConsumerState<FriendProfileScreen> {
  bool _removing = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Friend friend = widget.friend;
    final bool hasPreferences =
        friend.tennisLevel != null || friend.dominantHand != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil de amigo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: <Widget>[
                  InitialsAvatar(
                    name: friend.displayName,
                    imageUrl: friend.avatarUrl,
                    radius: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    friend.displayName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (hasPreferences)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: <Widget>[
                        if (friend.tennisLevel != null)
                          Chip(
                            avatar: const Icon(Icons.speed, size: 16),
                            label: Text('Nivel: ${friend.tennisLevel!.label}'),
                          ),
                        if (friend.dominantHand != null)
                          Chip(
                            avatar: const Icon(
                              Icons.back_hand_outlined,
                              size: 16,
                            ),
                            label: Text(friend.dominantHand!.label),
                          ),
                      ],
                    )
                  else
                    Text(
                      'Este amigo todavía no completó su nivel ni su mano '
                      'dominante.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Amistad'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Si eliminas la amistad, dejarán de aparecer en la lista '
                    'del otro y en la tuya.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    key: const Key('remove-friend-button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                    onPressed: _removing ? null : _confirmRemove,
                    icon: _removing
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.error,
                            ),
                          )
                        : const Icon(Icons.person_remove_outlined),
                    label: Text(_removing ? 'Eliminando…' : 'Eliminar amistad'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ThemeData theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Eliminar amistad'),
          content: Text(
            '¿Quieres eliminar a ${widget.friend.displayName} de tus amigos? '
            'Esta acción se aplica a ambos.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('confirm-remove-friend'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _removing = true);
    try {
      await ref.read(friendsProvider.notifier).removeFriend(widget.friend.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on AppFailure catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('No pudimos eliminar la amistad. Intenta de nuevo.');
      }
    } finally {
      if (mounted) {
        setState(() => _removing = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
