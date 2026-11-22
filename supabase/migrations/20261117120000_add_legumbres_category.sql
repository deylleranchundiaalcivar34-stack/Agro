-- Registra Legumbres en el catalogo que comparten Inicio, filtros y formularios.
INSERT INTO public.categorias_agricolas (nombre_categoria)
SELECT 'Legumbres'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.categorias_agricolas
  WHERE lower(trim(nombre_categoria)) = lower('Legumbres')
);
