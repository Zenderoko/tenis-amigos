import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/match.dart';

/// Etiqueta visual con el estado de un partido.
class MatchStatusBadge extends StatelessWidget {
  const MatchStatusBadge({super.key, required this.status});

  final MatchStatus status;

  Color get _color => switch (status) {
    MatchStatus.awaitingPlayers => AppColors.statusPending,
    MatchStatus.confirmed => AppColors.statusConfirmed,
    MatchStatus.cancelled => AppColors.statusCancelled,
    MatchStatus.completed => AppColors.statusCompleted,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: _color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
