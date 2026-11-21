create table if not exists public.perfiles_contacto_privados (
  id_usuario uuid primary key
    references public.usuarios(id_usuario) on delete cascade,
  telefono_celular text
    check (
      telefono_celular is null
      or telefono_celular ~ '^\+5939[0-9]{8}$'
    ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.perfiles_contacto_privados enable row level security;

grant select, insert, update, delete
  on public.perfiles_contacto_privados to authenticated;

create policy private_contact_profiles_read_self
on public.perfiles_contacto_privados
for select to authenticated
using (id_usuario = (select auth.uid()));

create policy private_contact_profiles_insert_self
on public.perfiles_contacto_privados
for insert to authenticated
with check (id_usuario = (select auth.uid()));

create policy private_contact_profiles_update_self
on public.perfiles_contacto_privados
for update to authenticated
using (id_usuario = (select auth.uid()))
with check (id_usuario = (select auth.uid()));

create policy private_contact_profiles_delete_self
on public.perfiles_contacto_privados
for delete to authenticated
using (id_usuario = (select auth.uid()));

-- Existing visible numbers already had an explicit share opt-in; preserve them
-- privately as well so users can stop sharing without losing their own number.
insert into public.perfiles_contacto_privados (
  id_usuario,
  telefono_celular,
  created_at,
  updated_at
)
select
  id_usuario,
  telefono_whatsapp,
  created_at,
  updated_at
from public.perfiles_contacto_publicos
where whatsapp_visible = true
  and telefono_whatsapp ~ '^\+5939[0-9]{8}$'
on conflict (id_usuario) do nothing;
