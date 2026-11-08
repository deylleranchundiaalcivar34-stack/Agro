# Diseño: Bienvenida marketplace de Agro+

> **Estado:** Concepto aprobado por el usuario; el plan de implementación queda pendiente de revisión.

## Objetivo

Dar a todas las personas una primera impresión cálida y propia de un marketplace agrícola, explicando brevemente para qué sirve Agro+ y ofreciendo acceso directo al inicio de sesión, registro y entrada administrativa.

## Experiencia

- Las personas sin sesión llegan a la bienvenida: logotipo existente, una frase que se puede recorrer manualmente y tres acciones: **Iniciar sesión**, **Crear cuenta** y **Acceso administrativo**.
- La ruta inicial de `AgroApp` es la bienvenida, pero el router lleva una sesión activa directamente a Inicio y una sesión con TOTP pendiente al desafío MFA.
- Los mensajes describen funciones existentes de la app:
  1. «Publica tus cosechas y conecta con compradores.»
  2. «Explora productos de productores agrícolas.»
  3. «Descubre zonas públicas y conversa por chat.»
- Las frases se recorren deslizando horizontalmente o tocando sus indicadores. No rotan automáticamente.
- **Iniciar sesión** abre el login normal. **Crear cuenta** abre el registro actual. El acceso administrativo abre el login actual con `mode=admin`.
- La navegación Atrás permite regresar a la bienvenida.
- Una sesión con TOTP pendiente no muestra la bienvenida ni puede abrir rutas protegidas antes de completar el desafío.
- Si la sesión ya está autenticada, las rutas actuales de login/registro conservan su comportamiento de llevar a Inicio.

## Dirección visual y movimiento

- Usar un fondo verde de pantalla completa, con gradiente y formas decorativas suaves; no mostrar una tarjeta o contenedor blanco alrededor del contenido principal.
- Reutilizar el logotipo y colores de `AppColors`. El logotipo puede conservar un soporte circular pequeño para que contraste con el fondo.
- Mostrar las frases sobre el fondo sin una tarjeta, con indicadores de página accesibles y tamaño legible.
- Ubicar **Iniciar sesión** y **Crear cuenta** juntos en una fila, con fondos claros y texto verde oscuro. Dejar el acceso administrativo como enlace debajo.
- No añadir paquetes, video, imágenes remotas ni servicios externos.
- En dispositivos con movimiento reducido, evitar animaciones decorativas; el cambio manual entre páginas debe seguir funcionando.
- Mantener el contenido desplazable y las acciones alcanzables en móviles pequeños y con texto ampliado.

## Límites

- Mantener correo/contraseña, recuperación de acceso, CAPTCHA excluido, MFA/TOTP y validación de roles como están.
- No añadir Google, biometría, permisos, datos ni cambios de Supabase.
- Las pantallas existentes de inicio de sesión y registro conservan sus formularios; solo se ajusta el retorno a la bienvenida cuando se entra desde ella.
