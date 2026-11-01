import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/auth_user.dart';
import '../domain/auth_validators.dart';
import 'auth_controller.dart';
import 'widgets/password_field.dart';

/// Permite cambiar la contraseña de una sesión ya autenticada.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _currentController.dispose();
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
          .changePassword(
            currentPassword: _currentController.text,
            newPassword: _passwordController.text,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente.')),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.profile);
      }
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

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AuthUser?> auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.profile);
            }
          },
        ),
        title: const Text('Cambiar contraseña'),
      ),
      body: SafeArea(
        child: auth.when(
          loading: () => const LoadingView(message: 'Cargando tu cuenta…'),
          error: (Object error, StackTrace stack) => ErrorView(
            message: 'No pudimos cargar tu cuenta.',
            onRetry: () => ref.invalidate(authControllerProvider),
          ),
          data: (AuthUser? user) {
            if (user == null) {
              return EmptyView(
                title: 'Tu sesión no está activa',
                message: 'Inicia sesión de nuevo para cambiar tu contraseña.',
                icon: Icons.lock_outline,
                action: FilledButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('Volver a iniciar sesión'),
                ),
              );
            }

            return Center(
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
                            Icons.password_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Actualiza tu contraseña',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Usa al menos 8 caracteres y una contraseña '
                            'distinta de la actual.',
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
                            fieldKey: const Key('change-current-password'),
                            controller: _currentController,
                            label: 'Contraseña actual',
                            enabled: !_saving,
                            textInputAction: TextInputAction.next,
                            autofillHints: const <String>[
                              AutofillHints.password,
                            ],
                            validator: AuthValidators.currentPassword,
                          ),
                          const SizedBox(height: 12),
                          PasswordField(
                            fieldKey: const Key('change-new-password'),
                            controller: _passwordController,
                            label: 'Contraseña nueva',
                            enabled: !_saving,
                            textInputAction: TextInputAction.next,
                            autofillHints: const <String>[
                              AutofillHints.newPassword,
                            ],
                            validator: (String? value) =>
                                AuthValidators.newPassword(
                                  value,
                                  _currentController.text,
                                ),
                          ),
                          const SizedBox(height: 12),
                          PasswordField(
                            fieldKey: const Key('change-confirm-password'),
                            controller: _confirmController,
                            label: 'Repite la contraseña nueva',
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
                            key: const Key('change-password-submit'),
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
              ),
            );
          },
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
