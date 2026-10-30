import 'package:flutter/material.dart';

/// Paleta de colores oficial de Agro+.
/// Principio de [ui-ux-pro-max]: nunca usar colores directos fuera de este archivo.
abstract class AppColors {
  // ── Verdes principales de marca ─────────────────────────────────────────────
  static const Color primary        = Color(0xFF2E7D32); // Verde principal
  static const Color primaryDark    = Color(0xFF1B5E20); // Verde oscuro (hover / pressed)
  static const Color primaryLight   = Color(0xFF4CAF50); // Verde medio
  static const Color primarySurface = Color(0xFFE8F5E9); // Verde muy claro (fondos/chips)

  // ── Secundarios de marca ──────────────────────────────────────────────────
  static const Color secondary      = Color(0xFF795548); // Café tierra
  static const Color secondaryLight = Color(0xFFA1887F); // Café claro

  // ── Neutros ───────────────────────────────────────────────────────────────
  static const Color background     = Color(0xFFF7F9F6); // Fondo neutro claro (pedido)
  static const Color surface        = Color(0xFFFFFFFF); // Blanco puro (cards)
  static const Color surfaceVariant = Color(0xFFF1F5F1);

  // ── Texto ─────────────────────────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFF1B1B1B);
  static const Color textSecondary  = Color(0xFF6B6B6B);
  static const Color textHint       = Color(0xFF9E9E9E);

  // ── Bordes de inputs ──────────────────────────────────────────────────────
  static const Color inputBorder    = Color(0xFFCFD8DC); // Borde inactivo (pedido)
  static const Color inputFocused   = Color(0xFF2E7D32); // Borde seleccionado (pedido)
  static const Color divider        = Color(0xFFE0E0E0);

  // ── Semánticos ────────────────────────────────────────────────────────────
  static const Color error          = Color(0xFFD32F2F);
  static const Color warning        = Color(0xFFF57C00);
  static const Color success        = Color(0xFF388E3C);
  static const Color info           = Color(0xFF1976D2);
}
