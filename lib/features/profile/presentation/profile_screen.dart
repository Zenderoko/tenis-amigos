import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_info.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/profile_providers.dart';
import '../domain/user_profile.dart';

/// Pantalla de Perfil: información personal y configuración básica.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<UserProfile> profile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: profile.when(
        loading: () => const LoadingView(message: 'Cargando tu perfil…'),
        error: (Object error, StackTrace stack) => ErrorView(
          message: 'No pudimos cargar tu perfil.',
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (UserProfile data) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            _ProfileHeader(profile: data),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Preferencias'),
            Card(
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    value: _notificationsEnabled,
                    onChanged: (bool value) =>
                        setState(() => _notificationsEnabled = value),
                    secondary: const Icon(Icons.notifications_outlined),
                    title: const Text('Notificaciones'),
                    subtitle: const Text(
                      'Avisos de invitaciones y recordatorios',
                    ),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.language_outlined),
                    title: Text('Idioma'),
                    subtitle: Text('Español'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Cuenta'),
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Editar perfil'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.editProfile),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.password_outlined),
                    title: const Text('Cambiar contraseña'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.changePassword),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Cerrar sesión'),
                    onTap: _signOut,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Acerca de'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showAbout(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '${AppInfo.appName} · v${AppInfo.appVersion}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authControllerProvider.notifier).signOut();
      if (mounted) {
        context.go(AppRoutes.login);
      }
    } on AppFailure catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('No pudimos cerrar la sesión. Intenta de nuevo.');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text(AppInfo.appName),
        content: const Text(
          '${AppInfo.tagline}.\n\nVersión ${AppInfo.appVersion}.\n\n'
          'Aplicación en desarrollo. Los datos mostrados son de ejemplo.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            InitialsAvatar(
              name: profile.displayName,
              imageUrl: profile.avatarUrl,
              radius: 36,
            ),
            const SizedBox(height: 12),
            Text(
              profile.displayName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              profile.email,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: <Widget>[
                if (profile.tennisLevel != null)
                  Chip(
                    avatar: const Icon(Icons.speed, size: 16),
                    label: Text('Nivel: ${profile.tennisLevel!.label}'),
                  ),
                if (profile.dominantHand != null)
                  Chip(
                    avatar: const Icon(Icons.back_hand_outlined, size: 16),
                    label: Text(profile.dominantHand!.label),
                  ),
                Chip(
                  avatar: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(
                    'Desde ${AppDateFormatters.monthYear(profile.memberSince)}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
