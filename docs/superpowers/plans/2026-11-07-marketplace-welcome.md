# Plan de implementación: Bienvenida marketplace de Agro+

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Crear una bienvenida ligera de Agro+ que explique el marketplace y dirija a Inicio, registro o acceso administrativo sin alterar la autenticación existente.

**Architecture:** Hacer que `AgroApp` siempre inicie en una nueva `WelcomeView`, sin bifurcar por estado de sesión. La bienvenida usará el logo, colores y rutas existentes, más tres mensajes locales con `AnimatedSwitcher`. Login, registro, MFA y recuperación seguirán siendo pantallas y flujos separados; la protección actual resolverá la sesión al pulsar una acción.

**Tech Stack:** Flutter/Dart, Material 3, GoRouter, Provider y `Timer` estándar para rotar texto. Las transiciones usan widgets Flutter existentes; no se agrega dependencia.

**Spec:** `docs/superpowers/specs/2026-11-07-marketplace-welcome-design.md`

## Global Constraints

- Conservar autenticación por correo y contraseña; CAPTCHA sigue excluido.
- No añadir inicio con Google, proveedores externos, llamadas de red ni dependencias nuevas.
- La app siempre abre la bienvenida, con o sin sesión.
- MFA pendiente puede ver la bienvenida, pero al intentar entrar se exige el desafío TOTP actual antes de acceder a rutas protegidas.
- El acceso administrativo conserva la ruta de login actual con `mode=admin`.
- La bienvenida usa `AppColors` y `assets/images/logotipo_oficial.png`.
- Con movimiento reducido no se anima ni rota automáticamente el mensaje.

## Review Focus

1. Inicio en frío con o sin sesión → la misma bienvenida, sin bifurcación por autenticación (Task 2).
2. Sesión activa conserva sus redirecciones actuales; MFA pendiente no puede saltarse el desafío TOTP (Task 2).
3. Acceso administrativo → login administrativo; no se mezcla con el flujo comprador/productor (Task 2).
4. Movimiento reducido → texto estable y sin temporizador activo (Task 1).
5. Pantalla angosta o texto ampliado → no desborda y las tres acciones siguen alcanzables (Task 1).

---

### Task 1: Diseñar e implementar la bienvenida ligera

**Files:**
- Create: `lib/features/auth/presentation/views/welcome_view.dart`
- Test: `test/welcome_view_test.dart`

**Interfaces:**
- Consume: `AppColors`, `assets/images/logotipo_oficial.png`, los destinos existentes de login, registro y login administrativo.
- Produce: `const WelcomeView()` con tres acciones accesibles y mensajes locales rotativos.

- [x] **Step 1: Escribir pruebas widget fallidas**: `muestra logo y acciones`, `rota mensaje tras cuatro segundos`, `mantiene una frase con movimiento reducido` y `no desborda a 320×640 con escala 1.4`. Verificar que **Entrar a Agro+** navega a `/home`.
- [x] **Step 2: Ejecutar `flutter test --no-pub test/welcome_view_test.dart` y confirmar que falla por faltar `WelcomeView`/comportamientos esperados.**
- [x] **Step 3: Implementar `WelcomeView`** con el logo existente, fondo y acentos Agro+, área de texto de altura fija, transición de desvanecido/desplazamiento sutil y botones. Iniciar el temporizador solo cuando las animaciones estén permitidas; cancelarlo en `dispose`.
- [x] **Step 4: Ejecutar `flutter test --no-pub test/welcome_view_test.dart` y confirmar que todas las pruebas pasan sin desbordamientos.**

### Task 2: Integrar entrada, rutas y retorno sin romper auth

**Files:**
- Modify: `lib/core/constants/app_routes.dart`
- Modify: `lib/app.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/splash/splash_view.dart`
- Modify: `lib/features/auth/presentation/views/login_view.dart`
- Modify: `lib/features/auth/presentation/views/register_view.dart`
- Test: `test/auth_mfa_guard_test.dart`
- Test: `test/welcome_view_test.dart`

**Interfaces:**
- Consumes: `const WelcomeView()` de Task 1 y `AuthViewModel.isAuthenticated`/`mfaRequired` actuales.
- Produces: ruta pública `AppRoutes.welcome = '/welcome'`; la app siempre inicia en bienvenida; el flujo MFA y el login administrativo conservan sus guardas actuales.

- [x] **Step 1: Escribir pruebas de rutas fallidas**: `AgroApp.entryLocation` es `/welcome` para cualquier sesión; `welcome remains public with and without a session`; **Entrar a Agro+** va a `/home`, que redirige al desafío con MFA pendiente o al login sin sesión; los demás CTAs abren registro y `/auth/login?mode=admin`.
- [x] **Step 2: Ejecutar `flutter test --no-pub test/auth_mfa_guard_test.dart test/welcome_view_test.dart` y comprobar los fallos esperados.**
- [x] **Step 3: Añadir `AppRoutes.welcome`; definir `AgroApp.entryLocation = AppRoutes.welcome` y usarla siempre en el arranque; registrar `/welcome` como pública; exceptuar solo `/welcome` del redirect MFA inicial para que todos vean la misma bienvenida. Al pulsar una acción, mantener el redirect MFA actual. Actualizar `SplashView` para volver a bienvenida. No redirigir `/welcome` por tener sesión activa.**
- [x] **Step 4: Conectar Entrar con `/home` y Crear cuenta con el registro existente usando `context.push`; añadir retorno visible en Login; hacer que la flecha de Registro use `pop` con retorno seguro a Login si no hay ruta anterior. El acceso administrativo abre `/auth/login?mode=admin` y Atrás regresa a la bienvenida.**
- [x] **Step 5: Ejecutar las dos suites enfocadas y confirmar todos los destinos, retorno, guardia TOTP y acceso admin.**

### Task 3: Verificación final y revisión del diff

**Files:** Los archivos de Tasks 1–2; no se esperan cambios de configuración ni dependencias.

**Interfaces:** Consume la bienvenida y rutas integradas. Produce un flujo de entrada verificable en Android/web, con iOS sin configuración adicional.

- [x] **Step 1: Ejecutar `flutter analyze --no-pub` y corregir advertencias o errores introducidos por el cambio.**
- [x] **Step 2: Ejecutar `flutter test --no-pub`; confirmar que toda la suite termina con cero fallos.**
- [x] **Step 3: Compilar e iniciar en Android conectado; comprobar la misma bienvenida con y sin sesión, botones y regreso; revisar tamaños compactos mediante pruebas widget.** (Arranque en frio y pantalla verificados en Android; los flujos y MFA se verificaron con pruebas widget. Android bloqueo la inyeccion ADB para interactuar manualmente.)
- [x] **Step 4: Revisar `git diff --check`, el diff de autenticación y el estado de los archivos; confirmar que no cambió el backend ni se incorporaron secretos o nuevas dependencias.**

## Criterios de aceptación

1. Todas las sesiones ven la misma bienvenida al abrir la app, sin bifurcación por autenticación.
2. MFA pendiente puede ver la bienvenida, pero no accede a rutas protegidas sin completar el desafío actual.
3. Cada CTA abre el flujo previsto y Atrás vuelve a la bienvenida cuando se entró desde ella.
4. Las frases y transiciones se ejecutan localmente, respetan movimiento reducido y no añaden dependencias.
5. La bienvenida cabe en pantallas pequeñas y texto ampliado.

## Fuera de alcance

- Rediseñar formularios de acceso, roles, MFA o recuperación.
- Cambiar autenticación Supabase, políticas, datos o proveedores.
- Integrar inicio con Google, biometría, Cloudinary, geolocalización o chat.
