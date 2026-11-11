export function resolveRecoveryCallback(params) {
  const tokenHash = params.get('token_hash');
  if (tokenHash) {
    return params.get('type') === 'recovery'
      ? { kind: 'token_hash', tokenHash }
      : { kind: 'invalid' };
  }

  const code = params.get('code');
  if (code) return { kind: 'pkce', code };
  if (params.has('error') || params.has('error_code')) return { kind: 'invalid' };

  return null;
}
