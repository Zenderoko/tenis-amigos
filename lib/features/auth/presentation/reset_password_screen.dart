import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/state_views.dart';
import '../data/auth_link_events.dart';
import '../domain/auth_user.dart';
import '../domain/auth_validators.dart';
import 'auth_controller.dart';
import 'widgets/password_field.dart';

/// Permite definir una contraseña nueva después de abrir el enlace de
/// recuperación enviado por Supabase.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updatePassword(newPassword: _passwordController.text);

      AuthLinkEvents.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente.')),
      );
      context.go(AppRoutes.home);
    } on AppFailure catch (error) {
      if (mounted) {
        _showError(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showError('No pudimos actualizar tu contraseña. Intenta de nuevo.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _cancel() {
    AuthLinkEvents.clear();
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AuthUser?> auth = ref.watch(authControllerProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _cancel();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancelar',
            onPressed: _cancel,
          ),
          title: const Text('Nueva contraseña'),
        ),
        body: SafeArea(
          child: auth.when(
            loading: () => const LoadingView(
              message: 'Validando el enlace de recuperación…',
            ),
            error: (Object error, StackTrace stack) => ErrorView(
              message: 'No pudimos validar el enlace. Solicita uno nuevo.',
              onRetry: () => ref.invalidate(authControllerProvider),
            ),
            data: (AuthUser? user) {
              if (user == null) {
                return EmptyView(
                  title: 'El enlace no es válido',
                  message:
                      'El enlace de recuperación expiró o ya fue usado. '
                      'Solicita uno nuevo desde el inicio de sesión.',
                  icon: Icons.link_off,
                  action: FilledButton(
                    onPressed: () {
                      AuthLinkEvents.clear();
                      context.go(AppRoutes.forgotPassword);
                    },
                    child: const Text('Solicitar otro enlace'),
                  ),
                );
              }

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Icon(
                            Icons.password_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Crea una contraseña nueva',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Usa al menos 8 caracteres.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 28),
                          PasswordField(
                            fieldKey: const Key('reset-password'),
                            controller: _passwordController,
                            label: 'Contraseña nueva',
                            enabled: !_saving,
                            textInputAction: TextInputAction.next,
                            autofillHints: const <String>[
                              AutofillHints.newPassword,
                            ],
                            validator: AuthValidators.password,
                          ),
                          const SizedBox(height: 12),
                          PasswordField(
                            fieldKey: const Key('reset-confirm-password'),
                            controller: _confirmController,
                            label: 'Repite la contraseña',
                            enabled: !_saving,
                            textInputAction: TextInputAction.done,
                            autofillHints: const <String>[
                              AutofillHints.newPassword,
                            ],
                            validator: (String? value) =>
                                AuthValidators.confirmPassword(
                                  value,
                                  _passwordController.text,
                                ),
                            onFieldSubmitted: (_) => _save(),
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            key: const Key('reset-submit'),
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Guardar contraseña'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
