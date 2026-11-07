# Agro+ Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unificar productos, mapa y chat con datos reales sobre `0b9f6bd`, conservando el login local y preparando Android, web e iOS.

**Architecture:** Integrar selectivamente la rama de productos y reemplazar los datos simulados de mapa/chat por repositorios Supabase. Crear una ubicación pública voluntaria separada de las direcciones privadas. Mantener `chats_negociacion` y `mensajes` como fuente única del chat.

**Tech Stack:** Flutter/Dart, Provider, GoRouter, Supabase Auth/Postgres/Realtime, Cloudinary, Geolocator, Flutter Map/OpenStreetMap.

**Spec:** `docs/superpowers/specs/2026-11-07-agro-integration-design.md` (aprobado por el usuario)

## Global Constraints

- Partir del commit local `0b9f6bd`; no mover ni subir `main` hasta revisar el diff y la verificación.
- CAPTCHA queda excluido. TOTP es opcional; una cuenta inscrita debe completar su desafío antes de acceder a rutas protegidas.
- No colocar `service_role`, secretos de Cloudinary ni otros secretos de servidor en Flutter, `.env` empaquetado o Git.
- La ubicación pública es aproximada, manual y voluntaria. Nunca publicar el GPS del dispositivo automáticamente.
- Mantener RLS para todas las tablas expuestas y verificar lectura y escritura con roles reales.
- Preparar configuración iOS; la ejecución iOS requiere un Mac.

## Review Focus

1. Sesión restaurada con TOTP pendiente: la ruta profunda vuelve al desafío; agregar a Task 2.
2. Dos toques simultáneos en Contactar: existe un solo chat; agregar a Task 6.
3. Permiso de ubicación negado: el mapa sigue usable y no etiqueta un punto predeterminado como ubicación del usuario; agregar a Task 5.
4. Falla de Cloudinary después de crear producto: la interfaz informa guardado parcial y evita duplicar; agregar a Task 3.
5. Mensaje rechazado por red o RLS: se conserva el borrador o se muestra estado fallido; agregar a Task 7.

---

### Task 1: Preparar copia aislada y fuentes

**Files:** `pubspec.yaml`, `pubspec.lock`, `android/app/src/main/AndroidManifest.xml`, `lib/core/router/app_router.dart`; archivos de `feature/products-crud` y `feature/map-chat` que se seleccionen en las tareas posteriores.

**Interfaces:** Consume `0b9f6bd` y las referencias actuales de GitHub. Produce una copia aislada con el commit local preservado y las ramas disponibles para inspección.

- [ ] Usar `superpowers:using-git-worktrees`: comprobar estado de Git, reutilizar un worktree adecuado o crear uno desde `0b9f6bd` con la herramienta nativa.
- [ ] Obtener refs remotas actuales. Si `git fetch` queda bloqueado por DNS o permisos, solicitar la escalación técnica necesaria; no reemplazar archivos a ciegas.
- [ ] Ejecutar `flutter test --no-pub` y `flutter analyze --no-pub` como línea base, registrando limitaciones del entorno.
- [ ] Comparar cada fuente con su ancestro y registrar archivos superpuestos. Integrar únicamente cambios propios de cada módulo; `feature/jhonatan-auth` ya está incluida en el historial.
- [ ] Verificar `git diff --check`, `git status --short` y que `.env` continúa sin seguimiento. Confirmar que el commit remoto que elimina `run_web.bat` no reintroduce el archivo.

### Task 2: Corregir guarda TOTP y conservar autenticación local

**Files:** Modify `lib/features/auth/presentation/viewmodels/auth_viewmodel.dart`, `lib/core/router/app_router.dart`, `lib/features/profile/presentation/views/profile_view.dart`; Test `test/auth_mfa_guard_test.dart`.

**Interfaces:** Consume `AuthViewModel.mfaRequired` y `AppRoutes.mfaChallenge`. Produce una condición de acceso que exige TOTP solo a cuentas inscritas y una etiqueta de biometría que no promete login.

- [ ] Escribir pruebas de redirect para sesión restaurada, login, ruta profunda y usuario sin TOTP. La sesión con `mfaRequired` debe ir a `mfaChallenge` y no a `home`.
- [ ] Ejecutar las pruebas y confirmar que fallan con la guarda actual.
- [ ] Cambiar la condición del router y el estado Auth para no tratar un desafío pendiente como acceso completo; permitir la ruta del desafío y la salida de sesión.
- [ ] Ajustar el texto de Perfil para describir la huella como comprobación local opcional; confirmar ausencia de CAPTCHA.
- [ ] Ejecutar las pruebas de auth y `dart analyze lib/features/auth lib/core/router` sin errores. Revisar el diff y guardar un commit aislado.

### Task 3: Integrar productos y Cloudinary

**Files:** Modify `lib/features/products/data/models/agricultural_product.dart`, `lib/features/products/data/repositories/products_repository.dart`, `lib/features/products/presentation/viewmodels/products_viewmodel.dart`, `lib/features/products/presentation/views/product_create_view.dart`, `lib/features/products/presentation/views/product_detail_view.dart`, `lib/features/products/presentation/views/products_catalog_view.dart`, `lib/core/router/app_router.dart`, `pubspec.yaml`, `pubspec.lock`; Create/port `lib/features/products/data/services/product_storage_service.dart`, `lib/features/products/presentation/views/product_edit_view.dart` and focused widgets from `feature/products-crud`; Test `test/product_integration_test.dart` plus selected branch tests.

**Interfaces:** `ProductsRepository` remains the UI's data gateway. It exposes create, get, edit, change quantity and visibility, and interest; `ProductStorageService.subirImagen(XFile)` returns an HTTPS URL or a typed upload error. Extend `AgriculturalProduct` as the one model used by the app; adapt the branch's `ProductModel` fields and tests to it instead of keeping two competing product models.

- [ ] Port the product branch's relevant tests and add a failing case for partial upload/DB failure and owner mismatch.
- [ ] Run focused tests and confirm the new cases fail before implementation.
- [ ] Integrate the repository, storage service, model fields, screens, routes and `http` dependency without replacing auth or unrelated router changes.
- [ ] Run focused product tests, existing catalog tests and analyzer. Resolve the actual `productos`, `unidad_medida` and `fotografias_producto` schema; retain error states and no duplicate publish on uncertain result.
- [ ] Verify the Cloudinary preset with a disposable sample only when test access is available; record preset mode/limits and result without exposing credentials. Review diff and save an isolated commit.

### Task 4: Datos de ubicación pública voluntaria

**Files:** Create Supabase CLI generated migration under `supabase/migrations/`; Create `lib/features/map/data/models/public_producer_location.dart`, `lib/features/map/data/repositories/public_location_repository.dart`, `lib/features/map/presentation/views/public_location_edit_view.dart`; Modify `lib/features/profile/presentation/views/profile_view.dart`, `lib/core/router/app_router.dart`; Test `test/public_location_repository_test.dart` and `test/public_location_view_test.dart`.

**Interfaces:** `PublicLocationRepository.listPublished()` returns locations with alias and approximate coordinates; `saveMine(alias, placeName, latitude, longitude)` publishes a manually chosen point; `removeMine()` withdraws it. A unique producer ID prevents duplicate public locations.

- [ ] Write tests for own publish/update/remove, other producer read, buyer write denial, no automatic GPS copy, and missing fields.
- [ ] Run focused tests and confirm failure.
- [ ] Create migration via `supabase migration new` (or the connected project's supported workflow), with a separate table, RLS, producer-only writes and authenticated read of published locations. Review access through a buyer and producer identity before applying.
- [ ] Build the repository and producer-only editor. Select the approximate zone manually and show explicit publish/withdraw actions.
- [ ] Run tests and analyzer; apply the reviewed migration, verify RLS and row visibility, review diff and save a commit.

### Task 5: Mapa con productores reales

**Files:** Modify `lib/features/map/presentation/views/map_view.dart`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`; Test `test/map_view_test.dart`.

**Interfaces:** Consume `PublicLocationRepository.listPublished()` and `ProductsRepository.getPublishedProducts()`. Show only producers with a published approximate location and available products; calculate distance only after permission grants an actual position.

- [ ] Write tests for location denied, no public locations, geofence filtering, and marker contact using a real product ID.
- [ ] Confirm tests fail with the example producer list.
- [ ] Replace example data with repository results; add loading, empty and error states, visible OSM attribution, a stable user agent and real geofence filtering.
- [ ] Merge Android location/Internet permissions with the auth deep link and biometric permission; add iOS `NSLocationWhenInUseUsageDescription`.
- [ ] Run focused tests and analyzer, inspect Android and web where available, review diff and save a commit.

### Task 6: Chat persistente e idempotente

**Files:** Create Supabase CLI generated migration under `supabase/migrations/`; Create `lib/features/chat/data/models/chat_conversation.dart`, `lib/features/chat/data/models/chat_message.dart`, `lib/features/chat/data/repositories/chat_repository.dart`; Test `test/chat_repository_test.dart`.

**Interfaces:** `ChatRepository.openForProduct(productId)` returns the one chat UUID for buyer/product; `listMine()` returns only accessible chats with product labels; `messages(chatId)` returns ordered messages; `watchMessages(chatId)` streams authorized changes; `send(chatId, content)` returns persisted message or typed failure.

- [ ] Write tests for buyer opens chat, two concurrent opens return one UUID, producer/third party access denied, ordered messages and send failure.
- [ ] Confirm tests fail before implementation.
- [ ] Add unique `(id_producto,id_comprador)` after checking existing duplicates; enable `mensajes` in `supabase_realtime`. Preserve existing participant RLS and avoid exposing `usuarios`.
- [ ] Implement repository with existing table/column names, UUIDs, idempotent creation and subscription cancellation. Query labels from product data, not private profiles.
- [ ] Run focused tests and analyzer; apply the reviewed migration, verify RLS and Realtime with two test accounts, review diff and save a commit.

### Task 7: Chat UI and cross-module navigation

**Files:** Modify `lib/features/chat/presentation/views/chat_list_view.dart`, `lib/features/chat/presentation/views/chat_room_view.dart`, `lib/features/products/presentation/views/product_detail_view.dart`, `lib/features/map/presentation/views/map_view.dart`, `lib/core/router/app_router.dart`; Test `test/chat_flow_test.dart`.

**Interfaces:** Consume `ChatRepository` from Task 6. Product detail/map Contactar navigates with the persisted chat UUID; list and room show real states and never invent messages.

- [ ] Write widget tests for empty list, loading, new message arrival, send failure, failed draft retention and product-to-chat navigation.
- [ ] Confirm tests fail with the placeholder UI.
- [ ] Integrate the real list and room with Provider/GoRouter, participant labels, retry/error states and lifecycle-safe Realtime subscription.
- [ ] Run focused tests and analyzer; manually verify buyer/producer conversation in two sessions and no third-party access.
- [ ] Review diff, check cancellation and save a commit.

### Task 8: Integración final y entrega revisable

**Files:** Modify `README.md` with setup and limits; update `pubspec.lock` and platform-generated files only as needed.

**Interfaces:** Consume all previous tasks and produce an integration branch with a reproducible verification report. `main` remains untouched until user reviews the result.

- [ ] Run `flutter pub get`, `flutter analyze`, `flutter test`, `git diff --check` and an Android/web smoke test where tool access permits; capture exact exit codes and failures.
- [ ] Check tracked files and history for accidental `.env` or server secrets; document Supabase migration and Cloudinary preset setup without values.
- [ ] Compare final branch with `0b9f6bd` and current remote `main`; confirm auth, products, map, chat and platform permissions appear in the diff.
- [ ] Run whole-branch review; fix material findings and rerun affected checks.
- [ ] Present branch, diff, test results, environment limitations and any remaining external configuration before proposing a merge or push.
