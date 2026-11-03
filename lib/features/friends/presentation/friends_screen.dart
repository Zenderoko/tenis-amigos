import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/domain/auth_validators.dart';
import '../domain/friend.dart';
import 'friends_providers.dart';

/// Pantalla de Amigos: solicitudes recibidas y enviadas, y lista de amigos.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final Set<String> _busyRequestIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final AsyncValue<FriendsOverview> overview = ref.watch(friendsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Amigos'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Agregar amigo',
            onPressed: _openAddFriendDialog,
            icon: const Icon(Icons.person_add_alt),
          ),
        ],
      ),
      body: overview.when(
        loading: () => const LoadingView(message: 'Cargando tus amigos…'),
        error: (Object error, StackTrace stack) => ListView(
          children: <Widget>[
            const SizedBox(height: 120),
            ErrorView(
              message: 'No pudimos cargar tus amigos.\n$error',
              onRetry: () => ref.invalidate(friendsProvider),
            ),
          ],
        ),
        data: (FriendsOverview data) =>
            RefreshIndicator(onRefresh: _refresh, child: _buildContent(data)),
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(friendsProvider);
    await ref.read(friendsProvider.future);
  }

  Widget _buildContent(FriendsOverview overview) {
    if (overview.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const SizedBox(height: 64),
          EmptyView(
            title: 'Agrega a tu primer amigo',
            message:
                'Busca a tus amigos por el correo con el que se registraron '
                'en TenisAmigos.',
            icon: Icons.people_outline,
            action: FilledButton.icon(
              onPressed: _openAddFriendDialog,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Agregar amigo'),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        if (overview.incomingRequests.isNotEmpty) ...<Widget>[
          SectionHeader(
            title:
                'Solicitudes recibidas '
                '(${overview.incomingRequests.length})',
          ),
          for (final FriendRequest request in overview.incomingRequests) ...[
            _RequestTile(
              request: request,
              busy: _busyRequestIds.contains(request.id),
              onAccept: () => _respond(request, accept: true),
              onReject: () => _respond(request, accept: false),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
        ],
        if (overview.outgoingRequests.isNotEmpty) ...<Widget>[
          SectionHeader(
            title:
                'Solicitudes enviadas '
                '(${overview.outgoingRequests.length})',
          ),
          for (final SentFriendRequest request
              in overview.outgoingRequests) ...[
            _SentRequestTile(
              request: request,
              busy: _busyRequestIds.contains(request.id),
              onCancel: () => _cancel(request),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
        ],
        SectionHeader(
          title: overview.friends.isEmpty
              ? 'Mis amigos'
              : 'Mis amigos (${overview.friends.length})',
        ),
        if (overview.friends.isEmpty)
          const _MutedText('Todavía no tienes amigos agregados.')
        else
          for (final Friend friend in overview.friends)
            _FriendTile(friend: friend),
      ],
    );
  }

  Future<void> _openAddFriendDialog() async {
    final FriendRequestResult? result = await showDialog<FriendRequestResult>(
      context: context,
      builder: (BuildContext context) => const _AddFriendDialog(),
    );
    if (result == null || !mounted) {
      return;
    }
    _showMessage(_messageFor(result));
  }

  String _messageFor(FriendRequestResult result) {
    final String name = result.targetName;
    return switch (result.outcome) {
      FriendRequestOutcome.sent => 'Solicitud enviada a $name.',
      FriendRequestOutcome.accepted => 'Tú y $name ahora son amigos.',
      FriendRequestOutcome.alreadyFriends =>
        '$name ya está en tu lista de amigos.',
      FriendRequestOutcome.alreadyRequested =>
        'Ya enviaste una solicitud a $name.',
    };
  }

  Future<void> _respond(FriendRequest request, {required bool accept}) async {
    if (_busyRequestIds.contains(request.id)) {
      return;
    }
    setState(() => _busyRequestIds.add(request.id));
    try {
      await ref
          .read(friendsProvider.notifier)
          .respond(request.id, accept: accept);
      if (!mounted) {
        return;
      }
      _showMessage(
        accept
            ? '${request.sender.displayName} ahora es tu amigo.'
            : 'Solicitud rechazada.',
      );
    } on AppFailure catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('No pudimos actualizar la solicitud.');
      }
    } finally {
      if (mounted) {
        setState(() => _busyRequestIds.remove(request.id));
      }
    }
  }

  Future<void> _cancel(SentFriendRequest request) async {
    if (_busyRequestIds.contains(request.id)) {
      return;
    }
    setState(() => _busyRequestIds.add(request.id));
    try {
      await ref.read(friendsProvider.notifier).cancel(request.id);
      if (mounted) {
        _showMessage('Solicitud a ${request.recipient.displayName} cancelada.');
      }
    } on AppFailure catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('No pudimos cancelar la solicitud.');
      }
    } finally {
      if (mounted) {
        setState(() => _busyRequestIds.remove(request.id));
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  final FriendRequest request;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            InitialsAvatar(
              name: request.sender.displayName,
              imageUrl: request.sender.avatarUrl,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    request.sender.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (request.sender.tennisLevel != null)
                    Text(
                      'Nivel: ${request.sender.tennisLevel!.label}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...<Widget>[
              IconButton(
                key: Key('friend-request-reject-${request.id}'),
                tooltip: 'Rechazar',
                onPressed: onReject,
                icon: const Icon(Icons.close),
              ),
              FilledButton(
                key: Key('friend-request-accept-${request.id}'),
                onPressed: onAccept,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text('Aceptar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SentRequestTile extends StatelessWidget {
  const _SentRequestTile({
    required this.request,
    required this.busy,
    required this.onCancel,
  });

  final SentFriendRequest request;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: InitialsAvatar(
          name: request.recipient.displayName,
          imageUrl: request.recipient.avatarUrl,
        ),
        title: Text(
          request.recipient.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Solicitud pendiente',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                key: Key('friend-request-cancel-${request.id}'),
                tooltip: 'Cancelar solicitud',
                onPressed: onCancel,
                icon: const Icon(Icons.close),
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
    final List<String> details = <String>[
      if (friend.tennisLevel != null) 'Nivel: ${friend.tennisLevel!.label}',
      if (friend.dominantHand != null) friend.dominantHand!.label,
    ];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: InitialsAvatar(
        name: friend.displayName,
        imageUrl: friend.avatarUrl,
      ),
      title: Text(
        friend.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: details.isEmpty ? null : Text(details.join(' · ')),
    );
  }
}

class _AddFriendDialog extends ConsumerStatefulWidget {
  const _AddFriendDialog();

  @override
  ConsumerState<_AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends ConsumerState<_AddFriendDialog> {
  final TextEditingController _emailController = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final String? validation = AuthValidators.email(_emailController.text);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final FriendRequestResult result = await ref
          .read(friendsProvider.notifier)
          .sendRequest(_emailController.text);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
        _submitting = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'No pudimos enviar la solicitud. Intenta de nuevo.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar amigo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Escribe el correo con el que tu amigo se registró en '
            'TenisAmigos.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('add-friend-email'),
            controller: _emailController,
            enabled: !_submitting,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            autofillHints: const <String>[AutofillHints.email],
            decoration: InputDecoration(
              labelText: 'Correo electrónico',
              hintText: 'amigo@ejemplo.com',
              errorText: _error,
              prefixIcon: const Icon(Icons.mail_outline),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('add-friend-submit'),
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar solicitud'),
        ),
      ],
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
