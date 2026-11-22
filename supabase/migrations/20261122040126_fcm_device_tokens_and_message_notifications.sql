create table if not exists public.dispositivos_fcm (
  id_usuario uuid not null references auth.users(id) on delete cascade,
  token text not null check (length(token) between 20 and 4096),
  plataforma text not null default 'android'
    check (plataforma in ('android')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (id_usuario, token)
);

alter table public.dispositivos_fcm enable row level security;
revoke all on public.dispositivos_fcm from anon, authenticated;
grant select, insert, update, delete on public.dispositivos_fcm to authenticated;

create policy dispositivos_fcm_select_self
  on public.dispositivos_fcm for select to authenticated
  using (id_usuario = (select auth.uid()));
create policy dispositivos_fcm_insert_self
  on public.dispositivos_fcm for insert to authenticated
  with check (id_usuario = (select auth.uid()));
create policy dispositivos_fcm_update_self
  on public.dispositivos_fcm for update to authenticated
  using (id_usuario = (select auth.uid()))
  with check (id_usuario = (select auth.uid()));
create policy dispositivos_fcm_delete_self
  on public.dispositivos_fcm for delete to authenticated
  using (id_usuario = (select auth.uid()));

create or replace function private.notify_new_chat_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_buyer_id uuid;
  v_producer_id uuid;
  v_product_name text;
  v_recipient_id uuid;
begin
  select c.id_comprador, p.id_productor, p.nombre_producto
    into v_buyer_id, v_producer_id, v_product_name
  from public.chats_negociacion c
  join public.productos p on p.id_producto = c.id_producto
  where c.id_chat = new.id_chat;

  if new.id_remitente = v_buyer_id then
    v_recipient_id := v_producer_id;
  elsif new.id_remitente = v_producer_id then
    v_recipient_id := v_buyer_id;
  else
    return new;
  end if;

  if v_recipient_id is not null then
    insert into public.alertas_notificaciones (
      id_usuario_receptor, titulo, mensaje_cuerpo, referencia_tipo, referencia_id
    ) values (
      v_recipient_id,
      'Nuevo mensaje',
      'Tienes un mensaje nuevo sobre ' || coalesce(v_product_name, 'un producto') || '.',
      'chat',
      new.id_chat
    );
  end if;

  return new;
end;
$function$;

revoke all on function private.notify_new_chat_message()
  from public, anon, authenticated;

drop trigger if exists mensajes_notify_chat_participant on public.mensajes;
create trigger mensajes_notify_chat_participant
  after insert on public.mensajes
  for each row execute function private.notify_new_chat_message();

do $migration$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'alertas_notificaciones'
  ) then
    alter publication supabase_realtime
      add table public.alertas_notificaciones;
  end if;
end;
$migration$;
