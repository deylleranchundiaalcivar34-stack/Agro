# Plan: Inicio marketplace de Agro+

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Reordenar Inicio para que primero ayude a descubrir productos y productores, manteniendo las métricas reales y accesos actuales.

**Architecture:** Reutilizar el `ProductsViewModel` compartido y componentes de catálogo existentes. Mantener `HomeViewModel` para conteos reales, sin añadir agregados falsos ni nuevas consultas innecesarias.

**Tech Stack:** Flutter/Dart, Provider, GoRouter, Supabase y componentes de catálogo existentes.

**Spec:** `docs/superpowers/specs/2026-11-07-home-marketplace-design.md`

**Visual reference:** `Cli_inicio.png` (catálogo comprador) y `prod_inicio.png` (panel productor) dentro del `Untitled.zip`. Usar la primera para el descubrimiento común; dejar el panel de ventas para una fase con soporte de solicitudes/órdenes reales.

## Global Constraints

- Una composición marketplace común; conservar permisos/roles que ya aplican a cada acción.
- Mostrar solo publicaciones, categorías y conteos reales.
- No añadir dependencias, pagos, pedidos, entregas ni cambios de base de datos.
- No tocar animaciones de arranque, splash, carga ni bienvenida.

## Review Focus

1. Catálogo vacío, cargando o con error → estado entendible y acceso para reintentar/abrir catálogo.
2. Datos dinámicos → tarjetas usan producto, precio, categoría y foto real; no contenido de ejemplo.
3. Teléfono estrecho o texto ampliado → búsqueda, tarjetas y métricas no desbordan.
4. Acciones de catálogo, mapa, chat, perfil y publicación → conservan rutas actuales.
5. Refresco → conteos y productos se actualizan sin consultas duplicadas innecesarias.

---

### Task 1: Orden marketplace y accesos

**Files:**
- Modify: `lib/features/home/presentation/views/home_view.dart`
- Test: crear o actualizar `test/home_view_test.dart`

- [x] Reorganizar la jerarquía en saludo/perfil, búsqueda de catálogo, categorías, productos publicados y acceso a Mapa.
- [x] Conservar las rutas existentes de catálogo, mapa, chat, perfil y publicación.
- [x] Mantener acceso de búsqueda conectado al catálogo y sus filtros actuales.

### Task 2: Datos de productos y resumen compacto

**Files:**
- Modify: `lib/features/home/presentation/views/home_view.dart`
- Modify solo si hace falta: `lib/features/home/presentation/viewmodels/home_viewmodel.dart`
- Test: `test/home_view_test.dart` y `test/home_viewmodel_test.dart`

- [x] Reutilizar productos publicados del `ProductsViewModel` y las tarjetas/cargas de imagen existentes.
- [x] Bajar los conteos existentes a un resumen compacto; no crear métricas de venta, pedido o reseña.
- [x] Mostrar carga, error y estado vacío usando acciones recuperables.

### Task 3: Verificación de Inicio

- [ ] Ejecutar pruebas enfocadas de Home y ViewModel y análisis Flutter.
- [ ] Revisar Android y web en anchos compactos; confirmar navegación y datos.
- [ ] Confirmar que ningún archivo de splash, carga o bienvenida cambió.
