# Frases automáticas de bienvenida — Agro+

## Intención

Mantener las tres frases de bienvenida fáciles de explorar, permitiendo que avancen automáticamente sin quitarle al usuario el control táctil.

## Diseño elegido

- La frase avanza cada 5 segundos, con transición horizontal suave.
- El usuario conserva el gesto de deslizar y puede seleccionar cualquier frase tocando su indicador.
- Una interacción manual reinicia el temporizador; la siguiente frase automática aparece 5 segundos después de esa interacción.
- Al llegar a la última frase, el carrusel vuelve a la primera.
- Si `MediaQuery.disableAnimations` está activo, se desactiva el avance automático y las frases quedan bajo control manual. El gesto y los indicadores siguen funcionando.
- El temporizador se pausa cuando la app pasa a segundo plano y se reinicia al regresar.
- No cambian el diseño visual, los textos, el splash, los botones ni las rutas de bienvenida.

## Enfoques considerados

1. **Solo navegación manual (actual):** control completo, pero las frases no se descubren sin deslizar.
2. **Avance automático cada 5 segundos con controles manuales y pausa después de cada interacción (elegido):** conserva el gesto y presenta las tres frases sin pedir una acción; el temporizador no compite con el usuario.
3. **Avance automático continuo sin pausa manual:** requiere menos estado, pero puede cambiar la frase mientras el usuario está leyendo o tocando.

## Alcance y verificación

Actualizar el carrusel existente en `WelcomeView`; no añadir paquetes. Cubrir con pruebas el avance automático, el reinicio del temporizador al deslizar o elegir un indicador, el ciclo de la última a la primera frase, la pausa al entrar en segundo plano y el modo manual con movimiento reducido. Mantener las pruebas de rutas y accesibilidad existentes.
