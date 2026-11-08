-- Allow any signed-in marketplace participant with a registered profile to
-- start a conversation about another user's active, available publication.
-- The id_comprador foreign key requires a registered Agro+ profile, and the
-- authenticated uid check prevents creating a conversation for someone else.
drop policy if exists chats_insert_marketplace_interested_user
  on public.chats_negociacion;

create policy chats_insert_marketplace_interested_user
on public.chats_negociacion
for insert
to authenticated
with check (
  id_comprador = (select auth.uid())
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
