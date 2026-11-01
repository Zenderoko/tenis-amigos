import 'package:flutter/material.dart';

/// Campo de contraseña con opción para mostrar u ocultar el texto.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.label,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.autofillHints,
    this.enabled = true,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: widget.fieldKey,
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscure,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
