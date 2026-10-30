import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_info.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/auth_user.dart';
import 'auth_controller.dart';
import 'widgets/google_sign_in_button.dart';

/// Pantalla de registro con Google.
///
/// Supabase crea la cuenta la primera vez que el usuario inicia sesión con
/// Google. Después se guarda su perfil en la tabla `profiles`.
class RegisterScreen extends ConsumerWidget {
  const RegisterScreen({super.key});

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
        _showError(context, 'No pudimos crear tu cuenta. Intenta de nuevo.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AuthUser?> auth = ref.watch(authControllerProvider);
    final bool isLoading = auth.isLoading;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => _goBack(context),
        ),
        title: const Text('Crear cuenta'),
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
                    Icons.person_add_alt_1_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Únete a ${AppInfo.appName}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crea tu cuenta con Google. Usaremos tu nombre y foto para '
                    'tu perfil.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  GoogleSignInButton(
                    label: 'Registrarme con Google',
                    isLoading: isLoading,
                    onPressed: () => _signIn(context, ref),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: isLoading ? null : () => _goBack(context),
                    child: const Text('Ya tengo cuenta'),
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
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.login);
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
