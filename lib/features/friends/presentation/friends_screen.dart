import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/prototype_banner.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/friend.dart';
import 'friends_providers.dart';

/// Pantalla de Amigos: solicitudes pendientes y lista de amigos.
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FriendRequest>> requests = ref.watch(
      friendRequestsProvider,
    );
    final AsyncValue<List<Friend>> friends = ref.watch(friendsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Amigos'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Agregar amigo',
            onPressed: () => _showMockMessage(
              context,
              'Invitar amigos estará disponible en la Etapa 3.',
            ),
            icon: const Icon(Icons.person_add_alt),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(friendRequestsProvider);
          ref.invalidate(friendsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            const PrototypeBanner(),
            const SizedBox(height: 20),
            SectionHeader(
              title: (requests.value?.isEmpty ?? false)
                  ? 'Solicitudes pendientes'
                  : 'Solicitudes pendientes (${requests.value?.length ?? 0})',
            ),
            requests.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: LoadingView(),
              ),
              error: (Object error, StackTrace stack) => ErrorView(
                message: 'No pudimos cargar las solicitudes.',
                onRetry: () => ref.invalidate(friendRequestsProvider),
              ),
              data: (List<FriendRequest> data) => data.isEmpty
                  ? const _MutedText('No tienes solicitudes pendientes.')
                  : Column(
                      children: <Widget>[
                        for (final FriendRequest request in data) ...<Widget>[
                          _RequestTile(
                            request: request,
                            onAccept: () {
                              ref
                                  .read(friendRequestsProvider.notifier)
                                  .accept(request.id);
                              _showMockMessage(
                                context,
                                '${request.displayName} ahora es tu amigo (prototipo).',
                              );
                            },
                            onReject: () => ref
                                .read(friendRequestsProvider.notifier)
                                .reject(request.id),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Mis amigos'),
            friends.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: LoadingView(),
              ),
              error: (Object error, StackTrace stack) => ErrorView(
                message: 'No pudimos cargar tu lista de amigos.',
                onRetry: () => ref.invalidate(friendsProvider),
              ),
              data: (List<Friend> data) => data.isEmpty
                  ? const _MutedText('Todavía no tienes amigos agregados.')
                  : Column(
                      children: <Widget>[
                        for (final Friend friend in data)
                          _FriendTile(friend: friend),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMockMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  final FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            InitialsAvatar(name: request.displayName),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                request.displayName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Rechazar',
              onPressed: onReject,
              icon: const Icon(Icons.close),
            ),
            FilledButton(
              onPressed: onAccept,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend});

  final Friend friend;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: InitialsAvatar(name: friend.displayName),
      title: Text(
        friend.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: friend.tennisLevel == null
          ? null
          : Text('Nivel: ${friend.tennisLevel}'),
      trailing: friend.isFavorite
          ? Icon(Icons.star, color: theme.colorScheme.tertiary)
          : null,
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Perfil de ${friend.displayName} (prototipo).'),
        ),
      ),
    );
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
