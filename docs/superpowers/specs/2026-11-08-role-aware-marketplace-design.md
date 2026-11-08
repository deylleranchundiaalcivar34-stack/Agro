# Diseño: Inicio y navegación por rol para Agro+

> **Estado:** Aprobada e implementada en esta rama; la migración RLS quedó preparada localmente y pendiente de aplicación remota.

## Objetivo

Dar prioridad distinta a compradores y productores sin separar el marketplace: compradores y productores pueden descubrir, mostrar interés y conversar por productos de otras personas; solo productores pueden publicar y gestionar sus propios lotes.

## Reglas funcionales acordadas

- Un comprador puede explorar productos, registrar interés y abrir conversaciones; no puede publicar ni editar productos.
- Un productor puede publicar y gestionar sus propios productos y también comprar a otros productores mediante interés y chat.
- Ninguna persona puede registrar interés ni abrir un chat de compra con su propia publicación.
- La compra de esta etapa significa expresar interés y conversar. No se incluye checkout, pedido, cobro ni entrega.
- El rol administrador permanece separado y no recibe permisos de compra o publicación mediante esta mejora.
- El rol persistido de la cuenta conserva su función de autorización de publicación. No se necesita crear una segunda cuenta ni cambiar el rol productor para comprar.

## Estado actual observado

- `MainNavigationView` presenta cinco destinos comunes: Inicio, Catálogo, Mapa, Chat y Perfil; la barra se oculta al desplazar contenido y reaparece al volver arriba.
- Inicio ya prioriza búsqueda, categorías, publicaciones reales y Mapa; su llamada a publicar aparece solo para productores. El contenido todavía no prioriza por completo las tareas propias de cada rol.
- El destino de productos ya tiene búsqueda y filtro por categoría. Los productores pueden alternar Catálogo y Mis publicaciones.
- `product_detail_view.dart` y la ficha del Mapa muestran acciones de interés/chat solo a compradores.
- Las políticas RLS activas `chats_insert_buyer` e `intereses_insert_buyer` exigen `private.has_role('buyer')`; la publicación de productos ya exige `private.has_role('producer')`.
- `private.can_view_product` permite ver publicaciones activas o propias; las nuevas políticas deben excluir explícitamente la propia publicación para evitar auto-interés o auto-chat.
- `chats_negociacion.id_comprador` e `intereses_preventa.id_comprador` son columnas existentes que representan a quien inicia el interés. Se conservarán para evitar cambios de esquema, pero la interfaz y modelos usarán el término neutral **interesado**.

## Experiencia propuesta

### Inicio comprador

- Encabezado y perfil actuales.
- Mensaje y búsqueda orientados a comprar, categorías y publicaciones reales.
- Acceso a Mapa y Chat.
- Sin botón ni acceso de publicación.

### Inicio productor

- Mantener búsqueda, categorías, catálogo, Mapa y Chat para que también pueda comprar.
- Priorizar la gestión de sus propios lotes y un acceso claro a **Mis publicaciones**.
- La publicación se inicia con el botón azul central de la barra; no agregar otro botón de publicación al Inicio.
- Cualquier resumen usa los lotes propios realmente cargados; no incluir ventas, pedidos, ingresos o reseñas que aún no existen.

### Navegación

- Conservar los cinco destinos y sus rutas: **Inicio, Comprar, Mapa, Chat y Perfil** para compradores y productores.
- En la navegación de productor, incluir en el centro un botón circular azul con únicamente el icono **+**. No mostrar el texto “Publicar” en la barra.
- Distribuir los destinos alrededor de la acción central en este orden: **Inicio**, **Comprar**, **+**, **Mapa**, **Chat**, **Perfil**.
- El botón central abre el formulario existente de publicación. Incluir `Tooltip` y semántica accesible con el texto **Publicar producto**.
- Para compradores se mantiene la barra de cinco destinos, sin el botón central.
- La barra debe seguir integrada al `Scaffold`, conservar su comportamiento de ocultarse al desplazar y respetar `MediaQuery.disableAnimations`.
- Usar `AppColors.info` para el botón azul, el estilo Material 3 existente y áreas táctiles de al menos 48 × 48 px. En anchos compactos, mantener los cinco destinos, evitar solapamientos y preservar el acceso al Perfil.

## Seguridad y Supabase

- Cambiar únicamente las políticas de inserción de `chats_negociacion` e `intereses_preventa` para aceptar cuentas autenticadas con rol `buyer` o `producer`.
- Exigir `id_comprador = auth.uid()`, producto publicado y disponibilidad, y `not private.owns_product(id_producto)`.
- Mantener acceso a conversaciones y mensajes restringido a sus participantes; no cambiar políticas de lectura de perfiles.
- Mantener la política de inserción de `productos` limitada a productores y al propietario autenticado. La interfaz, el router y el servicio también bloquean a compradores.
- No cambiar tablas ni nombres de columnas existentes. Crear una migración versionada y revisable; no aplicar cambios remotos hasta que se apruebe el plan.

## Límites

- No añadir pedidos, pagos, entregas, estadísticas ficticias, nuevas APIs ni cambios de navegación ajenos a esta mejora.
- No cambiar bienvenida, splash, carga, autenticación, CAPTCHA, mapas, ubicaciones o el flujo de recuperación.
- No guardar ubicación de compradores ni modificar la ubicación pública aproximada del productor.
- Mantener el botón de publicación exclusivo de productores tanto en la interfaz como en servicio y RLS; ocultar la acción no es la única protección.

## Criterios de aceptación

1. Un comprador puede buscar productos, registrar interés y contactar a productores, pero no ve ni puede invocar la publicación desde la interfaz, ruta o escritura de Supabase.
2. Un productor conserva publicar/gestionar sus lotes y también puede registrar interés y contactar a otro productor.
3. Ni comprador ni productor puede registrar interés o iniciar un chat sobre su propio producto.
4. Un usuario puede entender quién inició el chat sin que la aplicación describa a todo interesado como “comprador”.
5. La barra de productor muestra un **+** azul central sin texto y el acceso abre el formulario existente; la barra de comprador no muestra ese botón.
6. Los cinco destinos existentes permanecen disponibles y utilizables en móvil compacto; el botón central no tapa Mapa ni Perfil.
7. Los estados vacíos, errores, roles y rutas siguen siendo recuperables, y splash/bienvenida/carga no cambian.
