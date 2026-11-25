import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Coordinates = { latitude: number; longitude: number };

function respond(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function validCoordinates(value: unknown): value is Coordinates {
  if (!value || typeof value !== "object") return false;
  const point = value as Record<string, unknown>;
  return typeof point.latitude === "number" && Number.isFinite(point.latitude) &&
    point.latitude >= -90 && point.latitude <= 90 &&
    typeof point.longitude === "number" && Number.isFinite(point.longitude) &&
    point.longitude >= -180 && point.longitude <= 180;
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return respond(405, { error: "Método no permitido." });

  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch {
    return respond(400, { error: "La solicitud no contiene JSON válido." });
  }
  if (!validCoordinates(payload.origin) || !validCoordinates(payload.destination)) {
    return respond(400, { error: "Las coordenadas de origen o destino no son válidas." });
  }

  const apiKey = Deno.env.get("ORS_API_KEY");
  if (!apiKey) return respond(503, { error: "El servicio de rutas no está configurado." });

  try {
    const response = await fetch(
      "https://api.heigit.org/openrouteservice/v2/directions/driving-car/geojson",
      {
        method: "POST",
        headers: { Authorization: apiKey, "Content-Type": "application/json" },
        body: JSON.stringify({
          coordinates: [
            [payload.origin.longitude, payload.origin.latitude],
            [payload.destination.longitude, payload.destination.latitude],
          ],
          instructions: false,
        }),
      },
    );
    if (response.status === 429) {
      return respond(429, { error: "Se alcanzó el límite de consultas de rutas." });
    }
    if (!response.ok) {
      console.error("OpenRouteService respondió con estado", response.status);
      return respond(502, { error: "El proveedor de rutas no pudo calcular el recorrido." });
    }

    const result = await response.json();
    const feature = result?.features?.[0];
    const rawCoordinates = feature?.geometry?.coordinates;
    const summary = feature?.properties?.summary;
    if (!Array.isArray(rawCoordinates) || rawCoordinates.length < 2 ||
        typeof summary?.distance !== "number" || typeof summary?.duration !== "number") {
      return respond(502, { error: "El proveedor devolvió una ruta incompleta." });
    }

    const points = rawCoordinates.slice(0, 2500).map((pair: unknown) => {
      if (!Array.isArray(pair) || typeof pair[0] !== "number" || typeof pair[1] !== "number") {
        throw new Error("Geometría inválida");
      }
      return { latitude: pair[1], longitude: pair[0] };
    });
    if (points.length < 2 || points.some((point: Coordinates) => !validCoordinates(point))) {
      return respond(502, { error: "El proveedor devolvió una ruta incompleta." });
    }
    return respond(200, {
      points,
      distanceMeters: summary.distance,
      durationSeconds: summary.duration,
    });
  } catch (error) {
    console.error("No se pudo consultar OpenRouteService:", error);
    return respond(502, { error: "No se pudo conectar con el proveedor de rutas." });
  }
});
