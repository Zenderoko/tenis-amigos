import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_info.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/auth_user.dart';
import 'auth_controller.dart';
import 'widgets/google_sign_in_button.dart';

/// Pantalla de inicio de sesión con Google.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle();
      if (context.mounted) {
        context.go(AppRoutes.home);
      }
    } on AppFailure catch (error) {
      if (context.mounted) {
        _showError(context, error.message);
      }
    } catch (_) {
      if (context.mounted) {
        _showError(context, 'No pudimos iniciar sesión. Intenta de nuevo.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AuthUser?> auth = ref.watch(authControllerProvider);
    final bool isLoading = auth.isLoading;
    final ThemeData theme = Theme.of(context);

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _confirmExit(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancelar',
            onPressed: () => _handleBack(context),
          ),
          title: const Text('Iniciar sesión'),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Icon(
                      Icons.sports_tennis,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppInfo.appName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppInfo.tagline,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    GoogleSignInButton(
                      label: 'Continuar con Google',
                      isLoading: isLoading,
                      onPressed: () => _signIn(context, ref),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => context.push(AppRoutes.register),
                      child: const Text('Crear cuenta'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Usamos tu cuenta de Google para crear tu perfil y '
                      'mantener tu sesión segura.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Si Google abre su pantalla de cuenta, desliza desde '
                      'el borde o usa Atrás para volver.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    _confirmExit(context);
  }

  Future<void> _confirmExit(BuildContext context) async {
    final bool? exit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('¿Salir de TenisAmigos?'),
          content: const Text('Puedes volver a abrir la app cuando quieras.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Seguir aquí'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Salir'),
            ),
          ],
        );
      },
    );
    if (exit == true) {
      SystemNavigator.pop();
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
