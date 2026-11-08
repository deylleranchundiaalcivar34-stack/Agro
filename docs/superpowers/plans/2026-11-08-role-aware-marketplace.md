# Inicio, navegación y compra por rol — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir que compradores y productores compren mediante interés/chat, reservar publicación a productores, personalizar Inicio y añadir un **+** azul central solo a la navegación del productor.

**Architecture:** Mantener el rol de cuenta actual como capacidad de publicación. Reutilizar el `ProductsViewModel`, rutas y tablas existentes. Generalizar las acciones de compra para roles `buyer` y `producer`, con exclusión de auto-compra protegida en RLS. Renderizar una navegación adaptada al rol en `MainNavigationView` conservando los cinco destinos; el productor obtiene una acción central adicional de publicación.

**Tech Stack:** Flutter/Dart, Provider, GoRouter, Supabase RLS/Postgres.

**Spec:** `docs/superpowers/specs/2026-11-08-role-aware-marketplace-design.md`

## Archivos involucrados

- Modify: `lib/features/home/presentation/views/home_view.dart` — orden condicional de Inicio y enlaces a catálogo/publicaciones.
- Modify: `lib/features/main/presentation/views/main_navigation_view.dart` — barra adaptada al rol, acción central y visibilidad al desplazar.
- Modify: `lib/core/router/app_router.dart` — proteger la ruta de publicación para productores sin bloquear catálogo ni compra.
- Modify: `lib/features/products/presentation/views/product_detail_view.dart` — interés/chat para comprador o productor sobre publicaciones ajenas.
- Modify: `lib/features/map/presentation/views/map_view.dart` — contacto desde la ficha de Mapa para cualquier comprador/productor autenticado, nunca con la propia zona/producto.
- Modify: `lib/features/chat/data/repositories/chat_repository.dart` y `lib/features/chat/data/models/chat_conversation.dart` — usar semántica de interesado sin renombrar columnas remotas.
- Modify: `lib/features/chat/presentation/views/chat_list_view.dart` — etiquetas neutrales cuando quien inicia puede ser productor.
- Modify: `lib/features/products/data/repositories/products_repository.dart` — comprobar rol productor antes de crear una publicación desde el flujo real.
- Create migration with `supabase migration new allow_producer_interest`: `supabase/migrations/<timestamp>_allow_producer_interest.sql` — ajustar inserción de chats/intereses manteniendo la protección por participante y propietario.

## Global Constraints

- El rol de productor es el único que puede publicar, editar, retirar o cambiar cantidad de productos.
- Los roles `buyer` y `producer` pueden explorar, registrar interés y abrir chat por productos publicados de otra persona.
- No permitir auto-interés ni auto-chat.
- Mantener `id_comprador` en las tablas existentes; no crear tablas o columnas para la dualidad.
- Conservar cinco destinos: Inicio, Comprar, Mapa, Chat y Perfil.
- El botón central solo es para productores, es azul (`AppColors.info`) y muestra solo `+`; su etiqueta accesible es `Publicar producto`.
- No cambiar splash, carga, bienvenida, autenticación ni permisos de ubicación.
- No agregar APIs ni dependencias.

## Review Focus

1. Comprador que intenta abrir `/products/create` manualmente → se bloquea en router/servicio/RLS y no crea filas.
2. Productor interesado en un producto de otra persona → se crea un interés/chat y se conserva lectura/escritura solo para participantes.
3. Productor dueño de la publicación → detalle no ofrece compra y RLS también rechaza auto-interés/chat.
4. Administrador → no recibe publicación ni permisos de compra por esta regla.
5. Productor en móvil estrecho → el **+** queda al centro y no tapa Mapa ni Perfil; comprador conserva los cinco destinos.
6. Desplazamiento hacia abajo/arriba y `disableAnimations` → barra oculta/reaparece con el comportamiento actual sin tapar campos.

---

### Task 1: Políticas de compra y publicación

**Files:**
- Create: `supabase/migrations/<version>_allow_producer_interest.sql`
- Review: políticas activas de `chats_negociacion`, `intereses_preventa` y `productos` en el proyecto Agro.

**Interfaces:**
- Consumes: políticas actuales `chats_insert_buyer`, `intereses_insert_buyer`, `productos_insert_owner_producer` y funciones `private.has_role`, `private.can_view_product`, `private.owns_product`.
- Produces: políticas de inserción que aceptan `buyer` o `producer` para interés/chat sobre productos publicados de terceros; publicación sigue limitada a `producer`.

- [x] Confirmar la definición actual y dependencias de cada política antes de generar la migración; no recrear funciones `SECURITY DEFINER`.
- [x] Crear migración versionada que reemplace las dos políticas buyer-only y permita los roles buyer/producer únicamente cuando `id_comprador = auth.uid()`, el producto esté publicado y el usuario no sea su propietario.
- [x] Mantener sin cambios las políticas de lectura de chats/mensajes, `productos_insert_owner_producer` y las políticas de dueño/productor.
- [x] Inspeccionar el diff SQL y los asesores de seguridad; dejar la migración local para revisión sin aplicarla al proyecto remoto en esta tarea.

### Task 2: Acciones de interés y chat con interesado

**Files:**
- Modify: `lib/features/products/presentation/views/product_detail_view.dart`
- Modify: `lib/features/map/presentation/views/map_view.dart`
- Modify: `lib/features/chat/data/repositories/chat_repository.dart`
- Modify: `lib/features/chat/data/models/chat_conversation.dart`
- Modify: `lib/features/chat/presentation/views/chat_list_view.dart`

**Interfaces:**
- Consumes: migración y acceso a interés/chat de Task 1; rol `AuthViewModel.selectedRole`; `ProductsViewModel` y rutas actuales.
- Produces: ambos roles buyer/producer pueden iniciar interés/chat con publicaciones ajenas; los modelos de UI llaman `interestedUserId` a la contraparte que inicia aunque la columna SQL histórica siga siendo `id_comprador`.

- [x] Mostrar acciones de compra para `buyer` y `producer` cuando el producto esté publicado y tenga cantidad; ocultarlas al propietario y a admin.
- [x] En la ficha del Mapa, permitir contacto a comprador/productor sobre un producto del productor seleccionado solo si no pertenece al usuario actual.
- [x] Generalizar nombres internos/comunicaciones de `buyerId` a interesado cuando corresponda; conservar el alias SQL `id_comprador` al mapear datos.
- [x] Sustituir subtítulos de chat dependientes de rol por textos según propiedad, como “Interés en tu publicación” y “Conversación sobre un producto”.
- [x] Mantener `can_access_chat` y la lectura/escritura de mensajes limitada a participantes.

### Task 3: Inicio y publicación según el rol

**Files:**
- Modify: `lib/features/home/presentation/views/home_view.dart`
- Modify: `lib/features/products/presentation/views/products_catalog_view.dart` solo si el acceso a Mis publicaciones necesita ajustarse.

**Interfaces:**
- Consumes: Task 2 y `ProductsViewModel` compartido.
- Produces: inicio comprador priorizado a compra; inicio productor priorizado a publicaciones propias y publicación, manteniendo catálogo/compra disponibles.

- [x] Para comprador, mostrar búsqueda, categorías, productos publicados, Mapa y Chat sin accesos de publicación.
- [x] Para productor, cargar sus publicaciones privadas al entrar en Inicio, añadir acceso visible a Mis publicaciones y mantener búsqueda/categorías/productos de terceros para comprar.
- [x] Reutilizar el listado privado de `ProductsViewModel` para cualquier conteo propio; no agregar métricas de ventas/pedidos/ingresos.
- [x] Mantener CTA de publicación fuera del Inicio si la acción central del menú queda como acceso principal.

### Task 4: Acción central azul de la barra de productor

**Files:**
- Modify: `lib/features/main/presentation/views/main_navigation_view.dart`
- Modify: `lib/core/router/app_router.dart`

**Interfaces:**
- Consumes: rol activo de `AuthViewModel`; ramas indexadas actuales para Inicio, productos, Mapa, Chat y Perfil.
- Produces: cinco destinos comunes y acción central exclusiva del productor que abre `AppRoutes.productCreate`.

- [x] Renderizar barra de cinco destinos para compradores con la etiqueta de catálogo **Comprar**.
- [x] Renderizar para productores una barra integrada en el orden **Inicio, Comprar, +, Mapa, Chat, Perfil**; el control central es un botón circular azul con icono **+** únicamente.
- [x] Añadir `Tooltip` y semántica `Publicar producto`; mantener 48 × 48 px mínimo de interacción y layout adaptado a anchos compactos.
- [x] Reusar la lógica actual de scroll-hide, restablecimiento al cambiar de ruta y el camino de `MediaQuery.disableAnimations`.
- [x] Bloquear acceso de compradores/admin a la ruta de creación y validar `producer` en `ProductsRepository.createPreorderProduct`; conservar también la política RLS productora sin afectar catálogo/detalle.

### Task 5: Verificación final en dispositivo y Supabase

**Files:**
- No tocar archivos de splash/carga/bienvenida.

- [x] Revisar análisis Flutter y compilación Android.
- [ ] Revisar en un teléfono el menú buyer y producer, barra oculta/visible, botón central y pantallas estrechas; iniciar sesión manualmente con cada cuenta. Vista de productor abierta en Android y confirmada visualmente; el sistema bloqueó la automatización del gesto de desplazamiento y falta validar una cuenta buyer.
- [ ] Verificar con las dos cuentas que buyer compra/no publica, producer compra/publica, y el propietario no puede comprarse a sí mismo.
- [ ] Confirmar en Supabase que un tercero no lee chats/mensajes; compradores no insertan productos; productores sí pueden crear solo para su propio `id_productor`.
- [x] Verificar que ningún archivo de splash, carga o bienvenida cambió como parte de esta integración.

## Alcance de esta entrega

La interfaz, las comprobaciones de rol y la migración versionada están implementadas en esta rama. La migración no se aplicó al Supabase remoto; por eso, los productores podrán registrar interés y abrir chats con otros productores cuando esa migración se aplique. Queda pendiente la comprobación manual con cuentas buyer/producer en un dispositivo y la verificación de RLS después de aplicar la migración.
