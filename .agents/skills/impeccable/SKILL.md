---
name: impeccable
description: >-
  Garantiza código limpio, micro-animaciones fluidas con flutter_animate,
  transiciones sin tirones y manejo perfecto de estados de carga en Agro+.
  Activa esta skill cuando el usuario pida animaciones, transiciones, efectos
  visuales, feedback táctil, skeleton loaders o cualquier aspecto de pulido
  visual e interactividad de la app Flutter.
---

# Impeccable — Animaciones y Calidad de Código

Guía de animaciones, micro-interacciones y estándares de calidad de código
para la app **Agro+** usando `flutter_animate` y principios de Motion Design.

---

## 1. Paquete Principal: `flutter_animate`

Antes de generar cualquier animación, verificar que `flutter_animate` esté
en `pubspec.yaml`. Si no está, añadirlo:

```yaml
dependencies:
  flutter_animate: ^4.5.0
```

Importar siempre con:
```dart
import 'package:flutter_animate/flutter_animate.dart';
```

---

## 2. Animaciones de Entrada — Estándar Agro+

### Patrón base para toda pantalla nueva:
```dart
// Fade + slide sutil desde abajo — aplica a cualquier widget principal
Widget build(BuildContext context) {
  return Column(
    children: [
      _HeaderWidget()
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.05, curve: Curves.easeOut),

      _ContentWidget()
        .animate(delay: 150.ms)
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.05, curve: Curves.easeOut),
    ],
  );
}
```

### Para listas de items (cards de productos, mensajes de chat):
```dart
// Animar cada item con delay escalonado
ListView.builder(
  itemBuilder: (context, index) {
    return ProductCard(product: products[index])
      .animate(delay: (index * 60).ms)   // escalonado: 0ms, 60ms, 120ms...
      .fadeIn(duration: 300.ms)
      .slideX(begin: 0.03, curve: Curves.easeOut);
  },
)
```

---

## 3. Micro-interacciones — Feedback Táctil

### Botones con efecto de escala:
```dart
// Wrap cualquier botón personalizado con esto
GestureDetector(
  onTap: onTap,
  child: AnimatedScale(
    scale: _isPressed ? 0.96 : 1.0,
    duration: const Duration(milliseconds: 120),
    curve: Curves.easeOut,
    child: /* botón */,
  ),
)
```

### Chips de categoría seleccionables:
```dart
// Cambio de color animado en selección
AnimatedContainer(
  duration: const Duration(milliseconds: 200),
  curve: Curves.easeInOut,
  decoration: BoxDecoration(
    color: isSelected ? AppColors.primary : AppColors.primarySurface,
    borderRadius: BorderRadius.circular(8),
  ),
)
```

### Ícono de favorito (like) en productos:
```dart
IconButton(
  onPressed: onToggleFavorite,
  icon: Icon(
    isFavorite ? Icons.favorite : Icons.favorite_border,
    color: isFavorite ? Colors.red : Colors.grey,
  ),
).animate(target: isFavorite ? 1.0 : 0.0)
  .scale(begin: const Offset(1,1), end: const Offset(1.3,1.3),
         duration: 150.ms, curve: Curves.easeOut)
  .then()
  .scale(begin: const Offset(1.3,1.3), end: const Offset(1,1),
         duration: 100.ms)
```

---

## 4. Skeleton Loaders (Estados de Carga)

Usar siempre `shimmer` durante la carga de datos. **Nunca** mostrar
`CircularProgressIndicator` para listas completas.

```dart
import 'package:shimmer/shimmer.dart';

// Skeleton de card de producto
Widget _buildProductSkeleton() {
  return Shimmer.fromColors(
    baseColor: Colors.grey.shade300,
    highlightColor: Colors.grey.shade100,
    child: Card(
      child: Column(
        children: [
          Container(
            height: 160,
            color: Colors.white,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 16, width: double.infinity, color: Colors.white),
                const SizedBox(height: 8),
                Container(height: 14, width: 120, color: Colors.white),
                const SizedBox(height: 8),
                Container(height: 20, width: 80, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
```

---

## 5. Transiciones de Pantalla — GoRouter

Estas ya están configuradas en `app_router.dart`. Respetar siempre:

| Ruta | Transición | Duración |
|---|---|---|
| Login ↔ Splash | `FadeTransition` | 300ms |
| Login → Registro | `SlideTransition` (derecha) | 250ms |
| Home → Detalle | `SlideTransition` (derecha) | 250ms |
| Home → Crear Producto | `SlideTransition` (arriba) | 300ms |
| Chat Room | `SlideTransition` (derecha) | 250ms |

---

## 6. Pantalla de Splash — Animación de Marca

```dart
// Secuencia de animación para SplashView (ya implementada)
// Seguir este patrón para cualquier pantalla de onboarding
AnimationController _controller; // duration: 1200ms

// 1. Logo aparece con fade + scale (elastic out)
// 2. Texto del nombre fade in con delay 200ms
// 3. Tagline fade in con delay 400ms
// 4. Indicador de carga fade in con delay 800ms
// 5. Navegar después de 2000ms total
```

---

## 7. Reglas de Rendimiento — Campo Agro+

Los usuarios de Agro+ pueden estar en zonas rurales con dispositivos de gama baja.

### ✅ Hacer:
- Duración máxima de animaciones de entrada: **400ms**
- Delay máximo entre items de lista: **80ms**
- Usar `Curves.easeOut` para entradas, `Curves.easeIn` para salidas
- Detener animaciones al salir de la pantalla (`dispose` del controller)
- Usar `RepaintBoundary` en widgets que se animan frecuentemente

### ❌ Nunca:
- Animaciones infinitas en pantallas de lista (queman batería)
- `AnimationController` sin `dispose()`
- Animaciones simultáneas en más de 5 widgets a la vez
- `opacity: 0` con `Visibility` → usar `Opacity` o `.fadeIn()`
- Blur animado (`BackdropFilter`) en listas scrollables

---

## 8. Estándar de Calidad de Código

### Separación de responsabilidades:
```
❌ Mal: Lógica de animación mezclada en el ViewModel
✅ Bien: AnimationController vive en el State del widget
✅ Bien: flutter_animate en el build() sin controllers manuales
```

### Nomenclatura de animaciones:
```dart
// Siempre usar constantes para duraciones reutilizadas
class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration stagger = Duration(milliseconds: 60);
}
```

### Checklist antes de entregar cualquier pantalla:
- [ ] ¿Tiene animación de entrada?
- [ ] ¿El estado de carga tiene skeleton (no spinner para listas)?
- [ ] ¿Los botones tienen feedback visual táctil?
- [ ] ¿Las transiciones de navegación funcionan sin tirones?
- [ ] ¿Todos los `AnimationController` hacen `dispose()`?
- [ ] ¿Las animaciones se detienen cuando el widget no está visible?

