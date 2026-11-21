const show = (id) => document.getElementById(id).classList.remove('hidden');
const hide = (id) => document.getElementById(id).classList.add('hidden');

function showState(state) {
  for (const id of ['cargando', 'exito', 'error']) hide(id);
  show(state);
}

function removeCallbackFromAddressBar() {
  window.history.replaceState({}, document.title, window.location.pathname);
}

function failConfirmation() {
  showState('error');
}

async function confirmEmail() {
  const query = new URLSearchParams(window.location.search);
  const fragment = new URLSearchParams(window.location.hash.slice(1));
  const callback = {
    error: query.has('error') || fragment.has('error') || query.has('error_code') || fragment.has('error_code'),
    code: query.get('code'),
    tokenHash: query.get('token_hash'),
    type: query.get('type') ?? fragment.get('type'),
    accessToken: fragment.get('access_token'),
    refreshToken: fragment.get('refresh_token'),
  };

  if (callback.error) {
    removeCallbackFromAddressBar();
    failConfirmation();
    return;
  }

  if (callback.code || (callback.accessToken && callback.refreshToken)) {
    // Supabase redirects here with a code or session tokens only after validating its email link.
    removeCallbackFromAddressBar();
    showState('exito');
    return;
  }

  if (!callback.tokenHash || !['signup', 'email'].includes(callback.type)) {
    removeCallbackFromAddressBar();
    failConfirmation();
    return;
  }

  removeCallbackFromAddressBar();
  try {
    const { createClient } = await import('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm');
    const response = await fetch('/api/config', { cache: 'no-store' });
    const config = await response.json();
    if (!response.ok || !config.url || !config.anonKey) throw new Error('Supabase no está configurado.');

    const supabase = createClient(config.url, config.anonKey, {
      auth: { flowType: 'pkce', detectSessionInUrl: false, persistSession: false },
    });
    const { data, error } = await supabase.auth.verifyOtp({
      token_hash: callback.tokenHash,
      type: callback.type,
    });
    if (error || !data.user) throw error ?? new Error('No se confirmó ninguna cuenta.');
    showState('exito');
  } catch (_) {
    failConfirmation();
  }
}

confirmEmail();
