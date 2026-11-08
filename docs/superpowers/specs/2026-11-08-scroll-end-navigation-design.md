# Diseño: espacio de scroll y barra al final de contenido

> **Estado:** Diseño aprobado e implementación aplicada. La revisión manual en dispositivo sigue pendiente.

## Objetivo

Que las personas puedan llegar y tocar el último dato o botón de cada módulo, sin que la navegación inferior lo tape ni deje un hueco final exagerado. Si la barra está oculta durante el desplazamiento, debe reaparecer al llegar al final del contenido.

## Hallazgo del código actual

- La navegación ya vive en `MainNavigationView` como `Scaffold.bottomNavigationBar`; no se dibuja como una capa flotante sobre el contenido.
- `_handleScroll` la muestra cuando se vuelve al inicio o se desplaza hacia arriba. No trata `OverscrollNotification` hacia el final ni comprueba que el scroll haya alcanzado `maxScrollExtent`; por eso puede seguir oculta al estirar el contenido abajo.
- Inicio usa `BouncingScrollPhysics` y Catálogo usa `BouncingScrollPhysics` explícitamente. Eso impone el rebote aun en Android.
- Los espacios finales actuales varían: Inicio 32 px, Catálogo 112 px, Chat 100 px. Las rutas secundarias que no muestran la barra principal conservan reservas grandes como 180 px en Publicar producto y 116 px en Mi zona pública.
- Los formularios con acciones propias (Guardar/Cancelar de edición, enviar mensaje, publicar zona) requieren tratarse con su barra fija y teclado, no añadirles la altura de la navegación principal.

## Enfoque elegido

- Mantener la barra inferior integrada en el `Scaffold` y el patrón actual de ocultarla al desplazarse por el centro del contenido.
- Mostrarla al llegar al inicio o al final, al desplazar de vuelta hacia arriba y cuando el contenido no alcanza a desplazarse.
- Detectar el fin con métricas de scroll y overscroll hacia adelante. Ignorar overscroll del borde superior y cambios de métricas causados por teclado, orientación o aparición de la propia barra para evitar parpadeos.
- Retirar el rebote forzado y dejar que Flutter use el comportamiento de scroll correspondiente a la plataforma (Android sin rebote elástico forzado; iOS conserva su comportamiento nativo). Mantener la posibilidad de actualizar listas cortas con `RefreshIndicator`.
- Unificar el espacio posterior al último elemento en torno a 24 px más el área segura que corresponda. No añadir la altura completa de la barra: el `Scaffold` ya reserva ese espacio.
- En pantallas con acción fija inferior, reservar exactamente la altura de esa acción mediante `Scaffold.bottomNavigationBar`/`SafeArea` y mantenerla por encima del teclado. Las rutas secundarias continúan sin barra global.

## Alcance

- Módulos raíz: Inicio, Comprar/Catálogo, Mapa y Chat.
- Rutas secundarias: detalle y formularios de producto, sala de chat, edición de zona pública y pantallas de perfil.
- Revisar estados con lista vacía, lista corta, lista larga, texto ampliado, teclado abierto y cambio de rol comprador/productor.
- Mantener la barra de comprador de cuatro destinos y la barra productora de cuatro destinos más el botón azul `+`.

## Fuera de alcance

- No rediseñar las pantallas ni cambiar nombres, orden o destinos de navegación.
- No cambiar datos, Supabase, autenticación, productos, chat o comportamiento de permisos.
- No aumentar el tamaño de las áreas vacías para simular más contenido; eliminar reservas heredadas que ya no hacen falta.

## Criterios de aceptación

1. Al desplazarse por el medio de una lista, la barra se oculta según el comportamiento actual.
2. Al llegar al final, incluso si se tira del contenido para estirarlo, la barra vuelve a aparecer y permanece visible.
3. Al llegar al inicio, la barra continúa apareciendo sin parpadeos.
4. El último botón, campo y tarjeta pueden verse y tocarse completamente encima de la barra y del área de gesto del sistema.
5. El rebote no se fuerza en Android; el desplazamiento conserva el comportamiento nativo de cada plataforma.
6. No se agrega una reserva del alto de la barra dentro de las listas; se eliminan los espacios excesivos de 100–180 px cuando la pantalla no tiene una acción fija que los justifique.
7. Las acciones inferiores fijas y el compositor de chat permanecen accesibles con teclado abierto y en pantallas pequeñas.
8. No cambian las cuatro pestañas principales, el `+` azul del productor ni las rutas secundarias sin barra.

## Estado de implementación

- La barra vuelve a mostrarse al llegar al borde inferior, estirar el scroll hacia abajo o cuando el contenido deja de ser desplazable.
- Inicio y Catálogo usan la física nativa de cada plataforma y mantienen el refresco en listas cortas.
- Los espacios finales grandes se normalizaron; los formularios con acciones fijas conservan sus áreas seguras.
- `flutter analyze --no-pub` y `flutter build apk --debug --no-pub` finalizaron correctamente. La comprobación visual en teléfono queda pendiente.
