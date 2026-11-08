import assert from 'node:assert/strict';
import test from 'node:test';

import { resolveRecoveryCallback } from '../vercel-reset-password/recovery-callback.mjs';

test('keeps recovery token hash pending until the user confirms it', () => {
  const callback = resolveRecoveryCallback(
    new URLSearchParams('token_hash=sample-hash&type=recovery'),
  );

  assert.deepEqual(callback, { kind: 'token_hash', tokenHash: 'sample-hash' });
});

test('preserves compatibility with existing PKCE recovery emails', () => {
  const callback = resolveRecoveryCallback(new URLSearchParams('code=sample-code'));

  assert.deepEqual(callback, { kind: 'pkce', code: 'sample-code' });
});

test('rejects token hashes for unrelated auth actions', () => {
  const callback = resolveRecoveryCallback(
    new URLSearchParams('token_hash=sample-hash&type=signup'),
  );

  assert.deepEqual(callback, { kind: 'invalid' });
});

test('returns null when the URL has no auth callback', () => {
  assert.equal(resolveRecoveryCallback(new URLSearchParams('')), null);
});
