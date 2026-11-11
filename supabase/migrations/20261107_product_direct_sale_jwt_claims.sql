-- INCREMENTAL REVISABLE. NO EJECUTADA. No volver a ejecutar la migración inicial.
-- Ejecutar como postgres. Requiere administrar la membresía del dueño RPC
-- y ser dueño de las tablas para ALTER POLICY; no requiere permisos sobre auth.
BEGIN;
SET LOCAL lock_timeout = '5s';

-- Este parche usa opciones de membresía disponibles desde PostgreSQL 16.
DO $$
BEGIN
  IF pg_catalog.current_setting('server_version_num')::integer < 160000 THEN
    RAISE EXCEPTION 'Esta revisión requiere PostgreSQL 16 o superior';
  END IF;
END;
$$;

CREATE TEMP TABLE agro_direct_sale_jwt_patch_state (
  membership_changed boolean NOT NULL,
  public_create_added boolean NOT NULL,
  session_member name NOT NULL,
  set_was_allowed boolean NOT NULL,
  temporary_grantor oid,
  grant_existed boolean NOT NULL DEFAULT false
) ON COMMIT DROP;
CREATE TEMP TABLE agro_direct_sale_jwt_memberships_before (
  roleid oid, member oid, grantor oid,
  admin_option boolean, inherit_option boolean, set_option boolean
) ON COMMIT DROP;

DO $$
DECLARE rpc_oid oid; owner_oid oid; session_oid oid; grantor_oid oid;
  grantor_name name; administrators text;
BEGIN
  IF current_user <> 'postgres' THEN
    RAISE EXCEPTION 'Esta propuesta debe revisarse y ejecutarse como postgres';
  END IF;
  rpc_oid := pg_catalog.to_regprocedure(
    'public.agro_pasar_a_venta_directa(text,numeric,numeric,text,bigint,boolean)');
  SELECT oid INTO owner_oid FROM pg_catalog.pg_roles WHERE rolname = 'agro_direct_sale_executor';
  IF rpc_oid IS NULL OR owner_oid IS NULL THEN
    RAISE EXCEPTION 'Se requiere la RPC instalada y su dueño dedicado';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc
                 WHERE oid = rpc_oid AND proowner = owner_oid AND prosecdef
                   AND prorettype = 'jsonb'::regtype
                   AND proargnames = ARRAY['p_id_producto', 'p_cantidad', 'p_precio',
                                            'p_unidad', 'p_fase_esperada', 'p_disponible']) THEN
    RAISE EXCEPTION 'La firma, respuesta o dueño RPC no coinciden: inspeccionar antes de reemplazar';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE oid = owner_oid
             AND (rolcanlogin OR rolsuper OR rolbypassrls OR rolcreaterole OR rolcreatedb)) THEN
    RAISE EXCEPTION 'El dueño dedicado tiene privilegios inesperados';
  END IF;
  IF pg_catalog.pg_has_role('authenticated', owner_oid, 'MEMBER')
     OR pg_catalog.pg_has_role('anon', owner_oid, 'MEMBER') THEN
    RAISE EXCEPTION 'Un rol cliente puede asumir el dueño RPC: revisar membresías';
  END IF;
  IF pg_catalog.to_regnamespace('agro_direct_sale_private') IS NOT NULL THEN
    RAISE EXCEPTION 'El esquema del parche ya existe: revisar antes de repetir la instalación';
  END IF;

  SELECT oid INTO session_oid FROM pg_catalog.pg_roles WHERE rolname = session_user;
  IF NOT pg_catalog.pg_has_role(session_user, 'postgres', 'SET') THEN
    RAISE EXCEPTION 'session_user no puede volver al rol postgres tras reemplazar la RPC';
  END IF;
  -- Guardar cada otorgante: no sobrescribir la concesión de un administrador ajeno.
  INSERT INTO pg_temp.agro_direct_sale_jwt_memberships_before
    SELECT roleid, member, grantor, admin_option, inherit_option, set_option
    FROM pg_catalog.pg_auth_members WHERE roleid = owner_oid AND member = session_oid;
  INSERT INTO pg_temp.agro_direct_sale_jwt_patch_state (
    membership_changed, public_create_added, session_member, set_was_allowed)
  VALUES (false, NOT pg_catalog.has_schema_privilege(owner_oid, 'public', 'CREATE'),
    session_user, pg_catalog.pg_has_role(session_user, owner_oid, 'SET'));

  -- SET ROLE comprueba session_user, no basta con MEMBER ni con current_user.
  IF NOT pg_catalog.pg_has_role(session_user, owner_oid, 'SET') THEN
    -- GRANTED BY exige privilegios del otorgante y ADMIN OPTION sobre el destino.
    -- El superusuario bootstrap (OID reservado 10) puede otorgar sin ADMIN explícito.
    SELECT r.oid, r.rolname INTO grantor_oid, grantor_name
    FROM pg_catalog.pg_roles r
    WHERE (EXISTS (SELECT 1 FROM pg_catalog.pg_auth_members m
                   WHERE m.roleid = owner_oid AND m.member = r.oid AND m.admin_option)
           AND pg_catalog.pg_has_role(current_user, r.oid, 'USAGE'))
       OR (r.oid = 10 AND r.rolsuper AND
           (SELECT rolsuper FROM pg_catalog.pg_roles WHERE rolname = current_user))
    ORDER BY (r.rolname = current_user) DESC, r.oid
    LIMIT 1;
    SELECT pg_catalog.string_agg(pg_catalog.quote_ident(r.rolname), ', ' ORDER BY r.rolname)
      INTO administrators FROM pg_catalog.pg_roles r
      WHERE r.rolsuper OR EXISTS (SELECT 1 FROM pg_catalog.pg_auth_members m
        WHERE m.roleid = owner_oid AND m.member = r.oid AND m.admin_option);
    IF grantor_oid IS NULL THEN
      RAISE EXCEPTION USING ERRCODE = '42501',
        MESSAGE = 'Falta SET sobre agro_direct_sale_executor y postgres no puede habilitarlo temporalmente',
        HINT = 'Debe intervenir un administrador con ADMIN OPTION sobre agro_direct_sale_executor o un superusuario. Roles detectados: '
          || COALESCE(administrators, '(ninguno visible)');
    END IF;
    UPDATE pg_temp.agro_direct_sale_jwt_patch_state SET
      temporary_grantor = grantor_oid,
      grant_existed = EXISTS (SELECT 1 FROM pg_temp.agro_direct_sale_jwt_memberships_before b
                             WHERE b.grantor = grantor_oid);
    BEGIN
      IF (SELECT grant_existed FROM pg_temp.agro_direct_sale_jwt_patch_state) THEN
        -- Modificar solo SET; ADMIN e INHERIT conservan sus valores originales.
        EXECUTE pg_catalog.format(
          'GRANT agro_direct_sale_executor TO %I WITH SET TRUE GRANTED BY %I',
          session_user, grantor_name);
      ELSE
        -- Concesión separada y mínima; la membresía original permanece intacta.
        EXECUTE pg_catalog.format(
          'GRANT agro_direct_sale_executor TO %I WITH ADMIN FALSE, INHERIT FALSE, SET TRUE GRANTED BY %I',
          session_user, grantor_name);
      END IF;
    EXCEPTION WHEN insufficient_privilege THEN
      RAISE EXCEPTION USING ERRCODE = '42501',
        MESSAGE = 'El administrador no pudo habilitar SET temporalmente; no se modificaron la RPC ni las políticas',
        HINT = 'Revisar autoridad del otorgante ' || pg_catalog.quote_ident(grantor_name)
          || '. Administradores del rol detectados: ' || COALESCE(administrators, '(ninguno visible)');
    END;
    UPDATE pg_temp.agro_direct_sale_jwt_patch_state SET membership_changed = true;
  END IF;
  IF NOT pg_catalog.pg_has_role(session_user, owner_oid, 'SET') THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'SET sigue deshabilitado; se aborta antes de modificar la RPC o las políticas';
  END IF;
  IF (SELECT public_create_added FROM pg_temp.agro_direct_sale_jwt_patch_state) THEN
    GRANT CREATE ON SCHEMA public TO agro_direct_sale_executor;
  END IF;
END;
$$;

-- Helper INVOKER: no eleva permisos ni valida firmas. Solo PostgREST debe
-- establecer estos claims tras validar el JWT; no exponer set_config por API.
CREATE SCHEMA agro_direct_sale_private AUTHORIZATION postgres;
REVOKE ALL ON SCHEMA agro_direct_sale_private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA agro_direct_sale_private TO agro_direct_sale_executor;

CREATE FUNCTION agro_direct_sale_private.jwt_user_id()
RETURNS uuid LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE raw_claims text; claims jsonb; subject text;
BEGIN
  raw_claims := pg_catalog.current_setting('request.jwt.claims', true);
  IF raw_claims IS NULL OR pg_catalog.btrim(raw_claims) = '' THEN
    RETURN NULL;
  END IF;
  claims := raw_claims::jsonb;
  IF pg_catalog.jsonb_typeof(claims) IS DISTINCT FROM 'object'
     OR pg_catalog.jsonb_typeof(claims->'sub') IS DISTINCT FROM 'string' THEN
    RETURN NULL;
  END IF;
  subject := pg_catalog.btrim(claims->>'sub');
  IF subject IS NULL OR subject = '' THEN RETURN NULL; END IF;
  RETURN subject::uuid;
EXCEPTION WHEN invalid_text_representation THEN
  -- JSON o UUID inválido: la RPC debe rechazar la sesión, nunca inventar un usuario.
  RETURN NULL;
END;
$$;

-- Limitar también ACL que pudieran proceder de ALTER DEFAULT PRIVILEGES.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT DISTINCT a.grantee, roles.rolname
    FROM pg_catalog.pg_namespace n
    CROSS JOIN LATERAL pg_catalog.aclexplode(
      COALESCE(n.nspacl, pg_catalog.acldefault('n', n.nspowner))) a
    LEFT JOIN pg_catalog.pg_roles roles ON roles.oid = a.grantee
    WHERE n.nspname = 'agro_direct_sale_private'
      AND a.grantee NOT IN (n.nspowner,
        (SELECT oid FROM pg_catalog.pg_roles WHERE rolname = 'agro_direct_sale_executor'))
  LOOP
    EXECUTE pg_catalog.format('REVOKE ALL ON SCHEMA agro_direct_sale_private FROM %s',
      CASE WHEN r.grantee = 0 THEN 'PUBLIC' ELSE pg_catalog.quote_ident(r.rolname) END);
  END LOOP;
  FOR r IN
    SELECT DISTINCT a.grantee, roles.rolname
    FROM pg_catalog.pg_proc p
    CROSS JOIN LATERAL pg_catalog.aclexplode(
      COALESCE(p.proacl, pg_catalog.acldefault('f', p.proowner))) a
    LEFT JOIN pg_catalog.pg_roles roles ON roles.oid = a.grantee
    WHERE p.oid = 'agro_direct_sale_private.jwt_user_id()'::regprocedure
      AND a.grantee <> p.proowner
  LOOP
    EXECUTE pg_catalog.format('REVOKE ALL ON FUNCTION agro_direct_sale_private.jwt_user_id() FROM %s',
      CASE WHEN r.grantee = 0 THEN 'PUBLIC' ELSE pg_catalog.quote_ident(r.rolname) END);
  END LOOP;
END;
$$;
GRANT EXECUTE ON FUNCTION agro_direct_sale_private.jwt_user_id() TO agro_direct_sale_executor;

-- Mantener las mismas políticas y su alcance exclusivo al dueño dedicado.
ALTER POLICY agro_rpc_producto_select ON public.productos TO agro_direct_sale_executor
  USING (id_productor = (SELECT agro_direct_sale_private.jwt_user_id()));
ALTER POLICY agro_rpc_producto_update ON public.productos TO agro_direct_sale_executor
  USING (id_productor = (SELECT agro_direct_sale_private.jwt_user_id()))
  WITH CHECK (id_productor = (SELECT agro_direct_sale_private.jwt_user_id()));
ALTER POLICY agro_rpc_usuario_select ON public.usuarios TO agro_direct_sale_executor
  USING (id_usuario = (SELECT agro_direct_sale_private.jwt_user_id()));
ALTER POLICY agro_rpc_tipo_select ON public.tipos_usuario TO agro_direct_sale_executor USING (true);
ALTER POLICY agro_rpc_fase_select ON public.fases_comercializacion TO agro_direct_sale_executor USING (true);
ALTER POLICY agro_rpc_historial_select ON public.historial_fases_producto TO agro_direct_sale_executor
  USING (EXISTS (SELECT 1 FROM public.productos p
    WHERE p.id_producto = historial_fases_producto.id_producto
      AND p.id_productor = (SELECT agro_direct_sale_private.jwt_user_id())));
ALTER POLICY agro_rpc_historial_insert ON public.historial_fases_producto TO agro_direct_sale_executor
  WITH CHECK (EXISTS (SELECT 1 FROM public.productos p
    WHERE p.id_producto = historial_fases_producto.id_producto
      AND p.id_productor = (SELECT agro_direct_sale_private.jwt_user_id())));

-- Reemplazar como el dueño real conserva propiedad y OID; no se hace DROP.
-- Revalidar SET de session_user inmediatamente antes de asumir el dueño.
DO $$
BEGIN
  IF NOT pg_catalog.pg_has_role(session_user, 'agro_direct_sale_executor', 'SET') THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'SET no disponible antes de asumir el dueño RPC';
  END IF;
END;
$$;
SET LOCAL ROLE agro_direct_sale_executor;


CREATE OR REPLACE FUNCTION public.agro_pasar_a_venta_directa(
  p_id_producto text, p_cantidad numeric, p_precio numeric,
  p_unidad text, p_fase_esperada bigint, p_disponible boolean DEFAULT false
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = '' SET row_security = on SET lock_timeout = '5s'
AS $$
DECLARE
  actual public.productos%ROWTYPE;
  actualizado public.productos%ROWTYPE;
  usuario uuid;
  producto_uuid uuid;
  preventa integer;
  venta integer;
  historial_uuid uuid;
  antes bigint;
  despues bigint;
BEGIN
  -- No confiar en el rol ni en la propiedad enviados por Flutter.
  usuario := agro_direct_sale_private.jwt_user_id();
  IF usuario IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Inicia sesión como productor';
  END IF;
  producto_uuid := p_id_producto::uuid;
  SELECT p.* INTO actual FROM public.productos p
    WHERE p.id_producto = producto_uuid FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Producto ajeno o no disponible';
  END IF;
  -- Autorizar nuevamente con la fila bloqueada.
  IF actual.id_productor IS DISTINCT FROM usuario OR NOT EXISTS (
    SELECT 1 FROM public.usuarios u
    JOIN public.tipos_usuario t ON t.id_tipo_usuario = u.id_tipo_usuario
    WHERE u.id_usuario = usuario AND t.nombre_tipo = 'producer'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Solo el productor propietario';
  END IF;
  SELECT f.id_fase INTO STRICT preventa FROM public.fases_comercializacion f
    WHERE pg_catalog.lower(pg_catalog.btrim(f.nombre_fase)) = 'preventa';
  SELECT f.id_fase INTO STRICT venta FROM public.fases_comercializacion f
    WHERE pg_catalog.lower(pg_catalog.btrim(f.nombre_fase)) = 'venta directa';
  IF actual.id_fase_actual IS DISTINCT FROM preventa OR p_fase_esperada IS DISTINCT FROM preventa THEN
    RAISE EXCEPTION 'El producto ya no está en Preventa';
  END IF;
  IF p_disponible IS DISTINCT FROM true OR p_cantidad IS NULL OR p_precio IS NULL
     OR p_cantidad::text IN ('NaN', 'Infinity', '-Infinity') OR p_precio::text IN ('NaN', 'Infinity', '-Infinity')
     OR p_cantidad <= 0 OR p_cantidad > 99999999.99
     OR p_cantidad <> pg_catalog.round(p_cantidad, 2) OR p_precio < 0 THEN
    RAISE EXCEPTION 'Confirmar disponibilidad y revisar cantidad/precio';
  END IF;
  IF p_unidad IS NULL OR p_unidad NOT IN ('kg', 'lb', 'unidad')
     OR actual.unidad_medida IS DISTINCT FROM p_unidad
     OR (p_unidad = 'unidad' AND p_cantidad <> pg_catalog.trunc(p_cantidad)) THEN
    RAISE EXCEPTION 'Conservar la unidad registrada y validar la cantidad';
  END IF;

  SELECT count(*) INTO antes FROM public.historial_fases_producto h WHERE h.id_producto = producto_uuid;
  UPDATE public.productos SET id_fase_actual = venta,
    cantidad_disponible = p_cantidad, precio_unitario = p_precio
    WHERE id_producto = producto_uuid AND id_productor = usuario AND id_fase_actual = preventa;
  IF NOT FOUND THEN RAISE EXCEPTION 'No se pudo actualizar el producto'; END IF;

  -- Una sola escritura de historial, en la misma transacción que el UPDATE.
  -- UUID y fecha proceden de sus defaults; la fase anterior solo se devuelve a Flutter.
  INSERT INTO public.historial_fases_producto (id_producto, id_fase_nueva)
    VALUES (producto_uuid, venta) RETURNING id_historial INTO historial_uuid;
  SELECT p.* INTO STRICT actualizado FROM public.productos p WHERE p.id_producto = producto_uuid;
  SELECT count(*) INTO despues FROM public.historial_fases_producto h WHERE h.id_producto = producto_uuid;
  IF despues <> antes + 1 OR historial_uuid IS NULL OR NOT EXISTS (
       SELECT 1 FROM public.historial_fases_producto h
       WHERE h.id_historial = historial_uuid AND h.id_producto = producto_uuid AND h.id_fase_nueva = venta)
     OR actualizado.id_productor IS DISTINCT FROM usuario
     OR actualizado.id_fase_actual IS DISTINCT FROM venta
     OR actualizado.cantidad_disponible IS DISTINCT FROM p_cantidad
     OR actualizado.precio_unitario IS DISTINCT FROM p_precio
     OR actualizado.unidad_medida IS DISTINCT FROM actual.unidad_medida
     OR actualizado.estado_publicacion IS DISTINCT FROM actual.estado_publicacion THEN
    RAISE EXCEPTION 'No se pudo confirmar producto e historial; se revierte toda la transición';
  END IF;
  RETURN pg_catalog.to_jsonb(actualizado) || pg_catalog.jsonb_build_object(
    'fase_anterior', actual.id_fase_actual, 'historial_registrado', true);
END;
$$;

-- Ajustar ACL como el dueño real, sin depender de INHERIT en postgres.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT DISTINCT a.grantee, roles.rolname
    FROM pg_catalog.pg_proc p
    CROSS JOIN LATERAL pg_catalog.aclexplode(
      COALESCE(p.proacl, pg_catalog.acldefault('f', p.proowner))) a
    LEFT JOIN pg_catalog.pg_roles roles ON roles.oid = a.grantee
    WHERE p.oid = 'public.agro_pasar_a_venta_directa(text,numeric,numeric,text,bigint,boolean)'::regprocedure
      AND a.grantee <> p.proowner
      AND a.grantee <> (SELECT oid FROM pg_catalog.pg_roles WHERE rolname = 'authenticated')
  LOOP
    EXECUTE pg_catalog.format(
      'REVOKE ALL ON FUNCTION public.agro_pasar_a_venta_directa(text,numeric,numeric,text,bigint,boolean) FROM %s',
      CASE WHEN r.grantee = 0 THEN 'PUBLIC' ELSE pg_catalog.quote_ident(r.rolname) END);
  END LOOP;
  GRANT EXECUTE ON FUNCTION public.agro_pasar_a_venta_directa(text,numeric,numeric,text,bigint,boolean)
    TO authenticated;
END;
$$;

SET LOCAL ROLE postgres;

DO $$
DECLARE policy_record record; owner_oid oid;
BEGIN
  SELECT oid INTO owner_oid FROM pg_catalog.pg_roles WHERE rolname = 'agro_direct_sale_executor';
  -- Revisar TODAS las políticas aplicables, incluidas PUBLIC y roles heredados.
  -- Una política compartida no corregida hace abortar todo, sin cambiar otros módulos.
  FOR policy_record IN
    SELECT p.oid, p.polname, p.polrelid,
      COALESCE(pg_catalog.pg_get_expr(p.polqual, p.polrelid), '') || ' ' ||
      COALESCE(pg_catalog.pg_get_expr(p.polwithcheck, p.polrelid), '') AS expression
    FROM pg_catalog.pg_policy p
    WHERE p.polrelid IN ('public.productos'::regclass, 'public.usuarios'::regclass,
      'public.tipos_usuario'::regclass, 'public.fases_comercializacion'::regclass,
      'public.historial_fases_producto'::regclass)
      AND EXISTS (SELECT 1 FROM unnest(p.polroles) role_oid
        WHERE CASE WHEN role_oid = 0 THEN true
                   ELSE pg_catalog.pg_has_role(owner_oid, role_oid, 'USAGE') END)
  LOOP
    IF policy_record.expression ~* '"?auth"?[[:space:]]*\.[[:space:]]*"?uid"?[[:space:]]*\('
       OR EXISTS (
         WITH RECURSIVE llamadas(oid) AS (
           SELECT d.refobjid FROM pg_catalog.pg_depend d
           WHERE d.classid = 'pg_catalog.pg_policy'::regclass AND d.objid = policy_record.oid
             AND d.refclassid = 'pg_catalog.pg_proc'::regclass
           UNION
           SELECT d.refobjid FROM llamadas c
           JOIN pg_catalog.pg_depend d ON d.classid = 'pg_catalog.pg_proc'::regclass AND d.objid = c.oid
           WHERE d.refclassid = 'pg_catalog.pg_proc'::regclass
         )
         SELECT 1 FROM llamadas c
         JOIN pg_catalog.pg_proc f ON f.oid = c.oid
         JOIN pg_catalog.pg_namespace n ON n.oid = f.pronamespace
         WHERE n.nspname = 'auth'
            OR CASE WHEN f.prokind = 'f' THEN pg_catalog.pg_get_functiondef(f.oid)
              ~* '"?auth"?[[:space:]]*\.[[:space:]]*"?uid"?[[:space:]]*\(' ELSE false END
       ) THEN
      RAISE EXCEPTION 'La política % de % aún depende de auth; revisar su alcance antes de instalar',
        policy_record.polname, policy_record.polrelid::regclass;
    END IF;
  END LOOP;
  IF pg_catalog.pg_get_functiondef(
       'public.agro_pasar_a_venta_directa(text,numeric,numeric,text,bigint,boolean)'::regprocedure)
       ~* '"?auth"?[[:space:]]*\.[[:space:]]*"?uid"?[[:space:]]*\(' THEN
    RAISE EXCEPTION 'La RPC aún contiene dependencia de auth.uid';
  END IF;
  IF pg_catalog.has_function_privilege('authenticated', 'agro_direct_sale_private.jwt_user_id()', 'EXECUTE')
     OR pg_catalog.has_function_privilege('anon', 'agro_direct_sale_private.jwt_user_id()', 'EXECUTE')
     OR pg_catalog.has_schema_privilege('authenticated', 'agro_direct_sale_private', 'USAGE')
     OR pg_catalog.has_schema_privilege('anon', 'agro_direct_sale_private', 'USAGE') THEN
    RAISE EXCEPTION 'El helper o su esquema siguen accesibles para roles cliente';
  END IF;
END;
$$;

-- Retirar solo los permisos temporales añadidos por este parche.
DO $$
DECLARE state record; original_set boolean; grantor_name name; owner_oid oid; session_oid oid;
BEGIN
  SELECT * INTO STRICT state FROM pg_temp.agro_direct_sale_jwt_patch_state;
  SELECT oid INTO owner_oid FROM pg_catalog.pg_roles WHERE rolname = 'agro_direct_sale_executor';
  SELECT oid INTO session_oid FROM pg_catalog.pg_roles WHERE rolname = state.session_member;
  IF state.public_create_added THEN
    REVOKE CREATE ON SCHEMA public FROM agro_direct_sale_executor;
  END IF;
  IF state.membership_changed THEN
    SELECT rolname INTO STRICT grantor_name FROM pg_catalog.pg_roles WHERE oid = state.temporary_grantor;
    IF state.grant_existed THEN
      SELECT set_option INTO STRICT original_set
        FROM pg_temp.agro_direct_sale_jwt_memberships_before WHERE grantor = state.temporary_grantor;
      EXECUTE pg_catalog.format(
        'GRANT agro_direct_sale_executor TO %I WITH SET %s GRANTED BY %I',
        state.session_member, CASE WHEN original_set THEN 'TRUE' ELSE 'FALSE' END, grantor_name);
    ELSE
      -- No eliminar la membresía original ni usar CASCADE.
      EXECUTE pg_catalog.format(
        'REVOKE agro_direct_sale_executor FROM %I GRANTED BY %I RESTRICT',
        state.session_member, grantor_name);
    END IF;
  END IF;
  -- Comparar otorgantes y las tres opciones en ambas direcciones antes de COMMIT.
  IF EXISTS (
    (SELECT roleid, member, grantor, admin_option, inherit_option, set_option
     FROM pg_catalog.pg_auth_members WHERE roleid = owner_oid AND member = session_oid
     EXCEPT
     SELECT * FROM pg_temp.agro_direct_sale_jwt_memberships_before)
    UNION ALL
    (SELECT * FROM pg_temp.agro_direct_sale_jwt_memberships_before
     EXCEPT
     SELECT roleid, member, grantor, admin_option, inherit_option, set_option
     FROM pg_catalog.pg_auth_members WHERE roleid = owner_oid AND member = session_oid)
  ) OR pg_catalog.pg_has_role(session_user, owner_oid, 'SET') IS DISTINCT FROM state.set_was_allowed THEN
    RAISE EXCEPTION 'No se restauraron exactamente las opciones originales de membresía; se revierte todo';
  END IF;
END;
$$;

-- PostgREST recibe la actualización al confirmar la transacción.
NOTIFY pgrst, 'reload schema';
COMMIT;
