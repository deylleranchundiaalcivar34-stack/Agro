# Diseño: Exploración del mapa Agro+

> **Estado:** Propuesta para revisión; no implementada.

## Intención

Hacer que el mapa ayude a compradores a descubrir productores y cosechas cercanas, respetando que la ubicación del productor sea pública, aproximada y voluntaria.

## Estado actual

`MapView` carga zonas públicas y productos publicados desde Supabase, dibuja productores en OpenStreetMap, permite abrir una ficha con productos/contacto y pide ubicación del dispositivo desde el botón “Usar mi ubicación”. La distancia y el radio de 20 km solo se aplican después de obtener ubicación. `PublicLocationEditView` permite al productor seleccionar su zona aproximada sin pedir su ubicación privada.

## Referencia de la propuesta

La pantalla `Cli_mapa.png` de `Untitled.zip` aporta una buena jerarquía: búsqueda y filtros arriba, mapa con radio y marcadores al centro, y ficha del productor abajo. Se tomará esa composición como guía. `Pro_mapa.png` muestra parcelas GIS y líneas de despacho; queda fuera hasta tener geometrías de fincas y logística reales. `Cli_edicion_ubicacion.png` incluye dirección exacta e instrucciones de carga; no se copiarán esos datos porque Agro+ publica zonas aproximadas.

## Experiencia propuesta

- Al entrar al Mapa, seguir mostrando el mapa sin pedir permiso de inmediato.
- Añadir una búsqueda sencilla para filtrar por nombre de producto, categoría, alias de productor o sector, y filtros de categoría disponibles en los productos cargados.
- Ofrecer la acción **Buscar cerca de mí** con una explicación breve. El permiso del sistema se solicita solo después de que la persona toca esa acción.
- Si se concede permiso, centrar el mapa, mostrar la posición y permitir ajustar el radio. La coordenada del comprador se mantiene en memoria durante esa exploración y no se guarda en el perfil.
- Si se deniega o el servicio está apagado, mantener búsqueda manual, mapa y filtros disponibles; mostrar un aviso claro y recuperable.
- Al tocar un productor, abrir una ficha inferior desplazable con alias, zona pública, productos disponibles y contacto. Mantener el enlace a detalle de producto existente.
- Usar filtros de fase como “Cosecha lista” o “Preventa” solo si corresponden a fases presentes en los productos; no inventar valoraciones, verificaciones ni disponibilidad de transporte.
- Mantener OpenStreetMap, atribución visible, datos reales de Supabase y zonas públicas aproximadas.

## Alternativas consideradas

1. Pedir permiso apenas se abre la pestaña Mapa: menos pasos, pero el motivo no se entiende todavía y se pierde confianza si se deniega.
2. Pedir permiso desde una acción **Buscar cerca de mí** dentro del mapa: explica para qué se necesita y permite explorar manualmente. **Recomendada.**
3. Copiar la pantalla de direcciones del Figma: no encaja, porque Agro+ comparte zonas de producción, no direcciones residenciales.

## Límites

- No guardar la ubicación privada del comprador ni sobrescribir la zona pública del productor.
- No mostrar calificaciones, certificaciones, cooperativas verificadas, clima, tipo de suelo, logística o ahorros de flete sin datos y servicios que los respalden.
- No cambiar tablas, políticas, roles, geocodificación ni proveedores de mapas.
- Conservar la navegación existente de cinco destinos; adaptar solo la pantalla Mapa.
- No añadir pedido, reparto, ruta estimada, pago o dirección residencial.
- No tocar animaciones de arranque, splash, carga ni bienvenida.
- El mapa debe seguir siendo útil al denegar permiso o no tener GPS.
