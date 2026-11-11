# Plan: Navegación inferior y espacio de contenido

> **Estado:** Implementado y verificado; interacción táctil manual en el teléfono pendiente.

**Objetivo:** Evitar que la navegación inferior cubra información o acciones y hacer que se sienta integrada con las pantallas de Agro+.

**Hallazgo:** `MainNavigationView` dibuja la barra con un `Positioned` encima de todo el `navigationShell`. Así queda sobre las rutas anidadas, incluido el detalle y la edición de productos. La edición, además, ya tiene su propia barra fija para Guardar/Cancelar. La selección animada usa `easeOutBack` sin recorte explícito, lo que puede hacer que el indicador parezca salir de su contenedor.

**Enfoque recomendado:** Mantener `StatefulShellRoute.indexedStack` y reemplazar la capa flotante por una barra inferior integrada en el `Scaffold` del shell. Usar el componente Material 3 `NavigationBar` con los cinco destinos actuales y su indicador nativo. Mostrar la barra solamente en las cinco pantallas raíz: Inicio, Catálogo, Mapa, Chat y Perfil. Ocultarla en rutas de detalle, edición, sala de chat y edición de ubicación pública. En las pantallas raíz, ocultarla al desplazarse hacia abajo y volver a mostrarla al desplazarse hacia arriba, con umbral para evitar parpadeos. Respetar las áreas seguras y permitir que el contenido aproveche el espacio liberado.

## Alcance

- Conservar los cinco destinos, navegación por ramas y estado de cada pestaña.
- Integrar la barra en el layout del `Scaffold`, sin superponerla al contenido.
- Ocultar la barra global en pantallas secundarias que necesitan espacio propio o ya tienen acciones inferiores.
- Aplicar ocultamiento/reaparición al desplazamiento en las pantallas raíz que emitan eventos de scroll.
- Ajustar el detalle y los formularios para que su último campo/acción pueda alcanzarse con scroll, teclado abierto y áreas seguras.
- Mantener colores Agro+, etiquetas legibles, semántica accesible y animación contenida.
- No cambiar autenticación, datos, rutas públicas ni lógica de productos/chat.

## Tareas

### Task 1: Definir visibilidad y estructura del shell

- [x] Determinar explícitamente qué rutas son destinos raíz y cuáles son secundarias.
- [x] Cambiar la barra superpuesta por `Scaffold.bottomNavigationBar` y mantener `navigationShell` como cuerpo.
- [x] Usar `NavigationBar` de Material 3 con los cinco destinos actuales; confirmar etiquetas en ancho móvil reducido y con texto ampliado.
- [x] Asegurar que las rutas de detalle/edición y las rutas secundarias no presenten la barra global.

### Task 2: Añadir ocultamiento durante scroll y pulir la transición

- [x] Escuchar el desplazamiento de las páginas raíz y ocultar la barra tras un umbral de movimiento hacia abajo.
- [x] Mostrarla al desplazarse hacia arriba y mantenerla disponible al inicio de cada lista.
- [x] Evitar cambios de visibilidad por movimiento mínimo, scroll horizontal o eventos provenientes de pantallas secundarias.
- [x] Animar altura y opacidad sin dejar un hueco persistente ni cubrir contenido; respetar `MediaQuery.disableAnimations`.

### Task 3: Corregir espacio en detalle y edición

- [x] Revisar el `ListView` del detalle y asegurar acceso al contenido final sin que dependa de la barra global.
- [x] Revisar la barra Guardar/Cancelar de edición, el formulario reducido y el teclado; subir las acciones sobre el teclado.
- [x] Conservar `SafeArea` inferior y desplazamiento hasta el último control en pantallas pequeñas.

### Task 4: Verificar y revisar cambios

- [x] Verificar destinos, cambio de pestaña, scroll abajo/arriba y rutas secundarias con pruebas widget; instalar y abrir en Android.
- [x] Verificar detalle, edición, modo cantidad, tamaño reducido y acciones con teclado abierto mediante pruebas widget.
- [x] Revisar sala de chat y edición de zona pública: las rutas secundarias no presentan la barra raíz.
- [x] Ejecutar `flutter analyze --no-pub` y `flutter test --no-pub`; ambos terminaron correctamente.
- [x] Revisar `git diff`; la interacción táctil manual en el Android no pudo automatizarse porque el dispositivo rechaza los eventos inyectados por ADB (`INJECT_EVENTS`). El desplazamiento quedó cubierto por pruebas widget.

## Criterios de aceptación

1. Ningún botón, campo o texto del detalle/edición queda debajo de la navegación principal.
2. La barra se ve integrada al borde inferior y dentro del área segura, sin apariencia flotante.
3. Al bajar por contenido desplazable de las pestañas raíz, la barra se esconde; al subir, vuelve sin parpadeo.
4. En pantallas secundarias solo aparecen las acciones propias de esa pantalla.
5. Cambiar pestañas conserva el comportamiento actual de navegación y estado.
6. El indicador y las animaciones permanecen contenidos en la barra y son utilizables con accesibilidad básica.

## Fuera de alcance

- Cambiar el diseño general de las cinco pantallas.
- Cambiar rutas, permisos, backend, modelos o políticas de Supabase.
- Rediseñar las acciones del detalle o el guardado del producto más allá de espacio y accesibilidad.
