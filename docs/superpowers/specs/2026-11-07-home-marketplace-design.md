# Diseño: Inicio marketplace de Agro+

> **Estado:** Propuesta para revisión; no implementada.

## Intención

Hacer que Inicio presente Agro+ como marketplace de productos y productores, con accesos claros a búsqueda, catálogo, mapa y publicación.

## Estado actual

`HomeView` muestra saludo/perfil, una tarjeta de resumen con conteos reales de productos y categorías, un banner grande para publicar preventas y cuatro tarjetas de acceso rápido. El Catálogo ya tiene búsqueda local, filtros de categorías, tarjetas de producto y datos de `ProductsViewModel`.

El frame “Seller Dashboard Home” del Figma organiza ubicación, pedidos activos, solicitudes, ingresos y reseñas. Agro+ todavía no tiene pedidos, ventas pagadas ni calificaciones; copiar esos indicadores sugeriría datos y procesos que no existen.

La propuesta exportada en `Untitled.zip` aclara dos direcciones: `Cli_inicio.png` tiene seleccionada la pestaña Catálogo y muestra productos para compradores; `prod_inicio.png` es un panel de productor con ventas, inventario y solicitudes. Para el Inicio común se tomará como guía el descubrimiento del catálogo. El panel del productor puede ser una etapa futura cuando existan datos reales para solicitudes y ventas.

## Experiencia propuesta

- Mantener el mismo Inicio marketplace para compradores y productores, con saludo y perfil actuales.
- Priorizar una entrada visual a búsqueda del catálogo, categorías y productos publicados reales.
- Mostrar una sección horizontal de productos recientes o disponibles, usando fotos/precios/categorías reales y el componente o estilo de producto existente.
- Tomar de `Cli_inicio.png` la presentación de productos y fases comerciales, pero mantener precios, cantidades, productor y distancia vinculados a datos reales.
- Añadir una llamada clara al Mapa para explorar productores y cosechas; el permiso de ubicación se solicita dentro de Mapa cuando se elija buscar cerca.
- Mantener **Publicar preventa** accesible, con menos peso visual que el descubrimiento de productos.
- Conservar los tres conteos actuales solo como resumen compacto, sin gráficos de ingresos, órdenes ni reseñas.
- Mantener estados de carga, error y catálogo vacío; permitir refrescar con datos actuales.

## Alternativas consideradas

1. Copiar literalmente el dashboard del vendedor de Figma: descartada porque pedidos, ingresos y reseñas no existen en Agro+.
2. Dejar Inicio como está y solo ajustar colores/espaciado: poco cambio para la sensación de dashboard que el usuario quiere mejorar.
3. Ordenar Inicio alrededor de descubrir cosechas, conservando resumen real y accesos existentes: **Recomendada.**

## Límites

- No introducir datos simulados de pedidos, ventas, entregas o reseñas.
- No presentar puntuaciones, ventas completadas, productores certificados/verificados, garantías de pago, entregas, clima, suelo, trazabilidad o puntuación de búsqueda como capacidades activas sin datos/servicios que las respalden.
- La selección de perfil de `Gen_Inicio.png` y el flujo de bienvenida quedan fuera de esta mejora; el rol administrador no se ofrece como registro público.
- Reutilizar el catálogo/`ProductsViewModel`; evitar consultas duplicadas o cambios de esquema Supabase.
- Conservar la navegación existente de cinco destinos; adaptar solo el contenido de Inicio.
- Mantener la navegación actual y las acciones ya existentes.
- No pedir ubicación desde Inicio.
- No tocar animaciones de arranque, splash, carga ni bienvenida.
