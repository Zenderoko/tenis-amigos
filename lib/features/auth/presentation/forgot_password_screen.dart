import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/auth_validators.dart';
import 'auth_controller.dart';

/// Solicita a Supabase un enlace para restablecer la contraseña.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _sending = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) {
        setState(() => _sent = true);
      }
    } on AppFailure catch (error) {
      if (mounted) {
        _showError(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showError(
          'No pudimos enviar el correo de recuperación. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: _goBack,
        ),
        title: const Text('Recuperar contraseña'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _sent ? _buildSuccess(context) : _buildForm(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(
            Icons.lock_reset_outlined,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            '¿Olvidaste tu contraseña?',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Escribe el correo de tu cuenta y te enviaremos un enlace para '
            'crear una contraseña nueva.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          TextFormField(
            key: const Key('forgot-email'),
            controller: _emailController,
            enabled: !_sending,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.email],
            validator: AuthValidators.email,
            onFieldSubmitted: (_) => _send(),
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('forgot-submit'),
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enviar enlace'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _sending ? null : _goBack,
            child: const Text('Volver a iniciar sesión'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Icon(
          Icons.mark_email_read_outlined,
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
          'Si existe una cuenta con ${_emailController.text.trim()}, recibirás '
          'un enlace para restablecer tu contraseña. Ábrelo desde este '
          'dispositivo.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _sending ? null : _send,
          icon: const Icon(Icons.refresh),
          label: const Text('Enviar de nuevo'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _goBack,
          child: const Text('Volver a iniciar sesión'),
        ),
      ],
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
