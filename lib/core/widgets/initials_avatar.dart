import 'package:flutter/material.dart';

import '../utils/avatar_utils.dart';

/// Avatar circular con la foto del usuario o, si no hay, sus iniciales.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.radius = 20,
    this.color,
    this.imageUrl,
  });

  final String name;
  final double radius;
  final Color? color;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = _InitialsCircle(
      name: name,
      radius: radius,
      color: color,
    );
    final String? url = imageUrl?.trim();

    if (url == null || url.isEmpty) {
      return fallback;
    }

    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stack) {
                return fallback;
              },
        ),
      ),
    );
  }
}

class _InitialsCircle extends StatelessWidget {
  const _InitialsCircle({required this.name, required this.radius, this.color});

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
