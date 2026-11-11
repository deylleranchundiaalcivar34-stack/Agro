# Plan: Centro de perfil y seguridad de cuenta

> **Estado:** Implementado en código; revisión manual en teléfono pendiente. Diseño aprobado: `docs/superpowers/specs/2026-11-08-profile-center-design.md`.

**Objetivo:** Quitar Perfil de la barra inferior, facilitar el acceso desde el avatar y consolidar en una cuadrícula las funciones reales de cuenta, con datos de Supabase y bloqueo biométrico local opcional.

**Restricciones:** Preservar cambios locales existentes; no modificar splash/bienvenida/login/recuperación, ni aplicar cambios remotos a Supabase. No agregar botones de funciones futuras. No introducir Firebase/FCM o servicios pagos.

## Task 1: Revisar modelos, rutas y políticas existentes

- [x] Confirmar repositorios/modelos de perfil, pedidos, detalles y alertas, además de sus políticas RLS desde los archivos versionados locales y la inspección de solo lectura de Supabase.
- [x] Confirmar el estado del shell, rutas raíz/secundarias y puntos de entrada de perfil en Inicio, Catálogo, Mapa y Chat.
- [x] Confirmar que pedidos/alertas no guardan fechas, que `usuarios.nombre_empresa` sí existe y que no se necesita migración para estas pantallas.

## Task 2: Acceso al perfil y destinos de la barra

- [x] Mantener la ruta de perfil y sus subrutas fuera de los destinos visuales de `MainNavigationView`.
- [x] Reorganizar comprador a Inicio, Comprar, Mapa y Chat; reorganizar productor a Inicio, Comprar, `+`, Mapa y Chat.
- [x] Añadir acceso de avatar hacia Perfil en Inicio, Catálogo, Mapa y Chat, conservando la pestaña previa en la pila de navegación.
- [x] Conservar el acceso de rutas secundarias sin barra y el `+` exclusivo para productores.

## Task 3: Centro de perfil de dos columnas

- [x] Reemplazar la lista larga en `ProfileView` por encabezado de identidad y cuadrícula adaptable de icono+título, sin subtítulos.
- [x] Añadir Mis pedidos, Mis datos, Notificaciones y Seguridad para ambos roles.
- [x] Añadir Mis publicaciones y Mi zona pública solo para productores; Mis publicaciones lleva al filtro privado existente.
- [x] Sustituir el engranaje por campana y soporte; conservar cierre de sesión con confirmación.
- [x] Retirar opciones sin funcionalidad y ocultar Finca/Certificados porque el esquema no contiene datos para esos apartados.
- [x] Añadir pantalla de Ayuda con preguntas frecuentes y sin CTA externo no configurado.

## Task 4: Retirar publicaciones propias de Inicio

- [x] Eliminar el bloque Mis publicaciones del Inicio y las llamadas asociadas a cargar/actualizar esa sección.
- [x] Conservar búsqueda, catálogo y el flujo de publicación central existente.
- [x] Dirigir Perfil → Mis publicaciones al listado privado existente.

## Task 5: Datos de cuenta y cambio de contraseña

- [x] Crear una pantalla de Mis datos para nombre, apellido y nombre de empresa respaldado por la tabla actual.
- [x] Mostrar correo de solo lectura y no ofrecer cambio de rol.
- [x] Implementar cambio autenticado de contraseña con contraseña actual, nueva y confirmación usando Supabase Dart `updateUser`.
- [x] Mantener la sesión desde esta pantalla y dejar intacto el flujo independiente de recuperación.
- [x] Mostrar confirmación/errores sin borrar valores cuando guardar datos falla.

## Task 6: Pedidos y bandeja de notificaciones

- [x] Consultar pedidos/detalles del usuario autenticado a través de las políticas RLS existentes.
- [x] Distinguir pedidos como compra o pedido recibido según el usuario autenticado.
- [x] No fabricar fechas ni presentarlos como un historial cronológico.
- [x] Consultar alertas dirigidas al usuario, reflejar las no leídas y permitir marcarlas como leídas.
- [x] Usar la campana como acceso a la bandeja real; no añadir un recuento no solicitado ni propenso a fallos.
- [x] Implementar carga, vacío, error y reintento sin datos ficticios ni push notifications.

## Task 7: Bloqueo biométrico local al volver a la app

- [x] Revisar las versiones ya presentes de `local_auth` y `shared_preferences`, y reutilizar sus APIs.
- [x] En Seguridad, ofrecer interruptor de bloqueo local del dispositivo.
- [x] Al activar, comprobar soporte y autenticar mediante el diálogo del sistema; cancelar/fallar no habilita la preferencia.
- [x] Guardar solo el booleano local por cuenta, nunca biometría ni credenciales.
- [x] Bloquear al regresar a primer plano desde la capa raíz autenticada; no intercepta login ni recuperación.
- [x] Permitir PIN/patrón/credencial del sistema y ofrecer reintento o cierre de sesión si falla.
- [x] Confirmar configuración Android existente y iOS preparado (`NSFaceIDUsageDescription`, deployment target 15.0); compilar iOS requiere macOS.

## Task 8: Revisión y verificación manual

- [x] Revisar el alcance y no descartar los otros cambios locales preexistentes; no se añadieron secretos.
- [x] Ejecutar `flutter analyze --no-pub` y compilación Android debug; ambos terminaron correctamente.
- [x] Atender la revisión de accesibilidad/seguridad: mientras está bloqueada, la pantalla de fondo queda fuera del foco, del árbol de accesibilidad y de los toques; se cierra el teclado al pasar a segundo plano.
- [ ] Verificar manualmente comprador/productor, cambio de pestaña, avatar desde cada raíz, accesos de perfil, estados vacíos, edición de datos, cambio de contraseña y bloqueo al reanudar.
- [ ] Revisar diseño en móvil estrecho y tamaño de texto ampliado; confirmar que Perfil no deja hueco y que el `+` continúa centrado.
- [x] Confirmar que esta implementación no cambió splash, bienvenida, login, recuperación, MFA, datos remotos ni políticas RLS.

## Resultado de verificación

- `flutter analyze --no-pub`: sin problemas.
- `flutter build apk --debug --no-pub`: APK generado en `build/app/outputs/flutter-apk/app-debug.apk`.
- La app se instaló y arrancó en el Android conectado; el registro mostró inicialización de Flutter y Supabase. No se completó todavía el recorrido manual de pantallas con una sesión de usuario.
- El esquema y políticas de Supabase se inspeccionaron en modo de solo lectura. Los datos de `pedidos` y `alertas_notificaciones` están actualmente vacíos, por lo que las pantallas mostrarán su estado vacío hasta que existan registros.
- La comprobación táctil, los diálogos biométricos reales y la compilación de iOS siguen pendientes. iOS tiene el permiso de Face ID y deployment target 15.0; compilarlo requiere macOS.

## Nota técnica

La actualización de contraseña debe usar la sesión ya autenticada y la reautenticación actual de Supabase Auth; validar la firma exacta de `supabase_flutter` instalada en el proyecto antes de codificar. `local_auth` autentica con el mecanismo del sistema: la app guarda solo la preferencia de bloqueo. La bandeja de alertas en la app no requiere FCM.
