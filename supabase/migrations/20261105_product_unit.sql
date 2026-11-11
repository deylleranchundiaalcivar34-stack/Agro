-- PROPUESTA: no ejecutada. Revisar primero el esquema y obtener confirmación.
-- Comprobar columnas y relaciones existentes antes de aplicar este archivo.
-- No se asigna una unidad por defecto ni se actualizan productos antiguos.
BEGIN;
ALTER TABLE public.productos ADD COLUMN unidad_medida text NULL;
ALTER TABLE public.productos
  ADD CONSTRAINT productos_unidad_medida_allowed
    CHECK (unidad_medida IS NULL OR unidad_medida IN ('kg', 'lb', 'unidad')),
  ADD CONSTRAINT productos_unidad_medida_integer_quantity
    CHECK (unidad_medida IS DISTINCT FROM 'unidad'
           OR cantidad_disponible = trunc(cantidad_disponible));
COMMENT ON COLUMN public.productos.unidad_medida IS
  'Unidad comercial explícita: kg, lb o unidad. NULL en registros históricos sin clasificar.';
COMMIT;
