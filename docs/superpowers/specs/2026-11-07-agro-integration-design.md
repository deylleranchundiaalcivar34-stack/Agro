# Diseño propuesto: integración de Agro+

Fecha: 2026-11-07

## Intención

Unificar el trabajo del equipo sobre el commit local `0b9f6bd`, conservando la experiencia de autenticación reciente y entregando productos, mapa y chat con datos reales. La integración debe poder verificarse antes de mover `main` o publicar cambios.

## Estado comprobado

- El `main` local está limpio y contiene `0b9f6bd`. El `main` remoto avanzó un commit independiente (`a2fd8f5`) que elimina `run_web.bat`, archivo que también eliminó el commit local.
- `feature/jhonatan-auth` ya fue incorporada al historial de `main` remoto. No se fusionará por segunda vez.
- `feature/products-crud` agrega edición, cantidades, fotos con Cloudinary, catálogo y siete archivos de pruebas. Parte de una base anterior a los cambios recientes de autenticación.
- `feature/map-chat` agrega interfaz de mapa, geolocalización y chat, pero sus productores y conversaciones son ejemplos. El envío intenta insertar en `messages` con `room_1`; la base real usa `chats_negociacion`, `mensajes` e identificadores UUID.
- Supabase tiene tablas y políticas RLS para productos, fotos y chat. `mensajes` no está en la publicación `supabase_realtime`. `ubicaciones_geograficas` no tiene filas y su política de lectura muestra solo datos propios.
- `usuarios` solo permite leer el perfil propio. `chats_negociacion` carece de una restricción única para producto y comprador.
- El `.env` está ignorado por Git. Contiene la URL y una clave Supabase con rol `anon`, no una `service_role`. Flutter lo incluye como asset, por lo que no debe contener secretos de servidor.
- El widget anterior llamado reCAPTCHA era una comprobación local de 900 ms sin token ni validación de servidor. El commit local lo retiró. La opción de huella actual solo comprueba el dispositivo desde Perfil; no constituye inicio de sesión biométrico.

## Objetivos

1. Preservar el login local con correo, contraseña, reglas de contraseña y recuperación sin introducir regresiones. Si un usuario opta por TOTP, las rutas protegidas no se abrirán antes de completar el desafío.
2. Integrar productos sobre la misma base y verificar creación, lectura, edición, cantidad, visibilidad y fotografías con la estructura real de Supabase.
3. Mostrar productores reales en el mapa mediante una zona aproximada elegida y publicada voluntariamente por el productor; manejar permiso denegado, ausencia de ubicaciones y errores de red.
4. Crear y listar conversaciones por producto, persistir mensajes y recibir nuevos mensajes mediante Supabase Realtime, respetando las políticas RLS existentes.
5. Mantener fuera del repositorio y del cliente cualquier secreto de servidor. Documentar las configuraciones externas necesarias sin copiar valores secretos.
6. Ejecutar análisis, pruebas y una comprobación manual de los flujos principales antes de proponer el movimiento de `main`.

## Límites y decisiones

- La fuente de verdad del chat será Supabase. No se agregará Firebase/Firestore para los mensajes. Firebase Cloud Messaging podrá añadirse después solo para avisos cuando la app esté en segundo plano o cerrada.
- Geolocator obtiene la posición del dispositivo; no requiere una clave de API. Flutter Map muestra cartografía de OpenStreetMap; se debe añadir atribución visible y respetar la política de teselas.
- La rama de productos ya usa subida directa a Cloudinary con nombre de nube y preset `unsigned`. No se necesita API secret en Flutter. La configuración y límites del preset deben verificarse en Cloudinary antes de afirmar que la subida está lista para producción.
- Se integrarán las funciones comprobadas de cada rama, no sus datos de demostración. Los modelos o servicios duplicados de productos se consolidarán si crean dos fuentes de verdad.
- La biometría queda para una mejora futura. La comprobación local actual no reemplaza TOTP ni se anunciará como inicio de sesión biométrico.
- La ubicación pública será voluntaria y aproximada, en una tabla separada de las ubicaciones privadas usadas para entregas. El usuario confirmó esta opción. Nunca se publicará automáticamente el GPS del dispositivo.
- CAPTCHA queda excluido de la aplicación y de esta integración. No se recuperará el widget simulado ni se configurará un proveedor CAPTCHA.
- Se preparará también la configuración de permisos de iOS. La verificación manual en este equipo Windows cubrirá Android y web; iOS requerirá ejecución posterior en un Mac.

## Enfoques considerados

1. Fusionar las ramas completas directamente en `main`: conserva todo el historial, pero mezcla el chat de demostración, código de productos de una base antigua y cambios superpuestos en rutas, dependencias y Android. Se descarta.
2. Integrar de forma selectiva en una copia aislada de `0b9f6bd`, resolver productos primero y luego mapa/chat contra el esquema real, con pruebas por módulo. **Enfoque elegido para el diseño.**
3. Integrar solo las pantallas y conectar los datos más tarde: reduce trabajo inicial, pero deja funciones aparentemente completas que no negocian ni muestran productores reales. El usuario eligió datos reales desde esta primera integración.

## Diseño por módulos

### Base e integración Git

Crear una copia de trabajo aislada desde `0b9f6bd`. Incorporar el único cambio del `main` remoto sin perder el commit local. Traer las ramas de productos y mapa/chat como fuentes de cambios, resolver los archivos comunes (`pubspec.yaml`, `pubspec.lock`, `app_router.dart`, `AndroidManifest.xml`) de forma explícita y revisar el diff final. No actualizar `main` hasta verificar el resultado.

### Productos e imágenes

Mantener el modelo y repositorio que usa la aplicación como interfaz principal. Incorporar edición, cantidad, visibilidad y carga de imágenes de la rama de productos. La escritura debe exigir usuario productor, comprobar el propietario y conservar los errores parciales de subida o guardado. La base real ya tiene `unidad_medida` y políticas RLS para `productos` y `fotografias_producto`. La prueba de Cloudinary usará una imagen de prueba y el preset existente; no se pondrán claves secretas en `.env` de Flutter.

### Mapa

Mostrar productores con una ubicación pública que hayan elegido compartir, asociados a sus productos publicados. En Perfil, el productor seleccionará manualmente la zona aproximada y un alias público, con controles para publicar, cambiar o retirar esa ubicación. Una tabla pública específica contendrá solo alias, zona y coordenada aproximada; no expondrá direcciones de entrega ni campos privados de `usuarios`. La posición privada del dispositivo solo sirve para centrar y calcular distancia; si el permiso falta, el mapa y la lista siguen disponibles sin afirmar que el punto predeterminado es la ubicación del usuario. La geocerca debe filtrar resultados de verdad. Cuando no existan ubicaciones publicadas, mostrar un estado vacío. El mapa llevará la atribución de OpenStreetMap. Configurar permisos de ubicación en Android e iOS.

### Chat

`chats_negociacion.id_chat` será el ID de conversación. Al contactar desde un producto, crear o recuperar el chat entre comprador y productor conforme a RLS. Añadir unicidad sobre `(id_producto, id_comprador)` y una operación idempotente para que dos pulsaciones no generen dos chats. Consultar la lista de chats reales y los mensajes de `mensajes`, insertar con `id_chat`, `id_remitente` y `contenido`, y mostrar errores de envío en la interfaz. La lista y la sala identificarán la conversación por el nombre público del producto y etiquetas de rol (`Productor`/`Comprador`), sin consultar nombres privados de otros usuarios. Habilitar `mensajes` para Realtime y escuchar solo la conversación abierta; cancelar la suscripción al salir. Probar con dos cuentas reales de roles diferentes y verificar que un tercero no pueda leer la conversación.

### Autenticación

Conservar el código local de login, reglas de contraseña y recuperación. Corregir la guarda para que una sesión con TOTP pendiente vaya al desafío tanto al iniciar sesión como al restaurar una sesión o abrir una ruta profunda. Mantener el enrolamiento de TOTP opcional. Retirar cualquier referencia restante a CAPTCHA. La biometría se documentará como futura mejora y su botón actual no prometerá un inicio de sesión que todavía no implementa.

## Verificación y aceptación

- Análisis de Dart/Flutter sin errores de compilación; pruebas existentes y nuevas pruebas del comportamiento real de productos, mapa, chat y guarda MFA.
- Prueba en Android y web de inicio de sesión, reglas de contraseña, TOTP opcional, catálogo, edición, foto, mapa con y sin permiso, publicación y retirada de zona aproximada, creación idempotente de chat y mensajes en dos sesiones. Configuración iOS revisada estáticamente; ejecución iOS pendiente de un Mac.
- Verificar en Supabase que las políticas de lectura y escritura responden según rol y que Realtime entrega únicamente mensajes autorizados.
- Revisar que no se añadieron claves de servidor ni datos de ejemplo presentados como contenido real.
- Presentar el diff y los resultados antes de fusionar o subir `main`.
