-- Agrega provincia y canton para filtrar zonas publicas de productores.
-- Estas columnas ya existen en la base remota; IF NOT EXISTS mantiene segura
-- la migracion en entornos donde ya se aplico manualmente.
alter table public.ubicaciones_productores_publicas
  add column if not exists provincia text,
  add column if not exists canton text;
