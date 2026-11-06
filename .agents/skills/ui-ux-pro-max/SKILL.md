---
name: ui-ux-pro-max
description: >-
  Aplica principios de diseño UI/UX de nivel avanzado para la app Flutter "Agro+".
  Activa esta skill cuando el usuario pida crear, rediseñar o mejorar cualquier
  pantalla, widget, componente visual o sistema de diseño de la aplicación.
  Garantiza jerarquía visual, accesibilidad, Material 3 y coherencia de marca agrícola.
---

# UI/UX Pro Max — Agro+

Guía de diseño visual de nivel profesional para todas las pantallas y componentes
de la aplicación móvil **Agro+** (Flutter + Material 3).

---

## 1. Sistema de Colores

Usar **siempre** los colores definidos en `lib/core/constants/app_colors.dart`.
Nunca usar colores literales (`Color(0xFF...)`) fuera de ese archivo.

| Rol | Color | Hex |
|---|---|---|
| Primary | Verde oscuro | `#2E7D32` |
| Primary Light | Verde medio | `#4CAF50` |
| Primary Surface | Verde muy claro | `#E8F5E9` |
| Secondary | Café tierra | `#795548` |
| Background | Blanco verdoso | `#F9FBF9` |
| Error | Rojo semántico | `#D32F2F` |
| Warning | Naranja cálido | `#F57C00` |

**Regla de uso:**
- Fondos de pantalla → `AppColors.background`
- Superficies de cards → `AppColors.surface` (blanco puro)
- Texto principal → `AppColors.textPrimary` (`#1B1B1B`)
- Texto secundario → `AppColors.textSecondary` (`#6B6B6B`)
- Acciones primarias → `AppColors.primary`

---

## 2. Tipografía y Legibilidad

- Usar **siempre** el sistema de texto de `Theme.of(context).textTheme.*`.
- Nunca hardcodear `fontSize` salvo en casos de componentes de marca específicos.
- Jerarquía obligatoria:

| Nivel | Style | Uso |
|---|---|---|
| H1 | `headlineMedium` (bold) | Títulos de pantalla (Login, Registro) |
| H2 | `headlineSmall` (bold) | Secciones principales |
| H3 | `titleLarge` (semibold) | Subtítulos de card |
| Body | `bodyMedium` | Descripción de productos |
| Caption | `bodySmall` | Precios, fechas, metadatos |

- **Accesibilidad agrícola:** Mínimo `fontSize: 14` para texto de contenido. Los agricultores usan el celular bajo luz solar directa. Contraste mínimo WCAG AA (4.5:1).

---

## 3. Espaciado y Layout

Usar siempre múltiplos de **8px** (sistema de 8-point grid):

```dart
// ✅ Correcto
const SizedBox(height: 8)   // micro-gap
const SizedBox(height: 16)  // gap entre elementos
const SizedBox(height: 24)  // gap entre secciones
const SizedBox(height: 32)  // gap grande
const SizedBox(height: 48)  // separador de bloques

// Padding estándar de pantalla
const EdgeInsets.symmetric(horizontal: 24, vertical: 16)

// Padding interno de card
const EdgeInsets.all(16)
```

---

## 4. Componentes — Reglas Estrictas

### Cards de Producto
```dart
Card(
  elevation: 2,
  shadowColor: Colors.black12,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  ),
  child: /* contenido */,
)
```

### Botones Primarios
- Ancho completo (`minimumSize: Size(double.infinity, 52)`)
- Radio: `BorderRadius.circular(12)`
- Siempre mostrar `CircularProgressIndicator` de `strokeWidth: 2` durante carga

### Imágenes de Producto
- Usar siempre `CachedNetworkImage` con placeholder shimmer
- Aspect ratio fijo 4:3
- `borderRadius` superior de 16px en cards, sin radio inferior

### Chips de Categoría
- Fondo `AppColors.primarySurface` (inactivo) / `AppColors.primary` (activo)
- Alto fijo: 32px
- `BorderRadius.circular(8)`

### Empty States
- Siempre mostrar ícono grande (64px), mensaje y botón de acción
- Usar iconos de la familia `outlined` de Material Icons
- Color del ícono: `Colors.grey.shade400`

---

## 5. Pantallas — Estructura Obligatoria

Toda pantalla principal de Agro+ debe seguir este patrón:

```dart
Scaffold(
  backgroundColor: AppColors.background,
  appBar: AppBar(/* según app_theme */),
  body: SafeArea(
    child: /* contenido */,
  ),
  // floatingActionButton solo si hay acción primaria clara
)
```

### Pantallas de Lista (Catálogo, Chat)
1. **Header**: Barra de búsqueda + filtro de categorías (chips horizontales scrollables)
2. **Body**: `ListView.builder` o `GridView` con shimmer durante carga
3. **Empty state**: Si no hay datos
4. **FAB**: Solo para productores (crear producto)

### Pantallas de Detalle
1. **Hero image** en la parte superior (altura 240px)
2. **Sheet deslizable** con información debajo
3. **Botón de acción fijo** al fondo (`SafeArea` + `Padding`)

---

## 6. Feedback y Estados

Todo componente interactivo debe manejar explícitamente estos 4 estados:

| Estado | Implementación |
|---|---|
| **Loading** | Shimmer skeleton o CircularProgressIndicator |
| **Success** | Transición suave al contenido real |
| **Empty** | Empty state con ícono + mensaje + CTA |
| **Error** | SnackBar flotante rojo + opción de reintentar |

---

## 7. Navegación y Transiciones

- Pantallas principales (Home, Mapa, Chat) → Fade transition (sin movimiento)
- Pantallas de detalle / formularios → Slide from right
- Modales / bottom sheets → Slide from bottom con `showModalBottomSheet`
- La `BottomNavigationBar` usa Material 3 `NavigationBar` (ya configurada en `AppRouter`)

---

## 8. Accesibilidad

- Todo widget interactivo debe tener `semanticsLabel` o `tooltip`
- Tamaño mínimo de área táctil: 48×48px (`MaterialTapTargetSize.padded`)
- Nunca usar color como único diferenciador de estado
- Texto sobre fondos de color: siempre verificar contraste

