import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

const show = (id) => document.getElementById(id).classList.remove('hidden');
const hide = (id) => document.getElementById(id).classList.add('hidden');
const errorText = document.getElementById('errorTexto');
const notice = document.getElementById('aviso');

function mostrarAviso(texto, tipo = 'error') {
  notice.textContent = texto;
  notice.className = `mt-4 rounded-xl px-4 py-3 text-sm ${tipo === 'error' ? 'bg-red-50 text-red-700' : 'bg-emerald-50 text-emerald-700'}`;
}

async function iniciar() {
  try {
    const respuesta = await fetch('/api/config');
    const config = await respuesta.json();
    if (!respuesta.ok || !config.url || !config.anonKey) throw new Error('La pagina aun no esta configurada.');

    const supabase = createClient(config.url, config.anonKey);
    const { data, error } = await supabase.auth.getSession();
    if (error || !data.session) throw new Error('Este enlace ya no es valido o ya vencio.');

    hide('cargando');
    show('formulario');
    document.getElementById('formulario').addEventListener('submit', async (event) => {
      event.preventDefault();
      const password = document.getElementById('contrasena').value;
      const confirm = document.getElementById('confirmar').value;
      if (password.length < 6) return mostrarAviso('La contrasena debe tener al menos 6 caracteres.');
      if (password !== confirm) return mostrarAviso('Las contrasenas no coinciden.');

      const button = document.getElementById('boton');
      button.disabled = true;
      button.textContent = 'Guardando...';
      const { error: updateError } = await supabase.auth.updateUser({ password });
      if (updateError) {
        button.disabled = false;
        button.textContent = 'Guardar contrasena';
        return mostrarAviso(updateError.message);
      }
      await supabase.auth.signOut();
      hide('formulario');
      show('exito');
    });
  } catch (error) {
    hide('cargando');
    errorText.textContent = error.message || 'No fue posible verificar el enlace.';
    show('error');
  }
}

iniciar();
