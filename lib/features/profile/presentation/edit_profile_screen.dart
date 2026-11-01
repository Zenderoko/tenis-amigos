import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../../app/router.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/domain/auth_validators.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/profile_providers.dart';
import '../data/supabase_profile_repository.dart';
import '../domain/dominant_hand.dart';
import '../domain/tennis_level.dart';
import '../domain/user_profile.dart';

/// Permite editar el nombre, la foto y las preferencias de juego.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UserProfile> profile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: profile.when(
        loading: () => const LoadingView(message: 'Cargando tu perfil…'),
        error: (Object error, StackTrace stack) => ErrorView(
          message: 'No pudimos cargar tu perfil.',
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (UserProfile data) => _EditProfileForm(profile: data),
      ),
    );
  }
}

class _EditProfileForm extends ConsumerStatefulWidget {
  const _EditProfileForm({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<_EditProfileForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  TennisLevel? _level;
  DominantHand? _hand;
  Uint8List? _pickedBytes;
  String _pickedExtension = 'jpg';
  String _pickedContentType = 'image/jpeg';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _level = widget.profile.tennisLevel;
    _hand = widget.profile.dominantHand;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file == null) {
        return;
      }

      final Uint8List bytes = await file.readAsBytes();
      final String extension = p
          .extension(file.path)
          .replaceFirst('.', '')
          .toLowerCase();

      if (!mounted) return;
      setState(() {
        _pickedBytes = bytes;
        _pickedExtension = extension.isEmpty ? 'jpg' : extension;
        _pickedContentType = file.mimeType ?? _contentTypeFor(extension);
      });
    } catch (_) {
      if (mounted) {
        _showError('No pudimos abrir esa imagen. Prueba con otra.');
      }
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final AuthUser? user = ref.read(authControllerProvider).value;
    if (user == null) {
      _showError('Tu sesión expiró. Inicia sesión de nuevo.');
      return;
    }

    setState(() => _saving = true);
    try {
      final ProfileRepository repository = ref.read(profileRepositoryProvider);

      String? avatarUrl = widget.profile.avatarUrl;
      if (_pickedBytes != null) {
        avatarUrl = await repository.uploadAvatar(
          userId: user.id,
          bytes: _pickedBytes!,
          extension: _pickedExtension,
          contentType: _pickedContentType,
        );
      }

      await repository.updateProfile(
        userId: user.id,
        email: user.email,
        displayName: _nameController.text,
        tennisLevel: _level,
        dominantHand: _hand,
        avatarUrl: avatarUrl,
      );

      ref.invalidate(profileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu perfil se actualizó correctamente.')),
      );
      _close();
    } on AppFailure catch (error) {
      if (mounted) {
        _showError(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showError('No pudimos guardar tu perfil. Intenta de nuevo.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.profile);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: <Widget>[
                    _avatarPreview(),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.primary,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        color: theme.colorScheme.onPrimary,
                        tooltip: 'Cambiar foto',
                        onPressed: _saving ? null : _pickImage,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : _pickImage,
                  child: const Text('Cambiar foto'),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('edit-profile-name'),
                controller: _nameController,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                validator: AuthValidators.displayName,
                decoration: const InputDecoration(
                  labelText: 'Nombre visible',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Nivel de juego',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final TennisLevel level in TennisLevel.values)
                    ChoiceChip(
                      label: Text(level.label),
                      selected: _level == level,
                      onSelected: _saving
                          ? null
                          : (bool selected) => setState(
                              () => _level = selected ? level : null,
                            ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Mano dominante',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final DominantHand hand in DominantHand.values)
                    ChoiceChip(
                      label: Text(hand.label),
                      selected: _hand == hand,
                      onSelected: _saving
                          ? null
                          : (bool selected) =>
                                setState(() => _hand = selected ? hand : null),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              FilledButton(
                key: const Key('edit-profile-save'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarPreview() {
    final Uint8List? bytes = _pickedBytes;
    if (bytes != null) {
      return ClipOval(
        child: SizedBox(
          width: 96,
          height: 96,
          child: Image.memory(bytes, fit: BoxFit.cover),
        ),
      );
    }

    return InitialsAvatar(
      name: _nameController.text,
      imageUrl: widget.profile.avatarUrl,
      radius: 48,
    );
  }
}

String _contentTypeFor(String extension) {
  return switch (extension.toLowerCase()) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'heic' => 'image/heic',
    _ => 'image/jpeg',
  };
}
