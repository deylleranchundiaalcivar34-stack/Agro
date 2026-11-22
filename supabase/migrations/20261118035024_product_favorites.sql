create table if not exists public.productos_favoritos (
  id_usuario uuid not null references public.usuarios(id_usuario) on delete cascade,
  id_producto uuid not null references public.productos(id_producto) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (id_usuario, id_producto)
);

alter table public.productos_favoritos enable row level security;

grant select, insert, delete on table public.productos_favoritos to authenticated;

create policy "Users read their own favorites"
  on public.productos_favoritos
  for select
  to authenticated
  using (id_usuario = (select auth.uid()));

create policy "Users save available products from other producers"
  on public.productos_favoritos
  for insert
  to authenticated
  with check (
    id_usuario = (select auth.uid())
    and exists (
      select 1
      from public.productos as p
      where p.id_producto = productos_favoritos.id_producto
        and p.estado_publicacion is true
        and p.id_productor <> (select auth.uid())
    )
  );

create policy "Users remove their own favorites"
  on public.productos_favoritos
  for delete
  to authenticated
  using (id_usuario = (select auth.uid()));
