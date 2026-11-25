# Plan de implementación: rutas a productores

> Plan de ejecución para la rama `main` del proyecto Agro+.

**Objetivo:** Añadir al mapa una vista previa de ruta en auto desde la ubicación del comprador hasta la zona pública aproximada de un productor.

**Arquitectura:** Flutter obtiene permiso y llama a una Edge Function autenticada de Supabase. La función consulta OpenRouteService con `ORS_API_KEY` almacenada como secreto y responde con geometría, distancia y duración. Flutter dibuja la ruta en el mapa ya existente.

**Tecnologías:** Flutter, `flutter_map`, `latlong2`, Geolocator, Supabase Edge Functions/Deno y OpenRouteService Directions API.

**Diseño:** `docs/implementacion/diseno_rutas_productores.md`.

## Restricciones globales

- Trabajar en la copia del Escritorio sobre `main`.
- Mantener toda la interfaz visible en español.
- No guardar coordenadas del comprador ni del productor.
- No incluir la clave de ORS en el código cliente, archivos de configuración públicos ni APK.
- Usar `https://api.heigit.org/openrouteservice/v2/directions/driving-car/geojson`.
- La respuesta representa tiempo estimado de ruta, no tráfico en vivo.
- El destino siempre es la zona pública aproximada del productor.

## Revisión prioritaria

- Permiso denegado o ubicación desactivada: no enviar la solicitud y mostrar instrucciones en español.
- Secreto `ORS_API_KEY` ausente: responder con error de configuración claro, sin datos sensibles.
- Cuota/red/ORS fuera de servicio: permitir cerrar la ruta y volver al mapa.
- Coordenadas ORS: convertir el formato del mapa `[latitud, longitud]` a `[longitud, latitud]`.
- Polilínea inválida/vacía: no encuadrar ni dibujar una ruta falsa.

---

### Tarea 1: modelo y lectura de la ruta

**Archivos:**
- Crear: `lib/features/map/data/models/route_preview.dart`
- Prueba: `test/features/map/data/models/route_preview_test.dart`

- [ ] Escribir pruebas para leer geometría GeoJSON normalizada, distancia y duración.
- [ ] Ejecutar la prueba y comprobar que falla por ausencia del modelo.
- [ ] Implementar validación de coordenadas, kilometraje y duración.
- [ ] Ejecutar la prueba y comprobar que pasa.

### Tarea 2: función protegida para Directions

**Archivos:**
- Crear: `supabase/functions/calculate-route/index.ts`
- Crear: `supabase/functions/calculate-route/deno.json`

- [ ] Implementar CORS para preflight, método POST y validación de origen/destino.
- [ ] Consultar el endpoint de HeiGIT con coordenadas en orden longitud/latitud y `ORS_API_KEY`.
- [ ] Normalizar GeoJSON a puntos `[latitud, longitud]`, distancia en metros y duración en segundos.
- [ ] Traducir cuota, errores externos y secreto ausente a estados controlados sin devolver la clave.

### Tarea 3: repositorio y flujo visual del mapa

**Archivos:**
- Crear: `lib/features/map/data/repositories/route_preview_repository.dart`
- Modificar: `lib/features/map/presentation/views/map_view.dart`

- [ ] Llamar a `calculate-route` con origen/destino y convertir errores a mensajes en español.
- [ ] Añadir consentimiento específico antes de compartir coordenadas con HeiGIT.
- [ ] Añadir **Trazar ruta** a la ficha de productores ajenos.
- [ ] Dibujar polilínea y marcadores, ocultar la lista inferior mientras se previsualiza y encuadrar con `MapController.fitCamera`.
- [ ] Mostrar alias/zona aproximada, kilómetros estimados, minutos estimados y botón para cerrar.

### Tarea 4: comprobación de integración

- [ ] Ejecutar la prueba del modelo y `flutter analyze`.
- [ ] Compilar/abrir la app en Edge para comprobar el diseño y los estados sin ruta.
- [ ] Configurar `ORS_API_KEY` como secreto de la función; probar la consulta con consentimiento y coordenadas de prueba.
- [ ] Confirmar que el mapa conserva su comportamiento al cerrar el panel de ruta.
