alter table public.mensajes
  add column if not exists tipo_contenido text not null default 'texto',
  add column if not exists adjunto_ruta text;

alter table public.mensajes
  drop constraint if exists mensajes_tipo_contenido_check,
  add constraint mensajes_tipo_contenido_check
    check (tipo_contenido in ('texto', 'imagen')),
  drop constraint if exists mensajes_adjunto_chat_path_check,
  add constraint mensajes_adjunto_chat_path_check
    check (
      (tipo_contenido = 'texto' and adjunto_ruta is null)
      or (
        tipo_contenido = 'imagen'
        and adjunto_ruta like id_chat::text || '/' || id_remitente::text || '/%'
      )
    );

create table if not exists public.chats_lecturas (
  id_chat uuid not null
    references public.chats_negociacion(id_chat) on delete cascade,
  id_usuario uuid not null
    references public.usuarios(id_usuario) on delete cascade,
  leido_hasta timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (id_chat, id_usuario)
);

alter table public.chats_lecturas enable row level security;
grant select, insert, update on public.chats_lecturas to authenticated;

drop policy if exists chats_lecturas_participant_select
  on public.chats_lecturas;
create policy chats_lecturas_participant_select
  on public.chats_lecturas
  for select to authenticated
  using (private.can_access_chat(id_chat));

drop policy if exists chats_lecturas_self_insert
  on public.chats_lecturas;
create policy chats_lecturas_self_insert
  on public.chats_lecturas
  for insert to authenticated
  with check (
    id_usuario = (select auth.uid())
    and private.can_access_chat(id_chat)
  );

drop policy if exists chats_lecturas_self_update
  on public.chats_lecturas;
create policy chats_lecturas_self_update
  on public.chats_lecturas
  for update to authenticated
  using (
    id_usuario = (select auth.uid())
    and private.can_access_chat(id_chat)
  )
  with check (
    id_usuario = (select auth.uid())
    and private.can_access_chat(id_chat)
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'chat-attachments',
  'chat-attachments',
  false,
  8388608,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists chat_attachments_participant_read
  on storage.objects;
create policy chat_attachments_participant_read
  on storage.objects
  for select to authenticated
  using (
    bucket_id = 'chat-attachments'
    and case
      when (storage.foldername(name))[1] ~*
        '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then private.can_access_chat((storage.foldername(name))[1]::uuid)
      else false
    end
  );

drop policy if exists chat_attachments_participant_upload
  on storage.objects;
create policy chat_attachments_participant_upload
  on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'chat-attachments'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and case
      when (storage.foldername(name))[1] ~*
        '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then private.can_access_chat((storage.foldername(name))[1]::uuid)
      else false
    end
  );

drop policy if exists chat_attachments_uploader_delete
  on storage.objects;
create policy chat_attachments_uploader_delete
  on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'chat-attachments'
    and (storage.foldername(name))[2] = (select auth.uid())::text
    and case
      when (storage.foldername(name))[1] ~*
        '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then private.can_access_chat((storage.foldername(name))[1]::uuid)
      else false
    end
  );

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'chats_lecturas'
  ) then
    alter publication supabase_realtime add table public.chats_lecturas;
  end if;
end $$;
