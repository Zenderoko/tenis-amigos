import 'package:flutter/material.dart';

import '../utils/avatar_utils.dart';

/// Avatar circular con las iniciales de un nombre.
///
/// Es solo una solución visual: cuando exista la foto de perfil real (Etapa 2)
/// se mostrará esa imagen.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.radius = 20,
    this.color,
  });

  final String name;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color background = color ?? scheme.primaryContainer;
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: Text(
        AvatarUtils.initialsFor(name),
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
