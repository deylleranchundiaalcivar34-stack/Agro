export default function handler(request, response) {
  const url = process.env.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY;
  if (!url || !anonKey) {
    return response.status(503).json({ error: 'Configuracion pendiente' });
  }
  return response.status(200).json({ url, anonKey });
}
