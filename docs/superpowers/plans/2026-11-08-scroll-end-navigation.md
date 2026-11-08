# Plan: espacio de scroll y barra al final de contenido

> **Estado:** Implementado y compilado; falta la revisión manual del desplazamiento en el celular. Diseño: `docs/superpowers/specs/2026-11-08-scroll-end-navigation-design.md`.

**Objetivo:** Normalizar el espacio de scroll de todos los módulos y hacer que la barra inferior reaparezca al llegar al final, dejando botones y contenido visibles y tocables.

**Restricciones:** Conservar la navegación integrada actual, destinos por rol y rutas secundarias sin barra. No añadir margen igual a la altura de la barra. No tocar lógica de negocio, APIs o datos.

## Task 1: Ajustar detección del inicio y final de scroll

- [x] Actualizar el manejo de notificaciones de scroll en `MainNavigationView` para mostrar la barra al alcanzar `maxScrollExtent` y ante overscroll hacia el final.
- [x] Mantener el umbral actual para ocultar la barra al desplazarse hacia abajo y mostrarla al subir.
- [x] Ignorar eventos horizontales y cambios de métricas por teclado o tamaño de viewport; aceptar únicamente el overscroll hacia el final.
- [x] Cuando no haya contenido desplazable, mantener siempre visible la barra.

## Task 2: Normalizar la física y el espacio posterior de listas

- [x] Quitar el `BouncingScrollPhysics` forzado de Inicio y Catálogo y conservar el scroll estándar de Android/iOS, sin romper el `RefreshIndicator` de listas cortas.
- [x] Normalizar el espacio de fin de lista en Inicio, Catálogo, Chat y pantallas de perfil a una separación visual cercana a 24 px, sin duplicar área segura o altura de navegación.
- [x] Retirar reservas antiguas de 100–180 px donde no exista una acción inferior fija que las necesite.
- [x] Mantener contenido y botones de mapa en el área del `Scaffold`, sin superponerlos a la navegación.

## Task 3: Revisar acciones fijas y rutas secundarias

- [x] Revisar Publicar producto, Editar producto, Actualizar cantidad, sala de Chat y Mi zona pública.
- [x] Reservar solo el alto de cada acción fija con `SafeArea`; adaptar la lista/campos al teclado mediante `viewInsets`.
- [x] Confirmar que las rutas secundarias no muestran la barra global y que su último control sigue alcanzable.

## Task 4: Verificar en Android y revisar el cambio

- [x] Ejecutar `flutter analyze --no-pub` y compilar Android debug; ambas verificaciones finalizaron correctamente.
- [ ] En el teléfono, recorrer Inicio, Comprar, Mapa y Chat con perfiles comprador y productor: ocultar al bajar, mostrar al subir, llegar al final, estirar el borde y tocar la última acción.
- [ ] Revisar listas vacías y cortas, texto ampliado, teclado abierto, formularios secundarios y área de gesto inferior.
- [ ] Confirmar que Catálogo refresca una lista corta y que no haya saltos de scroll cuando aparece la barra al final.
- [ ] Confirmar que el `+` azul y los destinos permanecen en su posición acordada.

## Resultado esperado

La persona puede recorrer toda la información; al final del scroll la barra queda disponible de nuevo. El contenido termina con un espacio pequeño y consistente, y las pantallas con controles inferiores reservan solo el espacio que esos controles requieren.


**Verificación automatizada:** `dart format --set-exit-if-changed` sin cambios; `flutter analyze --no-pub` sin incidencias; `flutter build apk --debug --no-pub` compiló. No se ejecutaron pruebas automatizadas ni revisión manual en el dispositivo.
