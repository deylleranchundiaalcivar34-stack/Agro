# Configurar rutas con OpenRouteService

La pantalla de ruta ya está conectada al mapa de Agro+. Para calcular recorridos reales hacen falta una clave de OpenRouteService y desplegar la función de Supabase. La clave es privada: no se agrega a `.env`, Flutter, Android ni Git.

## 1. Obtener la clave

Crear una cuenta en [openrouteservice.org](https://openrouteservice.org/) y generar una API key de Directions.

## 2. Guardar la clave como secreto

Desde PowerShell, en la carpeta del proyecto, reemplazar el texto entre comillas por la clave personal:

```powershell
supabase secrets set ORS_API_KEY="TU_CLAVE_DE_OPENROUTESERVICE" --project-ref tatxjpawpldvlfsxozxd
```

No pegar la clave en el chat ni subirla al repositorio.

## 3. Desplegar la función protegida

```powershell
supabase functions deploy calculate-route --project-ref tatxjpawpldvlfsxozxd
```

La función requiere sesión de Supabase (JWT), valida las coordenadas y consulta HeiGIT desde el servidor. La app solo recibe geometría, distancia y duración; la API key no llega al APK.

## 4. Probar en la app

Iniciar Agro+ en Edge, entrar como comprador y abrir el mapa. Seleccionar un productor y pulsar **Trazar ruta hasta aquí**. Aceptar el aviso de envío de ubicación y el permiso del navegador. El mapa mostrará la ruta hacia la zona pública aproximada, con distancia y duración estimadas.

La duración no incluye tráfico en vivo. Si no hay permiso de ubicación, sesión iniciada, clave configurada o cuota disponible, la app muestra un mensaje y permite seguir usando el mapa.
