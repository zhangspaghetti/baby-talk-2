import { test } from '@playwright/test';

test.describe('auth and rbac shell (placeholder for S04/T05)', () => {
  test('TODO: replace this red placeholder with the canonical browser proof', async () => {
    throw new Error(
      [
        'Pending S04/T02-T05 implementation.',
        'Expected final scenarios:',
        '1. unauthenticated protected route -> /login',
        '2. super_admin login -> role-aware landing',
        '3. limited admin hidden-nav + forbidden deep link -> /403',
        '4. invalid access token -> exactly one /api/admin/auth/refresh then replay succeeds',
        '5. revoked refresh -> local session cleared and redirected to /login',
      ].join('\n'),
    );
  });
});
