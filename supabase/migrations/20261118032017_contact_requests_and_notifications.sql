-- Solicitudes de contacto: son consultas previas y no representan pedidos.
create table if not exists public.solicitudes_contacto (
  id_solicitud uuid primary key default gen_random_uuid(),
  id_producto uuid not null
    constraint solicitudes_contacto_id_producto_fkey
    references public.productos(id_producto) on delete cascade,
  id_comprador uuid not null
    constraint solicitudes_contacto_id_comprador_fkey
    references public.usuarios(id_usuario) on delete cascade,
  cantidad_solicitada numeric not null check (cantidad_solicitada > 0),
  mensaje_inicial text not null
    check (length(trim(mensaje_inicial)) between 1 and 2000),
  estado_solicitud text not null default 'pendiente'
    check (estado_solicitud in ('pendiente', 'aceptada', 'rechazada')),
  id_chat uuid unique
    constraint solicitudes_contacto_id_chat_fkey
    references public.chats_negociacion(id_chat) on delete set null,
  created_at timestamptz not null default now(),
  responded_at timestamptz
);

create index if not exists solicitudes_contacto_producto_estado_idx
  on public.solicitudes_contacto (id_producto, estado_solicitud, created_at desc);
create index if not exists solicitudes_contacto_comprador_created_idx
  on public.solicitudes_contacto (id_comprador, created_at desc);
create unique index if not exists solicitudes_contacto_unica_pendiente_idx
  on public.solicitudes_contacto (id_producto, id_comprador)
  where estado_solicitud = 'pendiente';

alter table public.solicitudes_contacto enable row level security;
grant select, insert on public.solicitudes_contacto to authenticated;

create policy solicitudes_contacto_select_participants
  on public.solicitudes_contacto
  for select to authenticated
  using (
    id_comprador = (select auth.uid())
    or exists (
      select 1
      from public.productos p
      where p.id_producto = solicitudes_contacto.id_producto
        and p.id_productor = (select auth.uid())
    )
  );

create policy solicitudes_contacto_insert_buyer
  on public.solicitudes_contacto
  for insert to authenticated
  with check (
    id_comprador = (select auth.uid())
    and (private.has_role('buyer') or private.has_role('producer'))
    and exists (
      select 1
      from public.productos p
      where p.id_producto = solicitudes_contacto.id_producto
        and p.estado_publicacion is true
        and p.cantidad_disponible > 0
        and p.id_productor <> (select auth.uid())
    )
  );

-- Solo el productor propietario puede responder. La funcion privada valida y
-- cambia unicamente el estado, creando el chat en la misma transaccion.
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
  v_chat_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Se requiere una sesion activa.' using errcode = '42501';
  end if;

  select s.id_producto, s.id_comprador, p.id_productor, s.estado_solicitud
    into v_product_id, v_buyer_id, v_producer_id, v_status
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

revoke all on function private.respond_to_contact_request(uuid, boolean)
  from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.respond_to_contact_request(uuid, boolean)
  to authenticated;

create or replace function public.respond_to_contact_request(
  p_solicitud uuid,
  p_aceptar boolean
)
returns uuid
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.respond_to_contact_request(p_solicitud, p_aceptar);
$function$;

revoke all on function public.respond_to_contact_request(uuid, boolean)
  from public, anon;
grant execute on function public.respond_to_contact_request(uuid, boolean)
  to authenticated;

alter table public.alertas_notificaciones
  add column if not exists referencia_tipo text,
  add column if not exists referencia_id uuid;

create or replace function private.notify_contact_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_product_name text;
  v_producer_id uuid;
begin
  select p.nombre_producto, p.id_productor
    into v_product_name, v_producer_id
  from public.productos p
  where p.id_producto = new.id_producto;

  if tg_op = 'INSERT' then
    insert into public.alertas_notificaciones (
      id_usuario_receptor, titulo, mensaje_cuerpo, referencia_tipo, referencia_id
    ) values (
      v_producer_id,
      'Nueva consulta de producto',
      'Tienes una nueva consulta sobre ' || coalesce(v_product_name, 'un producto') || '.',
      'solicitud_contacto',
      new.id_solicitud
    );
  elsif new.estado_solicitud is distinct from old.estado_solicitud then
    insert into public.alertas_notificaciones (
      id_usuario_receptor, titulo, mensaje_cuerpo, referencia_tipo, referencia_id
    ) values (
      new.id_comprador,
      case new.estado_solicitud
        when 'aceptada' then 'El productor acepto tu consulta'
        else 'El productor respondio a tu consulta'
      end,
      case new.estado_solicitud
        when 'aceptada' then 'Ya puedes conversar sobre ' || coalesce(v_product_name, 'tu producto') || '.'
        else 'El productor no puede continuar con la consulta de ' || coalesce(v_product_name, 'tu producto') || '.'
      end,
      'solicitud_contacto',
      new.id_solicitud
    );
  end if;

  return new;
end;
$function$;

revoke all on function private.notify_contact_request() from public, anon, authenticated;

create trigger solicitudes_contacto_notify_insert
  after insert on public.solicitudes_contacto
  for each row execute function private.notify_contact_request();
create trigger solicitudes_contacto_notify_response
  after update of estado_solicitud on public.solicitudes_contacto
  for each row execute function private.notify_contact_request();
