-- A buyer can open only one negotiation per product, including concurrent requests.
alter table public.chats_negociacion
  add constraint chats_negociacion_producto_comprador_unique
  unique (id_producto, id_comprador);

-- Flutter streams initial messages and receives changes through this publication.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'mensajes'
  ) then
    alter publication supabase_realtime add table public.mensajes;
  end if;
end $$;
