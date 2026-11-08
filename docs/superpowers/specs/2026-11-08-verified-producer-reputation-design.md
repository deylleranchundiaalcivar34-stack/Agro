# Propuesta: pedidos completados y reputación verificada

## Para revisar antes de cambiar pedidos o Supabase

Esta propuesta acompaña el perfil público de productor. **No contiene una migración y no cambia la base de datos.** Su objetivo es acordar una regla verificable antes de habilitar estrellas.

## Estado encontrado

- Agro+ muestra pedidos guardados, pero el código actual solo los consulta; todavía no crea pedidos ni permite avanzar su estado.
- La tabla `pedidos` tiene `estado_pedido` como texto libre, sin una lista restringida de estados.
- No existe una tabla de reseñas ni una forma persistida de confirmar que una entrega fue recibida.
- Por ahora el perfil público informa que las reseñas todavía no están habilitadas.

## Flujo mínimo propuesto

1. **Pendiente:** el comprador genera un pedido dentro de Agro+.
2. **Aceptado:** el productor acepta el pedido.
3. **Entregado por el productor:** el productor indica que entregó el producto o que se realizó la entrega acordada.
4. **Completado:** el comprador confirma que recibió el pedido. Solo entonces puede dejar una reseña.
5. **Cancelado:** comprador o productor cancela antes de la entrega, según las reglas que se acuerden. Un pedido cancelado nunca permite reseña.
6. **En revisión:** si el comprador no confirma o reporta un problema, el pedido queda sin reseña hasta que se resuelva. Esta etapa requiere decidir quién atiende el caso.

No incluye cobros, comisiones ni seguimiento GPS.

## Reglas de reputación propuestas

- Solo el comprador asociado al pedido completado puede calificar al productor de ese pedido.
- Una reseña por pedido, con puntuación entera de 1 a 5.
- El productor no puede calificar su propio pedido.
- El promedio y el total se calculan únicamente a partir de reseñas válidas.
- El perfil público muestra promedio y cantidad; no muestra correo, identidad del comprador ni datos del pedido.
- Si un productor no tiene reseñas verificadas, el perfil muestra «Aún sin reseñas verificadas» en vez de cero estrellas.

## Seguridad que deberá cubrir la implementación

- El servidor valida los cambios de estado y quién los puede hacer; no se confía en un estado enviado por el cliente Flutter.
- RLS mantiene la lectura del pedido restringida al comprador y al productor participantes.
- La escritura de reseñas comprueba en base de datos que el pedido está completado, que la persona es su comprador y que aún no existe una reseña para ese pedido.
- La consulta pública solo entrega el agregado mínimo necesario para el perfil.
- No se aplicará DDL ni se alterará `estado_pedido` hasta aprobar esta propuesta y preparar su plan técnico con migración y políticas RLS.

## Decisiones pendientes del usuario

1. ¿Te parece bien que el productor marque la entrega y que solo el comprador confirme la recepción para habilitar su calificación?
2. Si el comprador reporta un problema, ¿quieres dejar la reseña bloqueada hasta que una persona administradora resuelva el caso?
3. ¿La reseña será solo una puntuación con estrellas o también permitirá escribir un comentario?

## Fuera de alcance de esta propuesta

- Crear flujo de pago o checkout.
- Cambiar el perfil, el chat, el mapa, la autenticación o las pantallas globales.
- Activar calificaciones antes de que el flujo de pedidos exista y se haya verificado.
