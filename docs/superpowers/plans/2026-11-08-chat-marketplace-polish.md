# Chat y mapa del marketplace — Plan de implementación

> **Ejecución:** seguir `superpowers:executing-plans` después de que el usuario apruebe este plan. Los pasos de verificación de UI serán estáticos y manuales; no modificar ni desplegar Supabase remoto sin revisar primero la migración y sus políticas.

**Objetivo:** pulir la identidad de las conversaciones y la legibilidad del mapa sin cambiar el diseño global de Agro+, y dejar una ruta segura para reputación verificada.

**Arquitectura:** reutilizar alias de zona pública y productos existentes; obtener la vista previa con la relación anidada de mensajes limitada al más reciente y ordenar/limitar esa relación con PostgREST, más una sola consulta agrupada de alias. Evitar consultas N+1 y cargar historiales. Agrupar marcadores con una cuadrícula espacial local sin dependencia nueva, y dejar la reputación detrás de un flujo de pedidos verificable.

**Tecnologías:** Flutter, GoRouter, `flutter_map`, Supabase/Postgres y las tablas actuales de chat, productos y zonas públicas.

**Especificación:** `docs/superpowers/specs/2026-11-08-chat-marketplace-polish-design.md`

## Restricciones globales

- Conservar bienvenida, splash/carga, login, colores, tipografía, barra inferior y transiciones globales.
- Mantener las zonas aproximadas publicadas voluntariamente y la ubicación del comprador opcional.
- No consultar ni exponer correo, nombres privados ni coordenadas exactas.
- No crear indicadores de presencia o lectura sin datos persistidos que los respalden.
- No mostrar calificaciones sin pedido completado verificable y RLS por participante.
- Preservar los cambios locales existentes; no limpiar, resetear ni confirmar en Git otros trabajos del árbol.

## Enfoque de revisión

- Alias ausente, producto oculto o chat sin mensajes: usar presentación neutral y estados vacíos honestos.
- Muchos chats: resolver el último mensaje de todos en una sola vista/consulta, sin descargar historiales completos.
- Productor sin zona pública: conservar avatar genérico y no inferir nombre o correo.
- Varios marcadores coincidentes: el grupo debe poder expandirse y no impedir abrir las tarjetas existentes.
- Pedidos sin estado de entrega: mantener reputación sin promedio y separar el diseño del flujo de pedidos.

## Task 1: Identidad y resumen de conversaciones

**Archivos principales:**

- Modificar `lib/features/chat/data/models/chat_conversation.dart` para admitir alias público, último texto y hora sin cambiar el identificador ni el producto asociados al chat.
- Modificar `lib/features/chat/data/repositories/chat_repository.dart` para llenar esos campos con una consulta eficiente y ordenada.
- Modificar `lib/features/chat/presentation/views/chat_list_view.dart` para usar avatar circular con inicial del alias, contexto del producto, vista previa y hora. Si falta alias o mensaje, usar los textos genéricos acordados en la especificación.
- Modificar `lib/features/chat/presentation/views/chat_room_view.dart` para mostrar alias junto al contexto del producto y mantener la acción que abre el perfil público.
- Seleccionar `mensajes(id_remitente,contenido,fecha_hora_envio)` como relación anidada y usar `order(..., referencedTable: 'mensajes')` junto con `limit(1, referencedTable: 'mensajes')`. Consultar los alias de zona con un único filtro `inFilter` para todos los productores. Esta ruta ya es suficiente; no crear migración ni vista SQL.

**Interfaz prevista:** el repositorio devuelve cada `ChatConversation` con `producerAlias`, `lastMessagePreview` y `lastMessageAt` opcionales; la UI resuelve valores faltantes sin inventar actividad.

**Verificación:** `flutter analyze`; revisar manualmente comprador, productor, chat sin mensajes y chat sin alias. Confirmar en el diff que no se lee el historial completo ni se filtra por participante en el cliente en reemplazo de RLS.

## Task 2: Agrupación ligera de marcadores

**Archivos principales:**

- Modificar `lib/features/map/presentation/views/map_view.dart` o extraer un widget local de marcadores agrupados si reduce complejidad.
- Calcular grupos por celdas de pantalla usando `MapCamera.project`; recalcular membresía solo cuando el zoom cruza un nivel entero. No añadir dependencia ni animaciones de agrupación.
- Mantener intactos búsqueda, categoría, radio, botón de ubicación, atribución de OpenStreetMap y acceso a perfiles.

**Comportamiento:** al nivel de zoom actual, marcadores que se solapen se muestran como un grupo con cantidad; tocar el grupo acerca el mapa y, al separarse, permite abrir el marcador individual y su ficha.

**Verificación:** `flutter analyze`; revisar manualmente cero, uno, varios y marcadores coincidentes; confirmar que el botón de ubicación y la navegación siguen accesibles.

## Task 3: Reputación respaldada por pedidos — fase de diseño separada

**Archivos:** preparar un documento de diseño y, tras aprobación específica, migraciones bajo `supabase/migrations/` y UI del perfil público.

**Decisiones necesarias antes de escribir código:** acordar quién puede confirmar la recepción, estados permitidos, cancelaciones y cómo resolver desacuerdos. La reseña solo se habilitaría para el comprador del pedido confirmado, una vez por pedido, con puntuación validada de 1 a 5.

**Seguridad:** RLS valida comprador, productor y estado completado en servidor; no confiar en estado enviado por cliente. El agregado público solo expone promedio y cantidad de reseñas, nunca información del pedido ni correo.

**Límite de aprobación:** no cambiar el estado de `pedidos`, aplicar migraciones remotas ni activar calificaciones hasta que se apruebe el diseño específico del flujo de compra/recepción.

## Cierre

- Ejecutar `flutter analyze` después de cada tarea de UI.
- Hacer revisión visual en el teléfono antes de instalar una nueva versión.
- No publicar, aplicar DDL remoto, hacer push ni commit sin instrucción del usuario.
- Presentar los cambios y cualquier limitación antes de avanzar a la fase separada de pedidos/reseñas.
