# Rendimiento y movimiento de Agro+

## Intención

Hacer que Agro+ responda con rapidez y estabilidad en celulares modestos y conexiones rurales, conservando sus funciones, su identidad visual y las decisiones que el usuario ya aprobó. Reducir animación repetida y trabajo innecesario; mantener solo movimiento breve que comunique una acción o ayude a orientarse.

## Lo que ya existe

- Flutter con Supabase, Provider y GoRouter; las funciones se agrupan en autenticación, inicio, productos, mapa, chat y perfil.
- El arranque espera la carga inicial de autenticación y además mantiene un tiempo mínimo de marca de tres segundos.
- El catálogo y el mapa consultan productos publicados con relaciones de categoría, fase y fotografías; el cliente no aplica paginación explícita en las consultas observadas. Hay que revisar el límite configurado en Supabase antes de elegir el tamaño de página.
- El chat usa `.stream()` sobre todos los mensajes de la conversación activa; las consultas de historial y lista tampoco fijan un límite explícito.
- Hay `cached_network_image`, caché configurada en imágenes del splash, algunos skeletons con shimmer y animaciones de entrada distribuidas por pantallas.
- El mapa reúne ubicaciones públicas y productos y utiliza `flutter_map` y Geolocator.

Estas observaciones son indicios para medir; no prueban por sí solas qué parte causa lentitud en el teléfono.

## Objetivos

1. Medir arranque, fluidez, memoria, descargas y solicitudes por módulo antes de optimizar.
2. Priorizar los problemas observados en el teléfono y resolverlos en cambios pequeños, verificables y reversibles.
3. Reducir consultas y datos descargados mediante paginación, selección de columnas necesarias y carga diferida donde corresponda.
4. Reducir costo de decodificación y transferencia de imágenes sin migrar Cloudinary ni exigir nuevas claves.
5. Mantener mapa y chat en tiempo real con una carga acotada y un manejo correcto del ciclo de vida.
6. Unificar movimiento breve y coherente, respetar la preferencia de movimiento reducido y eliminar animaciones de entrada que se repiten en cada rebuild.
7. Conservar navegación, autenticación, permisos, políticas RLS, publicación, compra y estados existentes.

## Fuera de alcance

- No rediseñar pantallas ni cambiar el flujo de compra, publicación o autenticación.
- No cambiar por ahora la apariencia, la animación ni los tres segundos mínimos acordados del splash; tampoco el diseño de bienvenida.
- No añadir Firebase, FCM, proveedores de analítica, APIs pagadas ni dependencias salvo que una medición demuestre que hacen falta y se aprueben después.
- No migrar el almacenamiento de imágenes, eliminar funciones, cambiar RLS o publicar cambios a producción como parte de este trabajo.
- No hacer una reescritura global del estado o la arquitectura.

## Enfoques considerados

### A. Quitar animaciones en bloque

Es rápido de aplicar, pero no reduce consultas, imágenes pesadas, decodificación ni trabajo en listas. Puede quitar personalidad sin mejorar la espera real. Se descarta como estrategia principal.

### B. Medir y optimizar por etapas — elegido

Crear una línea base en el teléfono; priorizar catálogo/imágenes y mapa, después chat, inicio, formularios y perfil; cerrar con una pasada de movimiento común. Cada módulo conserva su comportamiento y se verifica antes de avanzar. Es la mejor relación entre mejora visible y riesgo de regresión.

### C. Refactorizar todos los módulos a la vez

Permite uniformar varias decisiones de arquitectura, pero mezcla cambios de datos, interfaz y navegación difíciles de diagnosticar y revertir. No se recomienda para el estado actual.

## Decisiones de diseño

- La medición manda: no declarar un módulo lento ni optimizado por inspección solamente.
- Las metas absolutas de arranque, memoria y transferencia se fijan después de medir un dispositivo real. Para fluidez, registrar los cuadros que superan el presupuesto del refresco del teléfono y comparar antes/después en el mismo equipo.
- Mantener el splash visible durante el tiempo acordado. Medir por separado cuánto corresponde al tiempo de marca y cuánto a inicialización/autenticación; cualquier cambio a ese comportamiento requiere aprobación propia.
- Mantener Supabase como backend actual. Las consultas nuevas de paginación deben preservar orden, filtros, propiedad de datos, RLS y relaciones mostradas.
- Las fotografías deben solicitar variantes pequeñas para tarjetas y una variante mayor solo en detalle; primero se verifican las URLs guardadas de Cloudinary y compatibilidad de transformaciones. Se revisan también caché y memoria de decodificación; no se cambia el proveedor.
- Chat conserva Realtime para la conversación abierta. El plan deberá escoger una estrategia compatible que cargue una página reciente y después eventos nuevos, combine la página con Realtime, deduplique por ID y conserve orden sin perder mensajes durante la suscripción. La carga de anteriores se pagina; al salir se libera la suscripción.
- Mapa conserva la ubicación pública voluntaria y aproximada y el gesto de pan. Se limita el conjunto de productos y ubicaciones que procesa/renderiza. Antes de añadir almacenamiento de tiles, verificar la política del servidor de mosaicos de OpenStreetMap; no asumir uso offline ni caché ilimitada. Los controles de permisos no cambian.
- Movimiento propuesto: feedback táctil breve y transiciones de estado cortas; quitar animaciones escalonadas por cada tarjeta y entradas que reinician al reconstruir. Evitar blur, sombras animadas y loaders infinitos en contenido largo. Respetar `MediaQuery.disableAnimations`.
- Las recomendaciones no autorizan todavía cambios de código ni de base de datos. Cada plan de módulo enumerará sus consultas, interfaces y pruebas antes de ejecutarse.

## Etapas propuestas

1. **Línea base:** usar Flutter DevTools/Profile en el teléfono conectado, con cuenta y recorrido reales. Medir inicio en frío/caliente, tiempo hasta interacción, cuadros lentos, memoria, solicitudes, bytes de imágenes, catálogo, mapa y chat; guardar pasos y resultados comparables.
2. **Catálogo e imágenes:** revisar el límite de filas e índices relevantes antes de fijar una página; limitar columnas consultadas y cargar más al desplazarse; no descargar la biblioteca completa para el mapa. Revisar URLs de Cloudinary, dimensiones, caché y memoria de decodificación. Verificar búsqueda, filtros, detalle, publicación/edición y vuelta a la lista.
3. **Mapa:** medir permiso/ubicación, consultas, construcción de marcadores y tiles; pedir solo datos del área cuando el esquema lo permita, evitar recomputar distancias/filtros por cada frame y confirmar que pan/zoom no dispara navegación ni consultas repetidas. Revisar la política de uso del servidor de tiles antes de cualquier caché persistente.
4. **Chat:** reemplazar carga completa del historial con página reciente y carga hacia mensajes anteriores; definir una unión sin pérdidas entre el historial y eventos Realtime, deduplicada y ordenada; mantener solo la conversación activa y evitar saltos de scroll al leer mensajes antiguos. Verificar envío, reconexión y cancelación de suscripciones.
5. **Inicio, autenticación, perfil y formularios:** identificar rebuilds y solicitudes repetidas; separar subárboles que cambian poco; conservar validación, teclado rápido, caché de perfil y protección biométrica.
6. **Movimiento y cargas:** inventariar las animaciones existentes; unificar duraciones y curvas por tipo de interacción; conservar solo feedback útil y transiciones breves; usar skeleton estático o shimmer limitado y detener animaciones fuera de pantalla; verificar preferencias de movimiento reducido.
7. **Verificación integral:** repetir los recorridos de línea base en Android conectado y, cuando haya entorno disponible, iOS y web. Comparar cifras, ejecutar pruebas focalizadas y suite disponible, revisar análisis estático, probar modo de red lenta y confirmar que no cambió ningún flujo funcional.

## Criterios de éxito

- Cada cifra de mejora se compara con la línea base del mismo dispositivo, compilación comparable y recorrido. Después de medir, se acuerda un objetivo cuantificable por etapa antes de implementar esa etapa.
- Menos tiempo de espera o bytes descargados en los problemas seleccionados, sin regresiones funcionales ni errores nuevos.
- Menos cuadros lentos en las pantallas que DevTools identifique como problema.
- Catálogo y chat no descargan un historial completo para mostrar únicamente la primera pantalla.
- Animaciones repetidas e infinitas fuera de pantalla se eliminan o limitan; las interacciones principales siguen sintiéndose claras y naturales.
- El arranque, splash, bienvenida, mapa, accesibilidad y navegación respetan los límites acordados.

## Por definir al preparar cada plan

- Qué teléfono y versión de Android se usarán para fijar las metas numéricas.
- Si el proyecto Supabase ya tiene índices adecuados para la paginación de productos y mensajes; se inspecciona antes de proponer migraciones.
- Qué formato de URL de Cloudinary está guardado para saber si admite transformaciones sin cambiar datos.
- Qué pruebas y dispositivos iOS/web están disponibles.
