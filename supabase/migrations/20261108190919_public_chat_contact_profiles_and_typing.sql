-- Public contact details are separate from private account data and map location.
create table if not exists public.perfiles_contacto_publicos (
  id_usuario uuid primary key
    references public.usuarios(id_usuario) on delete cascade,
  nombre_publico text not null
    check (length(trim(nombre_publico)) between 1 and 80),
  avatar_url text
    check (avatar_url is null or avatar_url ~ '^https://[^[:space:]]+$'),
  telefono_whatsapp text
    check (
      telefono_whatsapp is null
      or telefono_whatsapp ~ '^\+[1-9][0-9]{7,14}$'
    ),
  whatsapp_visible boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint perfiles_contacto_publicos_whatsapp_opt_in
    check (
      (whatsapp_visible and telefono_whatsapp is not null)
      or (not whatsapp_visible and telefono_whatsapp is null)
    )
);

alter table public.perfiles_contacto_publicos enable row level security;

grant select, insert, update, delete
  on public.perfiles_contacto_publicos to authenticated;

create policy public_chat_profiles_read_authenticated
on public.perfiles_contacto_publicos
for select to authenticated
using (true);

create policy public_chat_profiles_insert_self
on public.perfiles_contacto_publicos
for insert to authenticated
with check (id_usuario = (select auth.uid()));

create policy public_chat_profiles_update_self
on public.perfiles_contacto_publicos
for update to authenticated
using (id_usuario = (select auth.uid()))
with check (id_usuario = (select auth.uid()));

create policy public_chat_profiles_delete_self
on public.perfiles_contacto_publicos
for delete to authenticated
using (id_usuario = (select auth.uid()));

-- Only the two participants in a negotiation may join its ephemeral typing channel.
-- Private Realtime channels must also be enforced in the project's Realtime settings.
-- Supabase already enables RLS on realtime.messages; migrations manage policies only.
create policy agro_chat_typing_receive_participant
on realtime.messages
for select to authenticated
using (
  extension = 'broadcast'
  and event = 'typing'
  and case
    when realtime.topic() ~
      '^agro-chat:[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}:typing$'
    then private.can_access_chat(substring(realtime.topic() from 11 for 36)::uuid)
    else false
  end
);

create policy agro_chat_typing_send_participant
on realtime.messages
for insert to authenticated
with check (
  extension = 'broadcast'
  and event = 'typing'
  and payload ->> 'user_id' = (select auth.uid())::text
  and case
    when realtime.topic() ~
      '^agro-chat:[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}:typing$'
    then private.can_access_chat(substring(realtime.topic() from 11 for 36)::uuid)
    else false
  end
);
