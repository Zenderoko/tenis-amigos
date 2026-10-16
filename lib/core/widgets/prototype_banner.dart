import 'package:flutter/material.dart';

/// Aviso visible para indicar que una pantalla usa datos ficticios de prototipo.
///
/// Se usa únicamente durante las primeras etapas visuales (Etapa 1). Debe
/// eliminarse cuando la pantalla consuma datos reales del backend.
class PrototypeBanner extends StatelessWidget {
  const PrototypeBanner({
    super.key,
    this.message = 'Prototipo visual · datos de ejemplo, aún sin conexión al backend',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.science_outlined,
            size: 18,
            color: scheme.onTertiaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                color: scheme.onTertiaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
