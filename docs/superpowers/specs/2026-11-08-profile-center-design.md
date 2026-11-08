# Diseño: Centro de perfil y seguridad de cuenta

> **Estado:** Aprobado e implementado en código. Verificación manual en teléfono pendiente; no se modificó el esquema remoto de Supabase.

## Objetivo

Ordenar el acceso a cuenta, pedidos y seguridad sin sobrecargar la navegación principal. El avatar lleva al centro de perfil desde las pantallas principales. Las funciones mostradas deben ser reales y conectarse a los datos y políticas que ya existen.

## Decisiones acordadas

- Quitar **Perfil** como destino visible de la barra inferior para comprador y productor. Conservar la ruta y la rama interna necesarias para abrir las pantallas actuales.
- Abrir el centro de perfil tocando el avatar/logo de la cuenta desde Inicio, Comprar, Mapa y Chat.
- La navegación compradora tendrá cuatro destinos: **Inicio, Comprar, Mapa y Chat**.
- La navegación productora tendrá **Inicio, Comprar, +, Mapa y Chat**. El botón central sigue siendo solo **+**, azul y exclusivo para publicar.
- Reemplazar el engranaje sin acción por accesos a Notificaciones y Soporte en el encabezado del perfil.
- Mostrar opciones en una cuadrícula adaptable de dos columnas, con icono y título breve; quitar subtítulos. En pantallas muy estrechas o con texto ampliado, permitir una columna para evitar recortes.
- El perfil incluirá **Mis pedidos**, **Mis datos**, **Notificaciones** y **Seguridad**. Para productores añadirá **Mis publicaciones** y **Mi zona pública**.
- No mostrar **Finca/Certificados** mientras el producto no tenga datos reales persistidos para esas funciones. No confundir la zona pública aproximada con una ficha de finca.
- Retirar de Inicio la sección **Mis publicaciones** y su carga privada redundante; las publicaciones propias se abren desde el centro de perfil.
- Incluir **Ayuda y soporte** con respuestas frecuentes útiles. No mostrar botones de contacto externo hasta que exista un canal de soporte configurado.
- Mantener cerrar sesión visible como acción separada y pedir confirmación antes de ejecutarla.
- Quitar los elementos actuales que no hacen nada: engranaje, certificados/finca, notificaciones de precios y acciones de cambio de contraseña sin implementación.

## Funciones y datos

### Pedidos

- Leer los pedidos existentes mediante `pedidos` y `detalles_pedido`, con las políticas RLS actuales como autoridad.
- El productor podrá ver los pedidos en los que participa como productor y el comprador los suyos. Para productor, separar visualmente compras propias y pedidos de sus publicaciones cuando aplique.
- Esta pantalla será de consulta. No añade checkout, cobros, cambios de estado ni acciones de entrega.
- El esquema actual no incluye fecha de creación para los pedidos; no inventar fechas ni prometer orden cronológico por fecha.

### Datos personales

- Permitir editar nombres, apellidos y, si la cuenta ya tiene ese dato, nombre de empresa.
- Mostrar el correo como dato de solo lectura en esta etapa; cambiarlo requiere un flujo separado de confirmación por correo.
- Guardar con el usuario autenticado y las políticas de actualización propia existentes; nunca cambiar rol desde esta pantalla.

### Notificaciones

- Usar `alertas_notificaciones` para listar las alertas de la persona autenticada, mostrar no leídas y permitir marcarlas como leídas, sujeto a RLS.
- No incorporar Firebase Cloud Messaging ni notificaciones push en este alcance. Esto es una bandeja dentro de la app.
- El esquema no tiene fecha para ordenar alertas; no presentar una cronología ficticia.

### Seguridad y biometría

- Implementar cambio de contraseña dentro de la sesión: contraseña actual, nueva y confirmación. Usar la actualización de usuario de Supabase con reautenticación y conservar la sesión activa. No alterar el flujo independiente de recuperación de contraseña.
- Mostrar un interruptor de **Bloqueo biométrico**. Al activarlo, comprobar capacidades reales del dispositivo y pedir autenticación del sistema; guardar únicamente una preferencia local, nunca datos biométricos.
- Si la preferencia está activada, volver a pedir autenticación cuando Agro+ regresa a primer plano, siempre que la sesión continúe autenticada. Usar la opción biométrica del dispositivo con PIN/patrón/credencial del sistema como alternativa si el sistema la ofrece.
- Si el usuario cancela o falla la comprobación al activar, dejar la preferencia apagada. Si al regresar a la app falla el desbloqueo, conservar la pantalla bloqueada y ofrecer reintentar o cerrar sesión.
- Conservar el acceso por correo y contraseña como método de cuenta; el bloqueo biométrico es local a ese dispositivo, no un nuevo método de inicio de sesión remoto.
- Respetar `USE_BIOMETRIC`, `NSFaceIDUsageDescription`, los permisos/configuración ya presentes y preparar los cambios adicionales que iOS requiera. La verificación ejecutable de iOS requiere macOS.

## Diseño de navegación y pantallas

- Mantener la barra inferior integrada, oculta en rutas secundarias como ya está diseñada.
- En Inicio, Catálogo, Mapa y Chat usar el mismo acceso visual de avatar, que abre el centro de perfil sin desalinear la barra inferior.
- Mantener el botón central `+` de productor en su lugar. El avatar de perfil no ocupa espacio en la barra.
- Crear pantallas sencillas para Pedidos, Mis datos, Notificaciones, Seguridad y Soporte con estados de carga, vacío, error y reintento claros.
- **Mis publicaciones** debe abrir el filtro/listado privado existente (`mine=true`), no el catálogo general.
- **Mi zona pública** conserva el flujo actual de ubicación voluntaria aproximada y solo aparece para productor.
- El botón de campana del perfil abre la misma bandeja de notificaciones; no crear dos implementaciones distintas.

## Fuera de alcance

- No modificar splash, bienvenida, login, registro, recuperación de contraseña, MFA/TOTP, mapa ni chat.
- No activar Firebase, FCM, proveedor SMTP, pagos, pedidos nuevos, finca/certificados persistidos ni canales externos de soporte.
- No cambiar esquema o RLS remota por anticipado. Cualquier necesidad de migración debe identificarse en la revisión del código y someterse aparte.
- No almacenar huellas, plantillas biométricas, contraseñas ni tokens en preferencias locales.

## Criterios de aceptación

1. Perfil se abre desde el avatar en todas las pestañas raíz; ya no ocupa un destino inferior.
2. La barra distribuye correctamente cuatro destinos para comprador y cuatro destinos más el `+` para productor, sin huecos ni desbordamiento en ancho móvil.
3. El centro de perfil usa tarjetas compactas en dos columnas, sin descripciones y con acceso funcional a cada opción visible.
4. Los productores pueden entrar directamente a sus publicaciones y a la edición voluntaria de zona pública; compradores no ven esas opciones.
5. Inicio deja de renderizar y cargar el listado privado de publicaciones.
6. Pedidos y notificaciones consultan datos reales respetando RLS, y muestran estados vacíos/error adecuados sin fechas inventadas.
7. Los datos editables se guardan sin permitir cambiar rol ni correo.
8. El cambio de contraseña mantiene sesión y exige las credenciales actuales; recuperar contraseña sigue funcionando por su flujo actual.
9. Al activar bloqueo biométrico se pide autenticación del sistema; al volver a primer plano se solicita desbloqueo según preferencia, con alternativa del sistema disponible y ruta de fallo clara.
10. No quedan botones de interfaz que no ejecuten una acción real, y no se introducen cambios en splash, bienvenida o login.
