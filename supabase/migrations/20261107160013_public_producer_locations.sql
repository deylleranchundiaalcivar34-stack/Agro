-- Public zones are volunteered independently of private delivery locations.
-- numeric(5,2) rounds the submitted point to roughly kilometre scale.
create table if not exists public.ubicaciones_productores_publicas (
  id_productor uuid primary key references public.usuarios(id_usuario) on delete cascade,
  alias_publico text not null check (length(trim(alias_publico)) between 1 and 80),
  nombre_lugar text not null check (length(trim(nombre_lugar)) between 1 and 120),
  latitud numeric(5,2) not null check (latitud between -90 and 90),
  longitud numeric(5,2) not null check (longitud between -180 and 180),
  updated_at timestamptz not null default now()
);

alter table public.ubicaciones_productores_publicas enable row level security;

create policy "public_locations_read_authenticated"
on public.ubicaciones_productores_publicas for select to authenticated
using (true);

create policy "public_locations_insert_producer"
on public.ubicaciones_productores_publicas for insert to authenticated
with check (id_productor = (select auth.uid()) and private.has_role('producer'));

create policy "public_locations_update_producer"
on public.ubicaciones_productores_publicas for update to authenticated
using (id_productor = (select auth.uid()) and private.has_role('producer'))
with check (id_productor = (select auth.uid()) and private.has_role('producer'));

create policy "public_locations_delete_producer"
on public.ubicaciones_productores_publicas for delete to authenticated
using (id_productor = (select auth.uid()) and private.has_role('producer'));

grant select, insert, update, delete on public.ubicaciones_productores_publicas to authenticated;
