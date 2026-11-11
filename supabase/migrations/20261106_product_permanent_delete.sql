-- PROPUESTA PARA REVISIÓN. NO EJECUTADA NI APLICADA A SUPABASE.
-- Requiere autorización explícita antes de crear funciones, triggers o políticas.
-- Basada en las cinco relaciones y en la fase 1=Preventa confirmadas por el usuario.
-- Historial inicial: exactamente una fila, id_fase_nueva=1 y fase actual=1.
-- No concede autorización para eliminar ninguno de los siete productos existentes.
-- Validar primero en una base de pruebas: aislamiento, concurrencia, permisos y triggers actuales.
-- Los bloqueos de tablas son conservadores y afectan brevemente a todas sus escrituras.

BEGIN;

-- Fallar sin alterar RLS si la protección todavía no está habilitada.
DO $$
BEGIN
  IF NOT (SELECT relrowsecurity FROM pg_catalog.pg_class
          WHERE oid = 'public.productos'::pg_catalog.regclass) THEN
    RAISE EXCEPTION 'Revisar y habilitar RLS mediante una propuesta independiente.';
  END IF;
END;
$$;

-- El propietario de esta función debe poder inspeccionar TODAS las filas relacionadas.
-- SECURITY DEFINER se limita al guardián: NO efectúa el DELETE ni concede acceso al cliente.
-- row_security=off evita aceptar un resultado parcial si su propietario no puede omitir RLS.
CREATE FUNCTION public.agro_proteger_producto_antes_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
SET row_security = off
SET lock_timeout = '3s'
AS $$
DECLARE
  numero_historial bigint;
  solo_preventa boolean;
BEGIN
  IF TG_LEVEL = 'STATEMENT' THEN
    -- Esta versión se revisa para READ COMMITTED; no aceptar instantáneas antiguas.
    IF pg_catalog.current_setting('transaction_isolation') <> 'read committed' THEN
      RAISE EXCEPTION 'La eliminación requiere una transacción READ COMMITTED.';
    END IF;

    -- Adquirir estos bloqueos ANTES de visitar las filas del DELETE.
    -- Evita que aparezca actividad entre la comprobación y las cascadas.
    LOCK TABLE public.chats_negociacion,
               public.detalles_pedido,
               public.historial_fases_producto,
               public.intereses_preventa
      IN SHARE ROW EXCLUSIVE MODE;

    -- Si el esquema incorpora otra tabla dependiente, bloquear hasta revisar sus efectos.
    IF EXISTS (
      SELECT 1 FROM pg_catalog.pg_constraint c
      WHERE c.contype = 'f'
        AND c.confrelid = 'public.productos'::pg_catalog.regclass
        AND c.conrelid NOT IN (
          'public.chats_negociacion'::pg_catalog.regclass,
          'public.fotografias_producto'::pg_catalog.regclass,
          'public.historial_fases_producto'::pg_catalog.regclass,
          'public.intereses_preventa'::pg_catalog.regclass,
          'public.detalles_pedido'::pg_catalog.regclass
        )
    ) THEN
      RAISE EXCEPTION 'Existen nuevas relaciones con productos; revisar antes de eliminar.';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_catalog.pg_constraint c
      WHERE c.contype = 'f'
        AND c.confrelid = 'public.productos'::pg_catalog.regclass
        AND c.conrelid = 'public.fotografias_producto'::pg_catalog.regclass
        AND c.confdeltype = 'c'
    ) THEN
      RAISE EXCEPTION 'Revisar la cascada de fotografias_producto antes de eliminar.';
    END IF;
    RETURN NULL;
  END IF;

  -- Defensa adicional; las políticas de DELETE también deben exigir propiedad y rol.
  IF auth.uid() IS NULL OR OLD.id_productor::text IS DISTINCT FROM auth.uid()::text THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'No tienes permiso para eliminar este producto.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.usuarios u
    JOIN public.tipos_usuario t ON t.id_tipo_usuario = u.id_tipo_usuario
    WHERE u.id_usuario = auth.uid() AND t.nombre_tipo = 'producer'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Solo productores';
  END IF;

  SELECT count(*), coalesce(bool_and(h.id_fase_nueva = 1), false)
    INTO numero_historial, solo_preventa
  FROM public.historial_fases_producto h
  WHERE h.id_producto = OLD.id_producto;

  IF EXISTS (SELECT 1 FROM public.detalles_pedido d WHERE d.id_producto = OLD.id_producto)
     OR EXISTS (SELECT 1 FROM public.chats_negociacion c WHERE c.id_producto = OLD.id_producto)
     OR EXISTS (SELECT 1 FROM public.intereses_preventa i WHERE i.id_producto = OLD.id_producto)
     OR numero_historial <> 1 OR NOT solo_preventa
     OR OLD.id_fase_actual IS DISTINCT FROM 1
     OR NOT EXISTS (SELECT 1 FROM public.fases_comercializacion f
                    WHERE f.id_fase = 1 AND f.nombre_fase = 'Preventa') THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'Este producto tiene actividad comercial registrada. Puedes ocultarlo para que deje de aparecer en el catálogo',
      DETAIL = 'AGRO_ACTIVIDAD_COMERCIAL';
  END IF;

  -- La marca expresa consentimiento, NO concede permisos: propiedad y RLS se comprueban aparte.
  -- Se acota al ID y al nombre exactos del producto y a la transacción de la RPC.
  IF pg_catalog.current_setting('agro.delete_product_id', true) IS DISTINCT FROM OLD.id_producto::text
     OR pg_catalog.current_setting('agro.delete_product_name', true) IS DISTINCT FROM pg_catalog.btrim(OLD.nombre_producto)
     OR pg_catalog.current_setting('agro.discard_initial_history', true) IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Debes confirmar el nombre y autorizar descartar el historial inicial de preventa.',
      DETAIL = 'AGRO_CONFIRMACION_REQUERIDA';
  END IF;
  RETURN OLD;
END;
$$;

REVOKE ALL ON FUNCTION public.agro_proteger_producto_antes_delete() FROM PUBLIC, anon, authenticated;

-- Las dos protecciones se aplican también a DELETE directos, antes de las cascadas.
CREATE TRIGGER agro_producto_delete_bloqueos
BEFORE DELETE ON public.productos
FOR EACH STATEMENT EXECUTE FUNCTION public.agro_proteger_producto_antes_delete();

CREATE TRIGGER agro_producto_delete_guardia
BEFORE DELETE ON public.productos
FOR EACH ROW EXECUTE FUNCTION public.agro_proteger_producto_antes_delete();

-- Propuestas nuevas para DELETE: no modificar las reglas existentes de SELECT/UPDATE.
-- La política restrictiva impide que otra política permisiva abra productos ajenos.
-- Revisar que las lecturas propias de usuarios/tipos_usuario estén autorizadas por RLS.
CREATE POLICY agro_producto_delete_propietario
ON public.productos AS PERMISSIVE FOR DELETE TO authenticated
USING (
  id_productor = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1 FROM public.usuarios u
    JOIN public.tipos_usuario t ON t.id_tipo_usuario = u.id_tipo_usuario
    WHERE u.id_usuario = (SELECT auth.uid()) AND t.nombre_tipo = 'producer'
  )
);

CREATE POLICY agro_producto_delete_limite
ON public.productos AS RESTRICTIVE FOR DELETE TO PUBLIC
USING (
  id_productor = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1 FROM public.usuarios u
    JOIN public.tipos_usuario t ON t.id_tipo_usuario = u.id_tipo_usuario
    WHERE u.id_usuario = (SELECT auth.uid()) AND t.nombre_tipo = 'producer'
  )
);

-- Lectura completa de dependencias sin exponer datos de compradores al cliente.
CREATE FUNCTION public.agro_producto_delete_estado(p_id_producto text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
SET row_security = off
AS $$
DECLARE
  producto public.productos%ROWTYPE;
  permitido boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Sesión requerida';
  END IF;
  IF (SELECT count(*) FROM pg_catalog.pg_trigger t
      WHERE t.tgrelid = 'public.productos'::regclass
        AND NOT t.tgisinternal AND t.tgenabled = 'O'
        AND t.tgfoid = 'public.agro_proteger_producto_antes_delete()'::regprocedure
        AND ((t.tgname = 'agro_producto_delete_bloqueos' AND t.tgtype = 10)
          OR (t.tgname = 'agro_producto_delete_guardia' AND t.tgtype = 11))) <> 2
     OR NOT (SELECT relrowsecurity FROM pg_catalog.pg_class
             WHERE oid = 'public.productos'::regclass) THEN
    RAISE EXCEPTION 'Protección de eliminación no instalada';
  END IF;
  SELECT * INTO producto FROM public.productos
  WHERE id_producto::text = p_id_producto AND id_productor = auth.uid();
  IF NOT FOUND OR NOT EXISTS (
    SELECT 1 FROM public.usuarios u
    JOIN public.tipos_usuario t ON t.id_tipo_usuario = u.id_tipo_usuario
    WHERE u.id_usuario = auth.uid() AND t.nombre_tipo = 'producer'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Solo el productor propietario';
  END IF;
  SELECT producto.id_fase_actual = 1
    AND EXISTS (SELECT 1 FROM public.fases_comercializacion
                WHERE id_fase = 1 AND nombre_fase = 'Preventa')
    AND NOT EXISTS (SELECT 1 FROM public.chats_negociacion WHERE id_producto = producto.id_producto)
    AND NOT EXISTS (SELECT 1 FROM public.intereses_preventa WHERE id_producto = producto.id_producto)
    AND NOT EXISTS (SELECT 1 FROM public.detalles_pedido WHERE id_producto = producto.id_producto)
    AND (SELECT count(*) = 1 AND coalesce(bool_and(id_fase_nueva = 1), false)
         FROM public.historial_fases_producto WHERE id_producto = producto.id_producto)
  INTO permitido;
  RETURN pg_catalog.jsonb_build_object('version', 1, 'allowed', coalesce(permitido, false));
END;
$$;
ALTER FUNCTION public.agro_proteger_producto_antes_delete() OWNER TO postgres;
ALTER FUNCTION public.agro_producto_delete_estado(text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.agro_producto_delete_estado(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.agro_producto_delete_estado(text) TO authenticated;
-- SECURITY INVOKER mantiene los permisos y las políticas RLS del productor autenticado.
-- El ID como texto evita asumir aquí el tipo físico de id_producto; no se interpola SQL.
CREATE FUNCTION public.agro_eliminar_producto_definitivo(
  p_id_producto text,
  p_nombre_confirmacion text,
  p_descartar_historial_inicial boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
SET lock_timeout = '3s'
AS $$
DECLARE
  eliminado text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Inicia sesión como productor.';
  END IF;
  IF p_descartar_historial_inicial IS DISTINCT FROM true
     OR coalesce(pg_catalog.btrim(p_nombre_confirmacion), '') = '' THEN
    RAISE EXCEPTION 'Debes autorizar el descarte del historial inicial y escribir el nombre.';
  END IF;

  -- Volver a verificar en la misma transacción; el trigger comprueba bajo bloqueos.
  IF (public.agro_producto_delete_estado(p_id_producto)->>'allowed') IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'Eliminación bloqueada. Puedes utilizar Ocultar producto.';
  END IF;
  PERFORM pg_catalog.set_config('agro.delete_product_id', p_id_producto, true);
  PERFORM pg_catalog.set_config('agro.delete_product_name', pg_catalog.btrim(p_nombre_confirmacion), true);
  PERFORM pg_catalog.set_config('agro.discard_initial_history', 'true', true);

  DELETE FROM public.productos
  WHERE id_producto::text = p_id_producto
    AND id_productor = (SELECT auth.uid())
    AND pg_catalog.btrim(nombre_producto) = pg_catalog.btrim(p_nombre_confirmacion)
  RETURNING id_producto::text INTO eliminado;

  -- Retirar el consentimiento incluso si se ejecutan otras operaciones en esta transacción.
  PERFORM pg_catalog.set_config('agro.delete_product_id', '', true);
  PERFORM pg_catalog.set_config('agro.delete_product_name', '', true);
  PERFORM pg_catalog.set_config('agro.discard_initial_history', '', true);

  -- RETURNING prueba que se eliminó una fila: una lista vacía por RLS no cuenta como éxito.
  IF eliminado IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'No se pudo eliminar: revisa el nombre, la propiedad y los permisos del producto.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.productos WHERE id_producto::text = eliminado) THEN
    RAISE EXCEPTION 'No se pudo confirmar la eliminación del producto.';
  END IF;

  RETURN pg_catalog.jsonb_build_object('deleted', true, 'id_producto', eliminado);
END;
$$;

REVOKE ALL ON FUNCTION public.agro_eliminar_producto_definitivo(text, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.agro_eliminar_producto_definitivo(text, text, boolean) TO authenticated;
-- La RPC invocadora necesita privilegios de tabla además de políticas restrictivas.
GRANT SELECT, DELETE ON TABLE public.productos TO authenticated;

COMMIT;

-- NO se ejecutan llamadas a la RPC ni DELETE de prueba en este archivo.
-- La cascada elimina fotografías de la base y el único historial inicial autorizado.
-- Los archivos de Cloudinary requieren limpieza separada desde un backend seguro.
-- No se crea ninguna conexión desde Flutter con credenciales privadas.