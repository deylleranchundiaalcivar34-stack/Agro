# Password Recovery Same-Browser Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hacer que recuperación de contraseña inicie y termine en la web de Vercel para que el código PKCE se intercambie en el navegador que lo generó.

**Architecture:** La página de Vercel solicita el correo con Supabase Auth y redirige al mismo origen. Flutter abre esa página desde «Olvidé mi contraseña». Se conserva PKCE global y el endpoint existente que entrega la URL y clave pública.

**Tech Stack:** Flutter/Dart, `supabase_flutter`, `url_launcher`, HTML, JavaScript y Supabase Auth.

**Spec:** `docs/superpowers/specs/2026-11-07-password-recovery-flow.md` (aprobada por el usuario)

## Global Constraints

- Mantener el flujo PKCE actual de login, registro y confirmación de correo.
- El correo de recuperación se escribe en la web; no pasarlo en la URL desde Flutter.
- No exponer `service_role`, API secrets, tokens ni contraseñas.
- No cambiar plantilla de email ni configuración de Supabase en esta fase.
- Mantener la URL pública `https://agroplus-recuperar.vercel.app` y el endpoint `/api/config` existente.
- Igualar el requisito de contraseña con `PasswordRules`: ocho caracteres, mayúscula, minúscula, número y símbolo.

## Review Focus

1. Recuperación iniciada desde Flutter: debe abrir la web; el usuario debe solicitar el correo allí, sin enviar correo en query parameters.
2. Código PKCE devuelto a la web iniciadora: la página debe recuperar sesión y mostrar el formulario; un enlace abierto en otro contexto debe ofrecer reiniciar desde la web.
3. Correo que no pertenece a una cuenta: la pantalla debe mostrar la misma confirmación genérica para evitar enumeración.
4. Enlace usado, caducado o rechazado: mostrar mensaje recuperable y no presentar formulario de contraseña.
5. Contraseña débil o confirmación distinta: impedir el envío; al completar correctamente, limpiar parámetros de autenticación de la URL.

---

### Task 1: Convertir la web de Vercel en el inicio del flujo

**Files:**
- Modify: `vercel-reset-password/index.html`
- Modify: `vercel-reset-password/app.js`
- Read-only dependency: `vercel-reset-password/api/config.js` (conservar su contrato actual)

**Interfaces:**
- Consume: `GET /api/config` con `url` y `anonKey` públicos; Supabase JS v2.
- Produces: solicitud desde el navegador vía `supabase.auth.resetPasswordForEmail(email, { redirectTo: window.location.origin })`; estado de sesión de recuperación que revela el formulario de contraseña.

- [x] **Step 1: Crear estado inicial de solicitud** en `index.html`: formulario de correo, confirmación genérica, estado de carga, vista de contraseña nueva y errores existentes.
- [x] **Step 2: Solicitar recuperación desde el mismo cliente web** en `app.js`; validar correo, evitar dobles envíos y mostrar confirmación genérica sin distinguir cuentas existentes.
- [x] **Step 3: Procesar el retorno PKCE** con el cliente web en el mismo origen; cargar la sesión y permitir cambio solo cuando haya sesión válida. Eliminar `code`/tokens de la barra de direcciones después del intercambio.
- [x] **Step 4: Validar contraseña nueva** con las cinco reglas fijadas en la spec, actualizarla mediante `supabase.auth.updateUser`, cerrar la sesión y mostrar el estado exitoso.
- [x] **Step 5: Revisar la conexión entre estados**: la página sin callback presenta el formulario de correo; los callbacks requieren `code`, validan sesión PKCE y limpian la URL; contraseña débil o confirmación distinta bloquean el envío. La prueba real queda en Task 3 con el sitio desplegado.

### Task 2: Enviar al usuario desde Flutter a la web segura

**Files:**
- Modify: `pubspec.yaml` (declarar `url_launcher` como dependencia directa; `pubspec.lock` ya contiene la versión `6.3.3`)
- Modify: `lib/core/app_constants.dart` (definir URL única de recuperación)
- Modify: `lib/features/auth/presentation/views/forgot_password_view.dart`
- Modify: `lib/features/auth/presentation/viewmodels/auth_viewmodel.dart` (retirar la solicitud de recuperación nativa si queda sin usos)

**Interfaces:**
- Consumes: URL constante `https://agroplus-recuperar.vercel.app/` y `url_launcher`.
- Produces: acción visible «Continuar en navegador» que abre la página externa; estado de error si el sistema no puede abrirla; regreso al login existente.

- [x] **Step 1: Añadir acción de apertura externa** compatible con Android, iOS y web; no adjuntar el correo ni ningún token.
- [x] **Step 2: Reemplazar el envío de correo Flutter** por una pantalla breve que explica que el correo se ingresa en el navegador para completar PKCE en el mismo contexto.
- [x] **Step 3: Eliminar código de solicitud nativa** de `AuthViewModel` solo cuando no tenga otros consumidores; mantener `updatePassword` y los otros métodos Auth.
- [x] **Step 4: Revisar rutas y plataforma** para confirmar que volver al login y el lanzamiento externo funcionan en los destinos configurados.

### Task 3: Verificar el recorrido completo y desplegar la página

**Files:**
- Revisar: `vercel-reset-password/api/config.js`, `vercel-reset-password/vercel.json`, `docs/superpowers/specs/2026-11-07-password-recovery-flow.md`
- Build/deployment: proyecto Vercel existente con raíz `vercel-reset-password`.

**Interfaces:**
- Consume: app Flutter actualizada, variables de producción que ya responden HTTP 200, cuenta de prueba controlada por el usuario.
- Produces: recuperación completa validada sin cambiar login, registro ni plantillas de Supabase.

- [x] **Step 1: Ejecutar `flutter analyze --no-pub`** y corregir cualquier diagnóstico del cambio Flutter.
- [ ] **Step 2: Probar en dispositivo y navegador**: abrir recuperación desde Agro+, ingresar correo en Vercel, abrir el mensaje en el mismo navegador, cambiar a una contraseña que cumpla las cinco reglas y entrar en Agro+ con ella.
- [ ] **Step 3: Comprobar el caso de enlace inválido/caducado** y confirmar que la web permite solicitar otro desde su estado inicial.
- [ ] **Step 4: Desplegar la carpeta de recuperación en el proyecto Vercel existente** conservando las variables Production; volver a verificar `/api/config` solo por estado HTTP y presencia de propiedades, sin mostrar valores.
- [ ] **Step 5: Revisar `git diff --check`, archivos modificados y ausencia de secretos; entregar el cambio para revisión sin modificar `main` automáticamente.**

## Estado de ejecución

- Tasks 1 y 2 implementadas; `node --check vercel-reset-password/app.js` y `flutter analyze --no-pub` pasaron. También se generaron el APK debug de Android y el build web.
- El proyecto Vercel conserva las variables de Production y `/api/config` responde HTTP 200.
- El despliegue de Production quedó pendiente: la conexión de Vercel rechazó la creación con HTTP 403 por falta de permiso de despliegue. No hay CLI de Vercel ni sesión local configurada en este entorno.
- La prueba completa del correo requiere el despliegue nuevo y una cuenta de prueba controlada por el usuario; no se solicitó ni usó una cuenta ajena.

## Seguimiento del diagnóstico en producción (2026-11-08)

Este seguimiento actualiza la restricción inicial de no tocar la plantilla: el comportamiento observado demuestra que hace falta un enlace `token_hash` con confirmación manual. El cambio de plantilla se deja como acción del propietario en el Dashboard de Supabase.

La primera prueba real mostró que Supabase envió el correo y recibió una verificación `/verify` exitosa, seguida cuatro segundos después por una segunda solicitud con `One-time token not found`. La documentación de Supabase advierte que los escáneres de correo pueden consumir enlaces de un solo uso.

Se agregó una ruta compatible con `token_hash`: Vercel guarda el hash en memoria y espera a que el usuario pulse «Validar enlace y continuar» antes de llamar a `verifyOtp`. La ruta PKCE anterior se conserva como compatibilidad. Cuatro pruebas del parser pasan y `node --check` / `git diff --check` pasan.

La actualización se publicó en Production y se verificó HTTP 200 en `/`, `/app.js`, `/recovery-callback.mjs` y `/api/config`, sin imprimir claves. Para activar la protección contra escáneres falta que el usuario reemplace la plantilla Recovery de Supabase para usar `{{ .RedirectTo }}?token_hash={{ .TokenHash }}&type=recovery`, y luego completar una nueva prueba de correo.
