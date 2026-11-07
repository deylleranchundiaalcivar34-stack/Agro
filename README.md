# Agro+

Aplicacion Flutter para publicar productos agricolas, encontrar productores por una zona aproximada y negociar mediante chats privados de Supabase.

## Requisitos

- Flutter y Dart compatibles con `pubspec.yaml`.
- Un proyecto Supabase configurado con el esquema base de Agro+ y Auth por correo.
- Cloudinary con un preset de carga unsigned para las fotografias de producto.

## Configuracion local

1. Copia `.env.example` a `.env`.
2. Define `SUPABASE_URL` y `SUPABASE_ANON_KEY` con el URL y la clave publica de tu proyecto. La app movil nunca debe recibir la clave `service_role`.
3. Ejecuta `flutter pub get` y luego `flutter run`.

El archivo `.env` esta ignorado por Git. Usa solo claves publicas de cliente; nunca pongas secretos de servidor en una app Flutter.

## Datos y servicios

- **Productos:** se guardan en `productos`; sus fotos se relacionan mediante `fotografias_producto`.
- **Fotos:** `ProductStorageService` envia archivos de hasta 5 MB en JPG, PNG o WebP a Cloudinary, con el preset `agroproductos` del cloud configurado en el servicio. El preset unsigned es publico. Restringe formatos, tamano y carpetas desde Cloudinary. No agregues el API secret de Cloudinary a Flutter.
- **Mapa:** solo muestra productores que publicaron manualmente una zona aproximada. El punto se redondea a dos decimales y se separa de la tabla de ubicaciones privadas. El permiso de ubicacion del dispositivo se solicita al tocar el boton de distancia; sin permiso se ven todos los productores publicados.
- **Map tiles:** el mapa usa los tiles publicos de OpenStreetMap con atribucion visible. Respeta sus politicas de uso y cambia a un proveedor contratado si el trafico de produccion lo requiere.
- **Chat:** las conversaciones usan `chats_negociacion`; los mensajes usan `mensajes`. Realtime actualiza el flujo de mensajes y RLS controla acceso de participantes. No se crean mensajes de ejemplo ni se leen perfiles privados para nombrar a otros usuarios.
- **Autenticacion:** correo y contrasena son el acceso principal. CAPTCHA no forma parte de la app. La opcion para activar TOTP esta temporalmente oculta hasta completar su enforcement en RLS; se conserva la ruta del desafio para no bloquear cuentas futuras. Biometria del telefono solo comprueba localmente el dispositivo y no reemplaza el inicio de sesion.

## Migraciones incluidas

Estas migraciones se aplicaron al proyecto Supabase conectado durante la integracion:

- `20261107160013_public_producer_locations`: zonas aproximadas, seleccion voluntaria y RLS de lectura autenticada/escritura de productor propietario.
- `20261107161259_chat_unique_realtime`: una conversacion por comprador y producto, y publicacion de `mensajes` en `supabase_realtime`.

Aplican sobre el esquema base existente de Agro+. No crean un proyecto Supabase desde cero. Revisa y aplica estas migraciones a cada entorno antes de desplegar la app.

## Seguridad y privacidad

- No publiques ubicaciones de finca automaticamente ni copies la ubicacion actual del telefono.
- El productor elige el punto y el alias que se mostraran publicamente; puede retirarlos desde Perfil.
- Las operaciones de chat dependen de las politicas RLS ya existentes para compradores, productores y participantes.
- La clave anon/publishable de Supabase esta pensada para el cliente y requiere politicas RLS activas. Nunca uses `service_role` en la app.

## Verificacion

```sh
flutter analyze
flutter test
```

El mapa requiere internet para cargar tiles. Para probar permisos y conversaciones entre dos cuentas, usa dispositivos o sesiones separadas con un comprador y un productor.
