-- PROPUESTA REVISABLE. NO EJECUTADA EN SUPABASE.
-- Instalar una sola vez con el administrador de migraciones, tras probar en staging.
-- Requiere desplegar también el PATCH Flutter que omite fase y propietario.
BEGIN;
SET LOCAL lock_timeout = '5s';

-- No reemplazar silenciosamente objetos de una propuesta anterior ya instalada.
DO $$
DECLARE inicial record;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'agro_direct_sale_executor')
     OR EXISTS (SELECT 1 FROM pg_catalog.pg_proc p
                JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
                WHERE n.nspname = 'public' AND p.proname = 'agro_pasar_a_venta_directa')
     OR EXISTS (SELECT 1 FROM pg_catalog.pg_trigger
                WHERE tgrelid = 'public.productos'::regclass
                  AND tgname = 'zz_agro_auditar_venta_directa') THEN
    RAISE EXCEPTION 'Hay objetos previos instalados: preparar una migración incremental tras inspeccionarlos';
  END IF;
  IF NOT (SELECT relrowsecurity FROM pg_catalog.pg_class WHERE oid = 'public.productos'::regclass) THEN
    RAISE EXCEPTION 'Confirmar RLS de productos antes de instalar';
  END IF;
  IF (SELECT count(*) FROM public.fases_comercializacion
      WHERE lower(btrim(nombre_fase)) = 'preventa') <> 1
     OR (SELECT count(*) FROM public.fases_comercializacion
         WHERE lower(btrim(nombre_fase)) = 'venta directa') <> 1 THEN
    RAISE EXCEPTION 'Se necesita una única Preventa y una única Venta directa';
  END IF;
  -- Esquema confirmado: producto y fase nueva; no existe id_fase_anterior.
  -- UUID y fecha se dejan a sus defaults, sin asumir el nombre de la fecha.
  IF (SELECT count(*) FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'historial_fases_producto'
        AND ((column_name IN ('id_historial', 'id_producto') AND udt_name = 'uuid')
          OR (column_name = 'id_fase_nueva' AND udt_name = 'int4'))) <> 3
     OR NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'public' AND table_name = 'historial_fases_producto'
                      AND column_name = 'id_historial' AND column_default IS NOT NULL)
     OR NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'public' AND table_name = 'historial_fases_producto'
                      AND data_type IN ('timestamp with time zone', 'timestamp without time zone')
                      AND column_default IS NOT NULL)
     OR EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'public' AND table_name = 'historial_fases_producto'
                  AND is_nullable = 'NO' AND column_default IS NULL
                  AND is_identity = 'NO' AND is_generated = 'NEVER'
                  AND column_name NOT IN ('id_producto', 'id_fase_nueva')) THEN
    RAISE EXCEPTION 'Revisar tipos y defaults del historial real';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_trigger
             WHERE tgrelid IN ('public.productos'::regclass, 'public.historial_fases_producto'::regclass)
               AND NOT tgisinternal AND tgdeferrable) THEN
    RAISE EXCEPTION 'Revisar triggers diferibles antes de instalar';
  END IF;

  -- Conservar el trigger inicial existente. Un trigger INVOKER dejaría de funcionar
  -- al retirar INSERT al cliente: se exige revisarlo antes de cambiar privilegios.
  IF (SELECT count(*) FROM pg_catalog.pg_trigger t
      JOIN pg_catalog.pg_proc p ON p.oid = t.tgfoid
      WHERE t.tgrelid = 'public.productos'::regclass AND NOT t.tgisinternal
        AND (t.tgtype::integer & 4) = 4 AND (t.tgtype::integer & 24) = 0
        AND t.tgenabled IN ('O', 'A')
        AND pg_catalog.pg_get_functiondef(p.oid) ILIKE '%historial_fases_producto%') <> 1 THEN
    RAISE EXCEPTION 'Identificar un único trigger inicial activo antes de instalar';
  END IF;
  SELECT t.tgname, p.prosecdef, p.proowner INTO inicial
  FROM pg_catalog.pg_trigger t
  JOIN pg_catalog.pg_proc p ON p.oid = t.tgfoid
  WHERE t.tgrelid = 'public.productos'::regclass AND NOT t.tgisinternal
    AND (t.tgtype::integer & 4) = 4 AND (t.tgtype::integer & 24) = 0
    AND t.tgenabled IN ('O', 'A')
    AND pg_catalog.pg_get_functiondef(p.oid) ILIKE '%historial_fases_producto%';
  IF NOT FOUND OR NOT inicial.prosecdef THEN
    RAISE EXCEPTION 'Confirmar función SECURITY DEFINER del trigger inicial; no se retirará INSERT hasta preservarlo';
  END IF;
  IF NOT pg_catalog.has_column_privilege(inicial.proowner, 'public.historial_fases_producto', 'id_producto', 'INSERT')
     OR NOT pg_catalog.has_column_privilege(inicial.proowner, 'public.historial_fases_producto', 'id_fase_nueva', 'INSERT') THEN
    RAISE EXCEPTION 'El dueño del trigger inicial necesita permisos propios para registrar el historial';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_trigger t
    JOIN pg_catalog.pg_proc p ON p.oid = t.tgfoid
    WHERE t.tgrelid = 'public.productos'::regclass AND NOT t.tgisinternal
      AND (t.tgtype::integer & 16) = 16
      AND pg_catalog.pg_get_functiondef(p.oid) ILIKE '%historial_fases_producto%'
  ) THEN
    RAISE EXCEPTION 'Existe auditoría UPDATE no contemplada: revisar antes de añadir el INSERT explícito';
  END IF;
END;
$$;

-- ACL por tabla y columna: no basta con REVOKE UPDATE(id_fase_actual).
-- No se revocan permisos de roles padres compartidos sin revisión humana.
REVOKE UPDATE ON TABLE public.productos FROM PUBLIC, anon, authenticated;
REVOKE INSERT ON TABLE public.historial_fases_producto FROM PUBLIC, anon, authenticated;
DO $$
DECLARE columnas text;
BEGIN
  SELECT string_agg(quote_ident(attname), ', ' ORDER BY attnum) INTO columnas
  FROM pg_catalog.pg_attribute
  WHERE attrelid = 'public.productos'::regclass AND attnum > 0 AND NOT attisdropped;
  EXECUTE format('REVOKE UPDATE (%s) ON public.productos FROM PUBLIC, anon, authenticated', columnas);
  SELECT string_agg(quote_ident(attname), ', ' ORDER BY attnum) INTO columnas
  FROM pg_catalog.pg_attribute
  WHERE attrelid = 'public.historial_fases_producto'::regclass AND attnum > 0 AND NOT attisdropped;
  EXECUTE format('REVOKE INSERT (%s) ON public.historial_fases_producto FROM PUBLIC, anon, authenticated', columnas);
END;
$$;

-- Lista exacta usada por edición completa, cantidad y visibilidad. RLS se conserva.
GRANT UPDATE (id_categoria, nombre_producto, cantidad_disponible, unidad_medida,
              precio_unitario, fecha_estimada_cosecha, estado_publicacion)
ON public.productos TO authenticated;

-- Revisar también roles alcanzables por membresía, incluso sin herencia automática.
-- Si existe un permiso heredado, abortar TODO y revisar su origen sin CASCADE.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    WITH RECURSIVE alcanzables(oid) AS (
      SELECT oid FROM pg_catalog.pg_roles WHERE rolname IN ('anon', 'authenticated')
      UNION
      SELECT m.roleid FROM pg_catalog.pg_auth_members m JOIN alcanzables a ON m.member = a.oid
    )
    SELECT p.oid, p.rolname, p.rolsuper, p.rolbypassrls
    FROM alcanzables a JOIN pg_catalog.pg_roles p ON p.oid = a.oid
  LOOP
    IF r.rolsuper OR r.rolbypassrls
       OR EXISTS (SELECT 1 FROM pg_catalog.pg_class
                  WHERE oid IN ('public.productos'::regclass, 'public.historial_fases_producto'::regclass)
                    AND relowner = r.oid)
       OR pg_catalog.has_column_privilege(r.oid, 'public.productos', 'id_fase_actual', 'UPDATE')
       OR pg_catalog.has_any_column_privilege(r.oid, 'public.historial_fases_producto', 'INSERT') THEN
      RAISE EXCEPTION 'Permiso cliente/heredado peligroso mediante rol %; revisar ACL y membresías antes de instalar', r.rolname;
    END IF;
  END LOOP;
END;
$$;

-- Dueño exclusivo de esta RPC: no es dueño de tablas, no omite RLS y no tiene login.
CREATE ROLE agro_direct_sale_executor NOLOGIN NOINHERIT NOSUPERUSER
  NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
GRANT agro_direct_sale_executor TO CURRENT_USER;
GRANT USAGE ON SCHEMA public, auth TO agro_direct_sale_executor;
GRANT EXECUTE ON FUNCTION auth.uid() TO agro_direct_sale_executor;
-- SELECT completo permite conservar la respuesta JSON anterior del producto.
GRANT SELECT ON public.productos TO agro_direct_sale_executor;
GRANT SELECT (id_usuario, id_tipo_usuario) ON public.usuarios TO agro_direct_sale_executor;
GRANT SELECT (id_tipo_usuario, nombre_tipo) ON public.tipos_usuario TO agro_direct_sale_executor;
GRANT SELECT (id_fase, nombre_fase) ON public.fases_comercializacion TO agro_direct_sale_executor;
GRANT UPDATE (id_fase_actual, cantidad_disponible, precio_unitario)
  ON public.productos TO agro_direct_sale_executor;
GRANT INSERT (id_producto, id_fase_nueva),
      SELECT (id_historial, id_producto, id_fase_nueva)
  ON public.historial_fases_producto TO agro_direct_sale_executor;

-- Políticas solo para el dueño dedicado; no ampliar políticas de los clientes.
CREATE POLICY agro_rpc_producto_select ON public.productos
  FOR SELECT TO agro_direct_sale_executor USING (id_productor = (SELECT auth.uid()));
CREATE POLICY agro_rpc_producto_update ON public.productos
  FOR UPDATE TO agro_direct_sale_executor
  USING (id_productor = (SELECT auth.uid()))
  WITH CHECK (id_productor = (SELECT auth.uid()));
CREATE POLICY agro_rpc_usuario_select ON public.usuarios
  FOR SELECT TO agro_direct_sale_executor USING (id_usuario = (SELECT auth.uid()));
CREATE POLICY agro_rpc_tipo_select ON public.tipos_usuario
  FOR SELECT TO agro_direct_sale_executor USING (true);
CREATE POLICY agro_rpc_fase_select ON public.fases_comercializacion
  FOR SELECT TO agro_direct_sale_executor USING (true);
CREATE POLICY agro_rpc_historial_select ON public.historial_fases_producto
  FOR SELECT TO agro_direct_sale_executor USING (
    EXISTS (SELECT 1 FROM public.productos p
            WHERE p.id_producto = historial_fases_producto.id_producto AND p.id_productor = (SELECT auth.uid())));
CREATE POLICY agro_rpc_historial_insert ON public.historial_fases_producto
  FOR INSERT TO agro_direct_sale_executor WITH CHECK (
    EXISTS (SELECT 1 FROM public.productos p
            WHERE p.id_producto = historial_fases_producto.id_producto AND p.id_productor = (SELECT auth.uid())));

CREATE FUNCTION public.agro_pasar_a_venta_directa(
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
  usuario := auth.uid();
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

-- Transferir la función requiere CREATE temporal; el dueño no lo conserva.
GRANT CREATE ON SCHEMA public TO agro_direct_sale_executor;
ALTER FUNCTION public.agro_pasar_a_venta_directa(text, numeric, numeric, text, bigint, boolean)
  OWNER TO agro_direct_sale_executor;
REVOKE CREATE ON SCHEMA public FROM agro_direct_sale_executor;
REVOKE ALL ON FUNCTION public.agro_pasar_a_venta_directa(text, numeric, numeric, text, bigint, boolean)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.agro_pasar_a_venta_directa(text, numeric, numeric, text, bigint, boolean)
  TO authenticated;
-- Quitar también EXECUTE concedido por ALTER DEFAULT PRIVILEGES a otros roles.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT DISTINCT a.grantee, roles.rolname
    FROM pg_catalog.pg_proc p
    CROSS JOIN LATERAL pg_catalog.aclexplode(COALESCE(p.proacl, pg_catalog.acldefault('f', p.proowner))) a
    LEFT JOIN pg_catalog.pg_roles roles ON roles.oid = a.grantee
    WHERE p.oid = 'public.agro_pasar_a_venta_directa(text,numeric,numeric,text,bigint,boolean)'::regprocedure
      AND a.grantee <> p.proowner
      AND a.grantee <> (SELECT oid FROM pg_catalog.pg_roles WHERE rolname = 'authenticated')
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.agro_pasar_a_venta_directa(text,numeric,numeric,text,bigint,boolean) FROM %s',
                   CASE WHEN r.grantee = 0 THEN 'PUBLIC' ELSE quote_ident(r.rolname) END);
  END LOOP;
  IF pg_catalog.has_schema_privilege('agro_direct_sale_executor', 'public', 'CREATE') THEN
    RAISE EXCEPTION 'El dueño RPC aún hereda CREATE en public: revisar privilegios del esquema';
  END IF;
END;
$$;
REVOKE agro_direct_sale_executor FROM CURRENT_USER;

-- Verificar el trigger inicial otra vez tras los REVOKE; no alterar su definición.
DO $$
DECLARE inicial record;
BEGIN
  FOR inicial IN
    SELECT p.proowner FROM pg_catalog.pg_trigger t
    JOIN pg_catalog.pg_proc p ON p.oid = t.tgfoid
    WHERE t.tgrelid = 'public.productos'::regclass AND NOT t.tgisinternal
      AND (t.tgtype::integer & 4) = 4
      AND pg_catalog.pg_get_functiondef(p.oid) ILIKE '%historial_fases_producto%'
  LOOP
    IF NOT pg_catalog.has_column_privilege(inicial.proowner, 'public.historial_fases_producto', 'id_producto', 'INSERT')
       OR NOT pg_catalog.has_column_privilege(inicial.proowner, 'public.historial_fases_producto', 'id_fase_nueva', 'INSERT') THEN
      RAISE EXCEPTION 'Los REVOKE afectarían al trigger inicial: revisar su dueño antes de instalar';
    END IF;
  END LOOP;
END;
$$;
COMMIT;

