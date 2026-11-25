# Diseño: vista previa de rutas a productores

## Objetivo

Permitir que un comprador calcule y visualice en el mapa una ruta en auto hasta la zona pública aproximada de un productor, con distancia y duración estimadas.

## Alcance

- El botón **Trazar ruta** aparece en la ficha del productor del mapa.
- Se usa la ubicación actual del comprador si ya dio permiso; si no, se explica el uso antes de solicitarla.
- Antes de enviar coordenadas a un proveedor externo se informa que el origen y la zona pública se enviarán a OpenRouteService para calcular el recorrido.
- El trazado, los marcadores y una tarjeta con distancia/tiempo se muestran sobre el mapa existente. El mapa encuadra toda la ruta y permite cerrarla.
- La ubicación exacta del productor no se revela ni se persiste. La ruta termina en su zona pública aproximada.
- El tiempo es una estimación de ruta, no un cálculo de tráfico en vivo ni navegación giro a giro.

## Arquitectura

La app Flutter llama a una Edge Function autenticada de Supabase. La función valida coordenadas, consulta el endpoint Directions de OpenRouteService y devuelve solo geometría, distancia y duración. La clave `ORS_API_KEY` vive en los secretos de Supabase, nunca en el APK. Flutter dibuja la geometría en `flutter_map` con una polilínea, marcadores de origen/destino y encuadre automático.

## Decisión de implementación

Se elige una función de Supabase como proxy para proteger la clave y centralizar validación/errores. La ruta se calcula para auto (`driving-car`). No se incluye seguimiento GPS continuo, datos de tráfico en tiempo real, persistencia de coordenadas ni navegación paso a paso en esta entrega.

## Criterios de aceptación

1. Una ficha de productor ajeno ofrece **Trazar ruta**.
2. Sin ubicación disponible, la app solicita permiso con explicación en español y no envía coordenadas sin aceptación.
3. Una respuesta válida muestra polilínea, origen, zona pública, km y minutos; la cámara encuadra el trayecto.
4. Cerrar la ruta restaura la lista/mapa de productores.
5. Errores de permisos, configuración, cuota, red y respuesta inválida se presentan en español, sin filtrar la clave.
6. La función rechaza coordenadas inválidas y requiere sesión JWT.
