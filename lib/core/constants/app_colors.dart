import 'package:flutter/material.dart';

/// Paleta de colores de Agro+
/// Centralizada aquí para garantizar consistencia visual en toda la app.
abstract class AppColors {
  // --- Verdes (colores primarios de marca) ---
  static const Color primary = Color(0xFF2E7D32);       // Verde oscuro
  static const Color primaryLight = Color(0xFF4CAF50);  // Verde medio
  static const Color primarySurface = Color(0xFFE8F5E9); // Verde muy claro (fondos)

  // --- Tierra (colores secundarios de marca) ---
  static const Color secondary = Color(0xFF795548);      // Café tierra
  static const Color secondaryLight = Color(0xFFA1887F); // Café claro

  // --- Neutros ---
  static const Color background = Color(0xFFF9FBF9);    // Blanco verdoso
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1B1B1B);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color divider = Color(0xFFE0E0E0);

  // --- Semánticos ---
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFF57C00);
  static const Color success = Color(0xFF388E3C);
  static const Color info = Color(0xFF1976D2);
}

