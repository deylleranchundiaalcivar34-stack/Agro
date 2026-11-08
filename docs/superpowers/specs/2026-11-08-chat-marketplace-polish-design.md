# Diseño: confianza y navegación en chat y mapa

## Objetivo

Hacer más fácil reconocer a la persona y el producto de una conversación, y encontrar productores en el mapa, conservando la interfaz que Agro+ ya tiene. Preparar una reputación confiable sin presentar calificaciones hasta poder demostrar que la compra se completó.

## Estado actual comprobado

- La conversación muestra el producto en el encabezado; la lista de chats usa un ícono agrícola genérico y no muestra el último mensaje.
- El chat ya persiste mensajes en Supabase y recibe cambios en tiempo real.
- Existe un perfil público reciente que muestra el alias y la zona aproximada voluntaria, más los productos activos. Se puede abrir desde una conversación o la tarjeta de productor en el mapa.
- El mapa ya busca productores y productos, filtra por categoría y radio, y solicita ubicación solo al tocar «Buscar cerca de mí».
- `usuarios` restringe la lectura de perfiles a su propio dueño. `pedidos.estado_pedido` es texto libre y actualmente no hay pedidos ni esquema de reseñas que demuestre una entrega.

## Decisiones de diseño

### Conversaciones

- Cada chat mantiene el producto como contexto principal.
- Mostrar el alias voluntario del productor con avatar circular de iniciales; si no publicó alias, usar un avatar genérico. Para quien atiende como productor y no tiene un alias público del otro participante, mostrar una etiqueta neutral de comprador y no datos personales.
- La fila presenta una vista previa del último mensaje y su hora únicamente cuando se puedan leer eficientemente y bajo las políticas actuales del chat.
- El avatar del encabezado abre el perfil público del productor. El acceso no debe reemplazar el botón Atrás ni cambiar las rutas de chat existentes.
- No mostrar “en línea” ni contador de mensajes sin leer: la base actual no registra presencia ni lectura por participante.

### Reputación

- No mostrar estrellas, puntuaciones o distintivos inventados.
- La calificación pública queda bloqueada hasta acordar y persistir un flujo de pedido con recepción confirmada.
- Antes de implementarla, diseñar una migración con estados autorizados, políticas RLS por participante, una reseña por pedido completado y validación de autor, destinatario y rango de puntuación.
- No incluir pagos, comisiones ni compra con tarjeta en este alcance.

### Mapa

- Mantener OpenStreetMap, la búsqueda, los filtros y la ubicación aproximada voluntaria actuales.
- Mejorar la legibilidad cuando varios productores queden cerca: agrupar marcadores superpuestos y mostrar el número del grupo; al tocarlo, acercar el mapa o listar sus productores.
- Los marcadores y sus tarjetas siguen abriendo la ficha pública ya implementada.
- Nunca activar rastreo en vivo ni publicar coordenadas exactas.

## Protección del diseño actual

- Reutilizar `AppColors`, `ThemeData`, radios, tarjetas, tipografía y estados que ya usa Agro+.
- Limitar los cambios a lista/detalle de chat y mapa. No alterar bienvenida, splash/carga, login, colores de marca, barra inferior, perfil privado ni transiciones globales.
- Evitar animaciones nuevas pesadas; usar solo el movimiento mínimo que haga comprensible la agrupación del mapa.
- Mantener áreas táctiles accesibles y comportamiento adaptable a pantallas móviles.

## Fuera de alcance

- FCM/Firebase, presencia en línea y confirmaciones de lectura.
- Fotografías de perfil y cambios de Cloudinary.
- Cambios de autenticación, MFA, registro o recuperación de contraseña.
- Calificaciones habilitadas antes de tener pedidos completados verificables.

## Criterios de aceptación

1. Desde una fila y desde el encabezado del chat se reconoce el producto y, cuando exista, el alias público del productor.
2. La vista previa y hora corresponden al mensaje más reciente y no requieren descargar todo el historial ni consultar un chat a la vez.
3. Datos privados de `usuarios`, como correo y nombres no publicados, nunca aparecen en el chat ni en la ficha pública.
4. La reputación no muestra promedio ni estrellas hasta que la compra esté completada y pueda verificarse en base de datos.
5. Los grupos del mapa no tapan controles, respetan las coordenadas aproximadas y permiten abrir cada productor.
6. Bienvenida, carga, login, navegación inferior, paleta y animaciones globales se conservan sin cambios.
