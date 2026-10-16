import 'package:flutter/material.dart';

/// Paleta de la identidad visual de TenisAmigos.
///
/// Inspirada en una cancha de tenis: verde de pista, amarillo de pelota de
/// tenis y naranja de arcilla. Cambia estos valores para reajustar la marca.
abstract final class AppColors {
  /// Verde de pista de tenis: color principal de la marca.
  static const Color courtGreen = Color(0xFF177245);

  /// Verde oscuro para degradados y superficies.
  static const Color courtGreenDark = Color(0xFF0B4A2C);

  /// Amarillo de pelota de tenis: color de acento.
  static const Color ballYellow = Color(0xFFD7F24A);

  /// Naranja de arcilla: acento secundario.
  static const Color clay = Color(0xFFC75B39);

  /// Azul de pista rápida, usado para estados informativos.
  static const Color courtBlue = Color(0xFF17618C);

  /// Colores por estado de partido.
  static const Color statusConfirmed = Color(0xFF1E8E3E);
  static const Color statusPending = Color(0xFFB9820A);
  static const Color statusCancelled = Color(0xFF8A8A8A);
  static const Color statusCompleted = Color(0xFF1565C0);
}
