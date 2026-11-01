import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_info.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/auth_user.dart';
import '../domain/auth_validators.dart';
import 'auth_controller.dart';
import 'widgets/google_sign_in_button.dart';
import 'widgets/password_field.dart';

/// Pantalla de inicio de sesión con correo/contraseña y Google.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    try {
      await ref
          .read(authControllerProvider.notifier)
          .signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) {
        context.go(AppRoutes.home);
      }
    } on AppFailure catch (error) {
      if (!mounted) return;
      if (error.code == 'email_not_confirmed') {
        await _showUnconfirmedDialog(error.message);
      } else {
        _showError(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showError('No pudimos iniciar sesión. Intenta de nuevo.');
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle();
      if (mounted) {
        context.go(AppRoutes.home);
      }
    } on AppFailure catch (error) {
      if (mounted) {
        _showError(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showError('No pudimos iniciar sesión. Intenta de nuevo.');
      }
    }
  }

  Future<void> _showUnconfirmedDialog(String message) async {
    final bool? resend = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirma tu correo'),
          content: Text(
            '$message\n\n¿Quieres que te enviemos el correo de confirmación de '
            'nuevo?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reenviar correo'),
            ),
          ],
        );
      },
    );

    if (resend == true) {
      await _resendConfirmation();
    }
  }

  Future<void> _resendConfirmation() async {
    try {
      await ref
          .read(authControllerProvider.notifier)
          .resendConfirmationEmail(email: _emailController.text.trim());
      if (mounted) {
        _showError('Te enviamos un nuevo correo de confirmación.');
      }
    } on AppFailure catch (error) {
      if (mounted) {
        _showError(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showError('No pudimos reenviar el correo. Intenta de nuevo.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AuthUser?> auth = ref.watch(authControllerProvider);
    final bool isLoading = auth.isLoading;
    final ThemeData theme = Theme.of(context);

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _confirmExit();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancelar',
            onPressed: _handleBack,
          ),
          title: const Text('Iniciar sesión'),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
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
                        const SizedBox(height: 28),
                        TextFormField(
                          key: const Key('login-email'),
                          controller: _emailController,
                          enabled: !isLoading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const <String>[AutofillHints.email],
                          validator: AuthValidators.email,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        PasswordField(
                          fieldKey: const Key('login-password'),
                          controller: _passwordController,
                          label: 'Contraseña',
                          enabled: !isLoading,
                          textInputAction: TextInputAction.done,
                          autofillHints: const <String>[AutofillHints.password],
                          validator: AuthValidators.password,
                          onFieldSubmitted: (_) => _signInWithEmail(),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: isLoading
                                ? null
                                : () => context.push(AppRoutes.forgotPassword),
                            child: const Text('¿Olvidaste tu contraseña?'),
                          ),
                        ),
                        FilledButton(
                          key: const Key('login-submit'),
                          onPressed: isLoading ? null : _signInWithEmail,
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Entrar'),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: <Widget>[
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'o',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 20),
                        GoogleSignInButton(
                          label: 'Continuar con Google',
                          isLoading: isLoading,
                          onPressed: _signInWithGoogle,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () => context.push(AppRoutes.register),
                          child: const Text('Crear cuenta'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    _confirmExit();
  }

  Future<void> _confirmExit() async {
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

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
