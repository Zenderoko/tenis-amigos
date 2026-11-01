import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_info.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/auth_user.dart';
import '../domain/auth_validators.dart';
import '../domain/sign_up_result.dart';
import 'auth_controller.dart';
import 'widgets/google_sign_in_button.dart';
import 'widgets/password_field.dart';

/// Pantalla de registro con correo/contraseña y Google.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _confirmationSent = false;
  bool _resending = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signUpWithEmail() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    try {
      final SignUpResult result = await ref
          .read(authControllerProvider.notifier)
          .signUpWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            displayName: _nameController.text.trim(),
          );

      if (!mounted) return;
      if (result.isAuthenticated) {
        context.go(AppRoutes.home);
      } else {
        setState(() => _confirmationSent = true);
      }
    } on AppFailure catch (error) {
      if (mounted) {
        _showError(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showError('No pudimos crear tu cuenta. Intenta de nuevo.');
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
        _showError('No pudimos crear tu cuenta. Intenta de nuevo.');
      }
    }
  }

  Future<void> _resendConfirmation() async {
    setState(() => _resending = true);
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
    } finally {
      if (mounted) {
        setState(() => _resending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AuthUser?> auth = ref.watch(authControllerProvider);
    final bool isLoading = auth.isLoading;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: _goBack,
        ),
        title: const Text('Crear cuenta'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _confirmationSent
                  ? _ConfirmationView(
                      email: _emailController.text.trim(),
                      isResending: _resending,
                      onResend: _resendConfirmation,
                      onBackToLogin: () => context.go(AppRoutes.login),
                    )
                  : _buildForm(context, isLoading),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, bool isLoading) {
    final ThemeData theme = Theme.of(context);

    return AutofillGroup(
      child: Form(
        key: _formKey,
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
              'Crea tu cuenta con tu correo o con Google.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            TextFormField(
              key: const Key('register-name'),
              controller: _nameController,
              enabled: !isLoading,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.name],
              validator: AuthValidators.displayName,
              decoration: const InputDecoration(
                labelText: 'Nombre visible',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('register-email'),
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
              fieldKey: const Key('register-password'),
              controller: _passwordController,
              label: 'Contraseña',
              enabled: !isLoading,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              validator: AuthValidators.password,
            ),
            const SizedBox(height: 12),
            PasswordField(
              fieldKey: const Key('register-confirm-password'),
              controller: _confirmController,
              label: 'Repite la contraseña',
              enabled: !isLoading,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.newPassword],
              validator: (String? value) => AuthValidators.confirmPassword(
                value,
                _passwordController.text,
              ),
              onFieldSubmitted: (_) => _signUpWithEmail(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('register-submit'),
              onPressed: isLoading ? null : _signUpWithEmail,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Crear mi cuenta'),
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
              label: 'Registrarme con Google',
              isLoading: isLoading,
              onPressed: _signInWithGoogle,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: isLoading ? null : _goBack,
              child: const Text('Ya tengo cuenta'),
            ),
          ],
        ),
      ),
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.login);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ConfirmationView extends StatelessWidget {
  const _ConfirmationView({
    required this.email,
    required this.isResending,
    required this.onResend,
    required this.onBackToLogin,
  });

  final String email;
  final bool isResending;
  final VoidCallback onResend;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Icon(
          Icons.mark_email_unread_outlined,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Revisa tu correo',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Enviamos un enlace de confirmación a $email. Ábrelo desde este '
          'dispositivo para activar tu cuenta.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: isResending ? null : onResend,
          icon: isResending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: const Text('Reenviar correo'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onBackToLogin,
          child: const Text('Volver a iniciar sesión'),
        ),
      ],
    );
  }
}
