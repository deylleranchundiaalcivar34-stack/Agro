# Plan: Exploración del mapa Agro+

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Mejorar el descubrimiento de productores y productos en el mapa con búsqueda, filtros y una solicitud de ubicación voluntaria.

**Architecture:** Extender la pantalla `MapView` y sus controles locales; reutilizar `ProducerMapEntry`, `ProductsRepository`, `PublicLocationRepository`, Geolocator y OpenStreetMap. No se modifica el esquema remoto.

**Tech Stack:** Flutter/Dart, flutter_map, Geolocator, Supabase ya integrado.

**Spec:** `docs/superpowers/specs/2026-11-07-map-marketplace-design.md`

**Visual reference:** `Cli_mapa.png`, `Pro_mapa.png` y `Cli_edicion_ubicacion.png` dentro del `Untitled.zip` enviado por el usuario. Adaptar la estructura de `Cli_mapa`; no incorporar datos de ejemplo ni los polígonos GIS/logística de las otras pantallas.

## Global Constraints

- Permiso de ubicación solo tras tocar **Buscar cerca de mí**; mapa y búsqueda manual disponibles sin permiso.
- Ubicación privada del comprador solo en memoria; zonas de productor siguen aproximadas y voluntarias.
- Sin cambios a splash, carga, bienvenida, autenticación, base de datos o dependencias.

## Review Focus

1. Permiso concedido, denegado, denegado permanentemente y GPS apagado → el mapa informa el estado y mantiene navegación manual.
2. Búsqueda por producto/categoría/productor → resultados coinciden con las publicaciones y zonas visibles.
3. Cero productores/productos y error de red → estados claros con acción de reintento donde corresponda.
4. Ficha de productor y radios pequeños → contenido desplazable, producto y contacto alcanzables.
5. Ubicación compartida → no se escribe la coordenada del comprador en Supabase.

---

### Task 1: Búsqueda, filtros y ubicación justificada

**Files:**
- Modify: `lib/features/map/presentation/views/map_view.dart`
- Test: `test/map_view_test.dart`

- [ ] Añadir búsqueda local por alias, sector, producto y categoría, y chips de categorías disponibles.
- [ ] Sustituir el acceso aislado de ubicación por **Buscar cerca de mí** con explicación previa y estados para todos los permisos/GPS.
- [ ] Conservar el radio, habilitándolo solo con ubicación, sin impedir el uso manual cuando no esté disponible.
- [ ] Actualizar pruebas existentes para búsquedas, permiso concedido/denegado, GPS apagado y mapa sin resultados.

### Task 2: Resultados y ficha inferior

**Files:**
- Modify: `lib/features/map/presentation/views/map_view.dart`
- Test: `test/map_view_test.dart`

- [ ] Hacer más reconocibles los marcadores de productor, manteniendo su posición pública aproximada.
- [ ] Presentar el productor seleccionado en una hoja inferior desplazable con zona, productos y contacto; conservar navegación al detalle.
- [ ] Ajustar estados vacío/error/cargando para que comuniquen qué puede hacer la persona.
- [ ] Revisar tamaños compactos, semántica y atribución de OpenStreetMap.

### Task 3: Revisión del módulo

- [ ] Ejecutar pruebas enfocadas de `test/map_view_test.dart` y análisis Flutter.
- [ ] Compilar y revisar la pantalla en Android; revisar configuración iOS existente sin cambiar splash/carga/bienvenida.
- [ ] Revisar permisos: ninguna coordenada del comprador se persiste y el mapa funciona con permiso rechazado.
