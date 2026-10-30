import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';

/// Elemento descriptor para cada pestaña de la barra de navegación flotante.
class NavigationItemData {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const NavigationItemData({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
/// Vista contenedora de navegación principal (MainNavigationView) de Agro+.
///
/// Implementa:
/// - [StatefulNavigationShell] para persistencia de estado (no reconstruye vistas).
/// - Barra de navegación flotante con forma de pastilla (BorderRadius.circular(100)).
/// - Fondo blanco puro con sombra difuminada (alpha 0.05).
/// - Animación de Slider elástica ('impeccable') con resaltador #2E7D32.
/// - Íconos inactivos grises (#9E9E9E) e ícono activo en blanco puro sobre el resaltador.
class MainNavigationView extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationView({
    super.key,
    required this.navigationShell,
  });

  static const List<NavigationItemData> _items = [
    NavigationItemData(
      label: 'Inicio',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    NavigationItemData(
      label: 'Catálogo',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
    ),
    NavigationItemData(
      label: 'Mapa',
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
    ),
    NavigationItemData(
      label: 'Chat',
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
    ),
    NavigationItemData(
      label: 'Perfil',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  void _onTabSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ─────────────────────────────────────────────────────────────
          // 1. CUERPO DE LA RAMA ACTIVA (StatefulShellRoute / IndexedStack)
          // ─────────────────────────────────────────────────────────────
          Positioned.fill(
            child: navigationShell,
          ),

          // ─────────────────────────────────────────────────────────────
          // 2. BARRA DE NAVEGACIÓN FLOTANTE (ESTILO PASTILLA CIRCULAR 100)
          // ─────────────────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 18, right: 18, bottom: 14),
                child: Container(
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white, // Blanco puro
                    borderRadius: BorderRadius.circular(100), // Pastilla
                    border: Border.all(
                      color: AppColors.divider.withValues(alpha: 0.35),
                      width: 1,
                    ),
                    boxShadow: [
                      // Sombra difuminada elegante de diseño Prime
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 28,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = constraints.maxWidth / _items.length;
                      final indicatorWidth = itemWidth - 8;
                      const indicatorHeight = 54.0;

                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          // ─────────────────────────────────────────────
                          // SLIDER / RESALTADOR ELÁSTICO COLOR #2E7D32
                          // ─────────────────────────────────────────────
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutBack, // Animación elástica fluida
                            left: (currentIndex * itemWidth) + 4,
                            top: 6,
                            width: indicatorWidth,
                            height: indicatorHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary, // #2E7D32
                                borderRadius: BorderRadius.circular(100),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.30),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // ─────────────────────────────────────────────
                          // ÍTEMS INTERACTIVOS DE LA BARRA
                          // ─────────────────────────────────────────────
                          Row(
                            children: List.generate(_items.length, (index) {
                              final item = _items[index];
                              final isSelected = index == currentIndex;

                              return Expanded(
                                child: _NavBarItemWidget(
                                  data: item,
                                  isSelected: isSelected,
                                  onTap: () => _onTabSelected(index),
                                ),
                              );
                            }),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
/// Widget individual para cada botón de la barra de navegación con micro-interacción.
class _NavBarItemWidget extends StatefulWidget {
  final NavigationItemData data;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItemWidget({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavBarItemWidget> createState() => _NavBarItemWidgetState();
}

class _NavBarItemWidgetState extends State<_NavBarItemWidget> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: Center(
        child: AnimatedScale(
          scale: _isPressed ? 0.94 : (isSelected ? 1.04 : 1.0),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? widget.data.activeIcon : widget.data.icon,
                size: 22,
                // Blanco si está sobre el resaltador; gris #9E9E9E si está inactivo
                color: isSelected ? Colors.white : const Color(0xFF9E9E9E),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF9E9E9E),
                  letterSpacing: 0.1,
                ),
                child: Text(
                  widget.data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
