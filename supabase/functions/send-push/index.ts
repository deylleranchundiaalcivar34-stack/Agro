import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type EventType = "contact_request" | "contact_response" | "message";

type RestRow = Record<string, unknown>;

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function encodeJson(value: unknown): string {
  return base64Url(new TextEncoder().encode(JSON.stringify(value)));
}

function pemBytes(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const binary = atob(base64);
  const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
  return bytes.buffer as ArrayBuffer;
}

async function getGoogleAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${encodeJson({ alg: "RS256", typ: "JWT" })}.${encodeJson({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemBytes(serviceAccount.private_key.replace(/\\n/g, "\n")),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`;
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) throw new Error("No se pudo autorizar el envío a FCM.");
  const result = await response.json();
  return result.access_token as string;
}

function restHeaders(serviceKey: string) {
  return {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
    "Content-Type": "application/json",
  };
}

async function getRows(
  supabaseUrl: string,
  serviceKey: string,
  resource: string,
): Promise<RestRow[]> {
  const response = await fetch(`${supabaseUrl}/rest/v1/${resource}`, {
    headers: restHeaders(serviceKey),
  });
  if (!response.ok) throw new Error(`Consulta interna fallida: ${response.status}`);
  return await response.json() as RestRow[];
}

async function deliver(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<Response> {
  return await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
        },
      }),
    },
  );
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") return jsonResponse(405, { error: "Metodo no permitido." });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!supabaseUrl || !anonKey || !serviceKey || !serviceAccountJson) {
    return jsonResponse(503, { error: "La funcion de avisos aun no esta configurada." });
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization) return jsonResponse(401, { error: "Sesion requerida." });
  const authResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: { apikey: anonKey, Authorization: authorization },
  });
  if (!authResponse.ok) return jsonResponse(401, { error: "Sesion no valida." });
  const caller = await authResponse.json();

  let payload: { event_type?: EventType; reference_id?: string };
  try {
    payload = await request.json();
  } catch {
    return jsonResponse(400, { error: "Cuerpo JSON invalido." });
  }
  const eventType = payload.event_type;
  const referenceId = payload.reference_id;
  if (!referenceId || !["contact_request", "contact_response", "message"].includes(eventType ?? "")) {
    return jsonResponse(400, { error: "Evento de aviso no valido." });
  }

  try {
    let recipientId = "";
    let title = "";
    let body = "";
    let data: Record<string, string>;
    if (eventType === "contact_request" || eventType === "contact_response") {
      const requests = await getRows(
        supabaseUrl,
        serviceKey,
        `solicitudes_contacto?id_solicitud=eq.${encodeURIComponent(referenceId)}&select=id_comprador,id_producto,estado_solicitud`,
      );
      const contactRequest = requests[0];
      if (!contactRequest) return jsonResponse(404, { error: "Solicitud no encontrada." });
      const products = await getRows(
        supabaseUrl,
        serviceKey,
        `productos?id_producto=eq.${encodeURIComponent(String(contactRequest.id_producto))}&select=id_productor,nombre_producto`,
      );
      const product = products[0];
      if (!product) return jsonResponse(404, { error: "Producto no encontrado." });
      const buyerId = String(contactRequest.id_comprador);
      const producerId = String(product.id_productor);
      if (eventType === "contact_request") {
        if (caller.id !== buyerId || contactRequest.estado_solicitud !== "pendiente") {
          return jsonResponse(403, { error: "No puedes emitir este aviso." });
        }
        recipientId = producerId;
        title = "Nueva solicitud de producto";
        body = `Un comprador consulto por ${String(product.nombre_producto ?? "tu producto")}.`;
      } else {
        if (caller.id !== producerId || contactRequest.estado_solicitud === "pendiente") {
          return jsonResponse(403, { error: "No puedes emitir este aviso." });
        }
        recipientId = buyerId;
        title = contactRequest.estado_solicitud === "aceptada"
          ? "Aceptaron tu solicitud"
          : "Respondieron tu solicitud";
        body = `Hay una novedad sobre ${String(product.nombre_producto ?? "tu producto")}.`;
      }
      data = { kind: eventType, request_id: referenceId };
    } else {
      const messages = await getRows(
        supabaseUrl,
        serviceKey,
        `mensajes?id_mensaje=eq.${encodeURIComponent(referenceId)}&select=id_remitente,id_chat`,
      );
      const message = messages[0];
      if (!message) return jsonResponse(404, { error: "Mensaje no encontrado." });
      if (String(message.id_remitente) !== String(caller.id)) {
        return jsonResponse(403, { error: "No puedes emitir este aviso." });
      }
      const chats = await getRows(
        supabaseUrl,
        serviceKey,
        `chats_negociacion?id_chat=eq.${encodeURIComponent(String(message.id_chat))}&select=id_comprador,id_producto`,
      );
      const chat = chats[0];
      if (!chat) return jsonResponse(404, { error: "Chat no encontrado." });
      const products = await getRows(
        supabaseUrl,
        serviceKey,
        `productos?id_producto=eq.${encodeURIComponent(String(chat.id_producto))}&select=id_productor,nombre_producto`,
      );
      const product = products[0];
      if (!product) return jsonResponse(404, { error: "Producto no encontrado." });
      const buyerId = String(chat.id_comprador);
      const producerId = String(product.id_productor);
      if (caller.id === buyerId) recipientId = producerId;
      else if (caller.id === producerId) recipientId = buyerId;
      else return jsonResponse(403, { error: "No eres participante de este chat." });
      title = "Nuevo mensaje en Agro+";
      body = `Tienes un mensaje nuevo sobre ${String(product.nombre_producto ?? "un producto")}.`;
      data = { kind: "message", chat_id: String(message.id_chat) };
    }

    if (!recipientId || recipientId === String(caller.id)) {
      return jsonResponse(200, { sent: 0 });
    }
    const tokenRows = await getRows(
      supabaseUrl,
      serviceKey,
      `dispositivos_fcm?id_usuario=eq.${encodeURIComponent(recipientId)}&select=token`,
    );
    if (tokenRows.length === 0) return jsonResponse(200, { sent: 0 });

    const serviceAccount = JSON.parse(serviceAccountJson);
    const projectId = Deno.env.get("FCM_PROJECT_ID") ?? serviceAccount.project_id;
    if (!projectId) return jsonResponse(503, { error: "Falta el ID del proyecto Firebase." });
    const googleToken = await getGoogleAccessToken(serviceAccount);
    const results = await Promise.all(tokenRows.map(async (row) =>
      await deliver(googleToken, projectId, String(row.token), title, body, data)
    ));
    const sent = results.filter((response) => response.ok).length;
    if (sent === 0) console.warn("FCM no acepto mensajes para los tokens registrados.");
    return jsonResponse(200, { sent, attempted: results.length });
  } catch (error) {
    console.error("Error enviando aviso push:", error);
    return jsonResponse(500, { error: "No se pudo enviar el aviso." });
  }
});
