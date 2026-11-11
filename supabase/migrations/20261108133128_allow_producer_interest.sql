-- Buyers and producers may initiate a conversation or interest in another
-- producer's active listing. Keep the historical id_comprador column as the
-- initiator id; participant policies remain unchanged.

drop policy if exists chats_insert_buyer on public.chats_negociacion;
create policy chats_insert_marketplace_interested_user
on public.chats_negociacion
for insert
to authenticated
with check (
  id_comprador = (select auth.uid())
  and (private.has_role('buyer') or private.has_role('producer'))
  and private.can_view_product(id_producto)
  and not private.owns_product(id_producto)
  and exists (
    select 1
    from public.productos as producto
    where producto.id_producto = chats_negociacion.id_producto
      and producto.estado_publicacion is true
      and producto.cantidad_disponible > 0
      and producto.id_productor <> (select auth.uid())
  )
);

drop policy if exists intereses_insert_buyer on public.intereses_preventa;
create policy intereses_insert_marketplace_interested_user
on public.intereses_preventa
for insert
to authenticated
with check (
  id_comprador = (select auth.uid())
  and (private.has_role('buyer') or private.has_role('producer'))
  and private.can_view_product(id_producto)
  and not private.owns_product(id_producto)
  and exists (
    select 1
    from public.productos as producto
    where producto.id_producto = intereses_preventa.id_producto
      and producto.estado_publicacion is true
      and producto.cantidad_disponible > 0
      and producto.id_productor <> (select auth.uid())
  )
);
