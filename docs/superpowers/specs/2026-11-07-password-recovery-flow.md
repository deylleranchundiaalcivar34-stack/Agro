# Recuperación de contraseña desde el mismo navegador

## Intención

Permitir que compradores y productores recuperen su contraseña desde la app sin que el intercambio PKCE se rompa al abrir el correo en la web de Vercel. La solicitud de recuperación debe comenzar en esa misma web para que el navegador guarde el verificador que Supabase necesita cuando regresa el enlace.

## Estado observado

- Flutter solicita actualmente el correo a Supabase Auth y envía el usuario a `https://agroplus-recuperar.vercel.app`.
- La app Flutter usa el flujo PKCE por defecto de `supabase_flutter`.
- La web de recuperación crea una sesión de Supabase en otro contexto y no tiene el verificador que guardó el cliente Flutter. Recibe `?code=...`, pero no obtiene una sesión.
- El endpoint de configuración de Vercel ya responde HTTP 200 y encuentra `SUPABASE_URL` y `SUPABASE_ANON_KEY`.

## Objetivo

Iniciar `resetPasswordForEmail` desde la página de Vercel y procesar el retorno en el mismo origen y navegador. El usuario vuelve desde el correo a esa web, define su contraseña nueva y después regresa a Agro+.

## Alcance

- Agregar a la web una pantalla para ingresar el correo y solicitar el enlace.
- Hacer que la pantalla de recuperación de Flutter abra la web; no incluir el correo en la URL.
- Mantener el PKCE actual del login y los demás flujos de Auth.
- Igualar los requisitos de contraseña de la web con Flutter: 8 caracteres, mayúscula, minúscula, número y símbolo.
- Mostrar un mensaje genérico al pedir el correo para no revelar si una cuenta existe.
- Limpiar parámetros de autenticación de la barra de direcciones después de completar el intercambio de sesión.
- Desplegar el sitio de recuperación actualizado y verificar el flujo de extremo a extremo.

## Fuera de alcance

- Cambiar login, registro, CAPTCHA, Google, MFA/TOTP, RLS o tablas de Supabase.
- Cambiar la plantilla de correo de recuperación de Supabase.
- Usar claves secretas o `service_role` en Flutter o en el navegador.
- Cambiar Cloudinary, mapa o chat.

## Alternativas consideradas

1. **Empezar la recuperación en Vercel (recomendada):** conserva PKCE y la plantilla de correo existente. Requiere que la app abra la página y que la solicitud y el retorno usen el mismo navegador.
2. **Cambiar la plantilla de recuperación para usar `TokenHash`:** puede aceptar el enlace desde distintos navegadores, pero obliga a cambiar y mantener la plantilla Auth de Supabase además del código web.
3. **Cambiar globalmente el flujo de Auth a implicit:** reduce el aislamiento del cambio y afecta registro y otros redireccionamientos; se descarta.

## Experiencia esperada

1. En Agro+, el usuario toca «Olvidé mi contraseña» y abre la página segura de recuperación.
2. En esa página ingresa el correo y solicita el enlace. Se muestra una confirmación genérica.
3. Abre el enlace de correo en el mismo navegador donde inició la solicitud.
4. La página verifica la sesión de recuperación y muestra el formulario de contraseña nueva.
5. La página confirma el cambio y ofrece volver a Agro+.

Si el enlace está vencido, ya se usó o se abrió en otro navegador que no tiene el verificador, se presenta una acción clara para reiniciar el flujo desde la web.

## Seguridad y privacidad

- Usar solamente `SUPABASE_URL` y `SUPABASE_ANON_KEY` públicas ya configuradas en Vercel.
- No pasar correo ni credenciales por query parameters.
- No registrar el código PKCE, tokens, contraseña ni el cuerpo de respuestas sensibles.
- Usar los enlaces de un solo uso una sola vez y limpiar la URL cuando la sesión quede establecida.

## Aprobación

Alcance aprobado por el usuario el 2026-11-07. No se cambia la configuración de Supabase para este flujo.
