-- Copia el mensaje de consulta al chat con el comprador como remitente.
create or replace function private.respond_to_contact_request(
  p_solicitud uuid,
  p_aceptar boolean
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_product_id uuid;
  v_buyer_id uuid;
  v_producer_id uuid;
  v_status text;
  v_initial_message text;
  v_chat_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Se requiere una sesion activa.' using errcode = '42501';
  end if;

  select s.id_producto, s.id_comprador, p.id_productor,
         s.estado_solicitud, s.mensaje_inicial
    into v_product_id, v_buyer_id, v_producer_id, v_status, v_initial_message
  from public.solicitudes_contacto s
  join public.productos p on p.id_producto = s.id_producto
  where s.id_solicitud = p_solicitud
  for update of s;

  if not found then
    raise exception 'La solicitud ya no esta disponible.' using errcode = 'P0002';
  end if;
  if v_producer_id <> (select auth.uid()) then
    raise exception 'Solo el productor puede responder esta solicitud.' using errcode = '42501';
  end if;
  if v_status <> 'pendiente' then
    raise exception 'La solicitud ya fue respondida.' using errcode = 'P0001';
  end if;

  if p_aceptar then
    insert into public.chats_negociacion (id_producto, id_comprador)
    values (v_product_id, v_buyer_id)
    on conflict (id_producto, id_comprador) do nothing;

    select c.id_chat into v_chat_id
    from public.chats_negociacion c
    where c.id_producto = v_product_id
      and c.id_comprador = v_buyer_id;

    insert into public.mensajes (id_chat, id_remitente, contenido)
    values (v_chat_id, v_buyer_id, v_initial_message);

    update public.solicitudes_contacto
    set estado_solicitud = 'aceptada', id_chat = v_chat_id, responded_at = now()
    where id_solicitud = p_solicitud;
    return v_chat_id;
  end if;

  update public.solicitudes_contacto
  set estado_solicitud = 'rechazada', responded_at = now()
  where id_solicitud = p_solicitud;
  return null;
end;
$function$;
