import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
import { resolveRecoveryCallback } from './recovery-callback.mjs';

const show = (id) => document.getElementById(id).classList.remove('hidden');
const hide = (id) => document.getElementById(id).classList.add('hidden');

const formularioCorreo = document.getElementById('formularioCorreo');
const formulario = document.getElementById('formulario');
const errorTitulo = document.getElementById('errorTitulo');
const errorTexto = document.getElementById('errorTexto');
const aviso = document.getElementById('aviso');
const botonCorreo = document.getElementById('botonCorreo');
const botonPassword = document.getElementById('boton');
const botonConfirmar = document.getElementById('botonConfirmar');
let tokenHashRecovery = null;
let supabase = null;

function mostrarAviso(texto, tipo = 'error') {
  aviso.textContent = texto;
  aviso.className = `mt-4 rounded-xl px-4 py-3 text-sm ${tipo === 'error' ? 'bg-red-50 text-red-700' : 'bg-emerald-50 text-emerald-700'}`;
}

function esconderVistas() {
  for (const id of ['cargando', 'solicitud', 'correoEnviado', 'formulario', 'exito', 'error']) {
    hide(id);
  }
  hide('aviso');
}

function mostrarError(titulo, mensaje) {
  esconderVistas();
  errorTitulo.textContent = titulo;
  errorTexto.textContent = mensaje;
  show('error');
}

function limpiarCallbackDeUrl() {
  window.history.replaceState({}, document.title, window.location.pathname);
}

function hayCallbackDeAuth() {
  const query = new URLSearchParams(window.location.search);
  const fragment = new URLSearchParams(window.location.hash.slice(1));
  return resolveRecoveryCallback(query) !== null ||
    fragment.has('access_token') || fragment.has('error') || fragment.has('error_code');
}

function passwordIsStrong(value) {
  return value.length >= 8 && /[A-Z]/.test(value) && /[a-z]/.test(value) &&
    /[0-9]/.test(value) && /[^A-Za-z0-9]/.test(value);
}

document.getElementById('reiniciarDesdeError').addEventListener('click', () => {
  hide('error');
  hide('correoEnviado');
  show('solicitud');
});

document.getElementById('reintentarCorreo').addEventListener('click', () => {
  hide('correoEnviado');
  show('solicitud');
});

botonConfirmar.addEventListener('click', async () => {
  if (!tokenHashRecovery) return;

  botonConfirmar.disabled = true;
  botonConfirmar.textContent = 'Validando...';
  hide('aviso');
  try {
    const { data, error: verifyError } = await supabase.auth.verifyOtp({
      token_hash: tokenHashRecovery,
      type: 'recovery',
    });
    if (verifyError || !data.session) throw verifyError ?? new Error('No se obtuvo una sesion.');

    tokenHashRecovery = null;
    esconderVistas();
    show('formulario');
  } catch (_) {
    tokenHashRecovery = null;
    limpiarCallbackDeUrl();
    mostrarError(
      'El enlace no se pudo validar',
      'Puede haber vencido o ya haberse usado. Inicia una nueva solicitud desde esta pagina y vuelve a intentarlo.',
    );
  } finally {
    botonConfirmar.disabled = false;
    botonConfirmar.textContent = 'Validar enlace y continuar';
  }
});

async function iniciar() {
  try {
    const respuesta = await fetch('/api/config', { cache: 'no-store' });
    const config = await respuesta.json();
    if (!respuesta.ok || !config.url || !config.anonKey) {
      throw new Error('No se pudo cargar la configuración de recuperación. Intenta más tarde.');
    }

    supabase = createClient(config.url, config.anonKey, {
      auth: {
        flowType: 'pkce',
        detectSessionInUrl: false,
        persistSession: true,
      },
    });

    formularioCorreo.addEventListener('submit', async (event) => {
      event.preventDefault();
      const email = document.getElementById('correo').value.trim();
      if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        mostrarAviso('Escribe un correo electrónico válido.');
        return;
      }

      botonCorreo.disabled = true;
      botonCorreo.textContent = 'Enviando...';
      hide('aviso');
      try {
        const { error: requestError } = await supabase.auth.resetPasswordForEmail(email, {
          redirectTo: window.location.origin,
        });
        if (requestError) throw requestError;
        hide('solicitud');
        show('correoEnviado');
      } catch (_) {
        mostrarAviso('No se pudo enviar la solicitud. Revisa tu conexión e intenta de nuevo.');
      } finally {
        botonCorreo.disabled = false;
        botonCorreo.textContent = 'Enviar enlace de recuperación';
      }
    });

    formulario.addEventListener('submit', async (event) => {
      event.preventDefault();
      const password = document.getElementById('contrasena').value;
      const confirm = document.getElementById('confirmar').value;
      if (!passwordIsStrong(password)) {
        return mostrarAviso('Usa 8 caracteres como mínimo, con mayúscula, minúscula, número y símbolo.');
      }
      if (password !== confirm) return mostrarAviso('Las contraseñas no coinciden.');

      botonPassword.disabled = true;
      botonPassword.textContent = 'Guardando...';
      hide('aviso');
      try {
        const { error: updateError } = await supabase.auth.updateUser({ password });
        if (updateError) throw updateError;
        try {
          await supabase.auth.signOut();
        } catch (_) {
          // El cambio de contraseña ya quedó guardado; el cierre solo limpia la sesión local.
        }
        esconderVistas();
        show('exito');
      } catch (_) {
        mostrarAviso('No se pudo actualizar la contraseña. Solicita un enlace nuevo e intenta otra vez.');
      } finally {
        botonPassword.disabled = false;
        botonPassword.textContent = 'Guardar contraseña';
      }
    });

    if (hayCallbackDeAuth()) {
      const callback = resolveRecoveryCallback(new URLSearchParams(window.location.search));
      if (callback?.kind === 'token_hash') {
        tokenHashRecovery = callback.tokenHash;
        limpiarCallbackDeUrl();
        esconderVistas();
        show('confirmarEnlace');
        return;
      }
      if (callback?.kind === 'invalid') {
        limpiarCallbackDeUrl();
        mostrarError(
          'El enlace no se pudo validar',
          'Puede haber vencido o ya haberse usado. Inicia una nueva solicitud desde esta pagina y vuelve a intentarlo.',
        );
        return;
      }

      const code = callback?.kind === 'pkce' ? callback.code : null;
      let session = null;
      try {
        if (code) {
          const { data, error: exchangeError } = await supabase.auth.exchangeCodeForSession(code);
          if (!exchangeError) session = data.session;
        }
      } catch (_) {
        // El mensaje de abajo no expone el código ni detalles del intercambio.
      }
      limpiarCallbackDeUrl();
      if (!session) {
        mostrarError(
          'El enlace no se pudo validar',
          'Puede haber vencido, haberse usado o haberse abierto en otro navegador. Inicia una nueva solicitud desde esta página y abre el correo en el mismo navegador.',
        );
        return;
      }

      esconderVistas();
      show('formulario');
      return;
    }

    esconderVistas();
    show('solicitud');
  } catch (_) {
    mostrarError(
      'No se pudo abrir la recuperación',
      'No logramos conectar con el servicio de recuperación. Intenta de nuevo más tarde.',
    );
  }
}

iniciar();
