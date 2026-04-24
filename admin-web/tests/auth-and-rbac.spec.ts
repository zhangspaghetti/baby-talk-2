import { expect, test, type Page, type Response } from '@playwright/test';
import {
  createAdminWithPermissions,
  revokeRefreshToken,
  sessionStorageKey,
  type AdminSessionFixture,
} from './helpers/admin-api';

test.describe('auth and rbac browser proof', () => {
  test('redirects unauthenticated visits to /login with visible return context', async ({ page }) => {
    await page.goto('/protected');

    await expect(page).toHaveURL(/\/login\?returnTo=%2Fprotected$/);
    await expect(page.getByRole('heading', { name: 'BabyTalk Admin 登录' })).toBeVisible();
    await expect(page.getByTestId('login-banner')).toContainText('请先登录管理员账号');
    await expect(page.getByTestId('login-banner')).toContainText('admin_authentication_required');
    await expect(page.getByTestId('login-return-to')).toContainText('/protected');
  });

  test('shows a visible error for bad credentials', async ({ page }) => {
    await page.goto('/login');

    const failedLogin = page.waitForResponse(
      (response) => exactApiPath(response, '/api/admin/auth/login') && response.request().method() === 'POST',
    );

    await page.getByLabel('用户名').fill('super_admin');
    await page.getByLabel('密码').fill('WrongPassword123!');
    await page.getByTestId('login-submit').click();

    expect((await failedLogin).status()).toBe(401);
    await expect(page).toHaveURL(/\/login$/);
    await expect(page.getByTestId('login-error')).toContainText('用户名或密码错误');
    await expect(page.getByTestId('login-error')).toContainText('invalid_admin_credentials');
  });

  test('lands super admins on overview and keeps all primary navigation visible', async ({ page }) => {
    await loginViaUi(page, { expectedUrl: /\/overview$/ });

    await expect(page.getByTestId('protected-shell')).toBeVisible();
    await expect(page.getByTestId('overview-page')).toBeVisible();
    await expect(page.getByTestId('overview-control-strip')).toBeVisible();
    await expect(page.getByTestId('overview-domain-card-knowledge_ingestion')).toBeVisible();
    await expect(page.getByTestId('session-user')).toContainText('super_admin');
    await expect(page.getByTestId('session-role')).toContainText('super_admin');
    await expect(page.getByTestId('workspace-current')).toContainText('Overview');
    await expect(page.getByTestId('workspace-link-overview')).toBeVisible();
    await expect(page.getByTestId('workspace-link-users')).toBeVisible();
    await expect(page.getByTestId('workspace-link-knowledge-ops')).toBeVisible();
    await expect(page.getByTestId('workspace-link-mentor-audit')).toBeVisible();
    await expect(page.getByTestId('workspace-link-distribution-stats')).toBeVisible();
  });

  test('lands limited admins on their single module, hides unrelated nav, and makes forbidden deep links explicit', async ({
    page,
    request,
  }) => {
    const limitedAdmin = await createAdminWithPermissions(request, ['users:read'], 'Users Reader');

    await loginViaUi(page, {
      username: limitedAdmin.username,
      password: limitedAdmin.password,
      expectedUrl: /\/users(?:\?.*)?$/,
    });

    await expect(page.getByTestId('users-page')).toBeVisible();
    await expect(page.getByTestId('session-user')).toContainText(limitedAdmin.username);
    await expect(page.getByTestId('workspace-current')).toContainText('Users');
    await expect(page.getByTestId('workspace-link-users')).toBeVisible();
    await expect(page.getByTestId('workspace-link-overview')).toHaveCount(0);
    await expect(page.getByTestId('workspace-link-knowledge-ops')).toHaveCount(0);
    await expect(page.getByTestId('workspace-link-mentor-audit')).toHaveCount(0);
    await expect(page.getByTestId('workspace-link-distribution-stats')).toHaveCount(0);

    await page.goto('/mentor/audits?flag=blocked_fallback');

    await expect(page).toHaveURL(/\/403\?from=%2Fmentor%2Faudits%3Fflag%3Dblocked_fallback/);
    await expect(page.getByTestId('forbidden-page')).toBeVisible();
    await expect(page.getByTestId('forbidden-query')).toContainText('routeKey=mentor-safety');
    await expect(page.getByTestId('forbidden-query')).toContainText('required=mentor%3Aaudit');
    await expect(page.getByTestId('forbidden-page')).toContainText(limitedAdmin.username);
    await expect(page.getByTestId('forbidden-page')).toContainText(limitedAdmin.roleCode);
    await expect(page.getByTestId('workspace-link-users')).toBeVisible();
    await expect(page.getByTestId('workspace-link-mentor-audit')).toHaveCount(0);
  });

  test('replays the original bootstrap request after exactly one refresh when the access token is stale', async ({ page }) => {
    await loginViaUi(page, { expectedUrl: /\/overview$/ });
    const originalSession = await readStoredSession(page);

    await writeStoredSession(page, {
      ...originalSession,
      accessToken: 'invalid-access-token',
    });

    const meTracker = trackEndpointResponses(page, '/api/admin/me', 'GET');
    const refreshTracker = trackEndpointResponses(page, '/api/admin/auth/refresh', 'POST');

    try {
      await page.goto('/users');

      await expect(page).toHaveURL(/\/users(?:\?.*)?$/);
      await expect(page.getByTestId('users-page')).toBeVisible();
      await expect(page.getByTestId('session-user')).toContainText('super_admin');
      await expect.poll(() => meTracker.statuses.slice(0, 2).join(',')).toBe('401,200');
      await expect.poll(() => meTracker.statuses.filter((status) => status === 401).length).toBe(1);
      await expect.poll(() => refreshTracker.statuses.join(',')).toBe('200');

      const sessionRotation = await page.evaluate(
        ({ storageKey, staleAccessToken, previousRefreshToken }) => {
          const raw = window.localStorage.getItem(storageKey);
          if (!raw) {
            return {
              present: false,
              accessRotated: false,
              refreshRotated: false,
              username: null,
              roles: [],
            };
          }

          const parsed = JSON.parse(raw) as {
            accessToken?: string;
            refreshToken?: string;
            admin?: { username?: string; roles?: string[] };
          };

          return {
            present: true,
            accessRotated: parsed.accessToken !== staleAccessToken,
            refreshRotated: parsed.refreshToken !== previousRefreshToken,
            username: parsed.admin?.username ?? null,
            roles: Array.isArray(parsed.admin?.roles) ? parsed.admin.roles : [],
          };
        },
        {
          storageKey: sessionStorageKey,
          staleAccessToken: 'invalid-access-token',
          previousRefreshToken: originalSession.refreshToken,
        },
      );

      expect(sessionRotation.present).toBe(true);
      expect(sessionRotation.accessRotated).toBe(true);
      expect(sessionRotation.refreshRotated).toBe(true);
      expect(sessionRotation.username).toBe('super_admin');
      expect(sessionRotation.roles).toContain('super_admin');
    } finally {
      meTracker.stop();
      refreshTracker.stop();
    }
  });

  test('clears the stored session and returns to /login when the refresh token has been revoked', async ({
    page,
    request,
  }) => {
    await loginViaUi(page, { expectedUrl: /\/overview$/ });
    const session = await readStoredSession(page);
    await revokeRefreshToken(request, session.refreshToken);

    const meTracker = trackEndpointResponses(page, '/api/admin/me', 'GET');
    const refreshTracker = trackEndpointResponses(page, '/api/admin/auth/refresh', 'POST');

    try {
      await page.goto('/mentor/audits?flag=blocked_fallback');

      await expect(page).toHaveURL(/\/login\?returnTo=%2Fmentor%2Faudits%3Fflag%3Dblocked_fallback$/);
      await expect(page.getByTestId('login-banner')).toContainText('refresh token 已失效，请重新登录。');
      await expect(page.getByTestId('login-banner')).toContainText('refresh_token_revoked');
      await expect(page.getByTestId('login-return-to')).toContainText('/mentor/audits?flag=blocked_fallback');
      await expect.poll(() => meTracker.statuses.join(',')).toBe('401');
      await expect.poll(() => refreshTracker.statuses.join(',')).toBe('401');
      await expect.poll(() => readStoredSessionPresence(page)).toBe(false);
    } finally {
      meTracker.stop();
      refreshTracker.stop();
    }
  });

  test('clears malformed stored session JSON before redirecting back to /login', async ({ page }) => {
    await page.goto('/login');
    await writeRawStoredSession(page, '{"accessToken":');

    await page.goto('/protected');

    await expect(page).toHaveURL(/\/login\?returnTo=%2Fprotected$/);
    await expect(page.getByTestId('login-banner')).toContainText('本地管理员会话已损坏，已清理并请重新登录。');
    await expect(page.getByTestId('login-banner')).toContainText('stored_session_reset');
    await expect(page.getByTestId('login-return-to')).toContainText('/protected');
    await expect.poll(() => readStoredSessionPresence(page)).toBe(false);
  });
});

async function loginViaUi(
  page: Page,
  options: {
    username?: string;
    password?: string;
    expectedUrl: RegExp;
  },
) {
  const username = options.username ?? 'super_admin';
  const password = options.password ?? 'SuperAdmin123!';

  await page.goto('/login');

  const loginResponse = page.waitForResponse(
    (response) => exactApiPath(response, '/api/admin/auth/login') && response.request().method() === 'POST',
  );
  const meResponse = page.waitForResponse(
    (response) => exactApiPath(response, '/api/admin/me') && response.request().method() === 'GET',
  );

  await page.getByLabel('用户名').fill(username);
  await page.getByLabel('密码').fill(password);
  await page.getByTestId('login-submit').click();

  expect((await loginResponse).status()).toBe(200);
  expect((await meResponse).status()).toBe(200);
  await expect(page).toHaveURL(options.expectedUrl);
  await expect(page.getByTestId('protected-shell')).toBeVisible();
}

function trackEndpointResponses(page: Page, pathname: string, method: string) {
  const statuses: number[] = [];
  const listener = (response: Response) => {
    if (response.request().method() !== method) {
      return;
    }
    if (exactApiPath(response, pathname)) {
      statuses.push(response.status());
    }
  };

  page.on('response', listener);

  return {
    statuses,
    stop: () => page.off('response', listener),
  };
}

function exactApiPath(response: Response, pathname: string): boolean {
  return new URL(response.url()).pathname === pathname;
}

async function readStoredSession(page: Page): Promise<AdminSessionFixture> {
  const payload = await page.evaluate((storageKey) => window.localStorage.getItem(storageKey), sessionStorageKey);
  if (!payload) {
    throw new Error('Expected babytalk.admin.session to exist, but it was empty.');
  }
  return JSON.parse(payload) as AdminSessionFixture;
}

async function readStoredSessionPresence(page: Page): Promise<boolean> {
  return await page.evaluate((storageKey) => window.localStorage.getItem(storageKey) !== null, sessionStorageKey);
}

async function writeStoredSession(page: Page, session: AdminSessionFixture) {
  await page.evaluate(
    ({ storageKey, nextSession }) => {
      window.localStorage.setItem(storageKey, JSON.stringify(nextSession));
    },
    {
      storageKey: sessionStorageKey,
      nextSession: session,
    },
  );
}

async function writeRawStoredSession(page: Page, rawSession: string) {
  await page.evaluate(
    ({ storageKey, payload }) => {
      window.localStorage.setItem(storageKey, payload);
    },
    {
      storageKey: sessionStorageKey,
      payload: rawSession,
    },
  );
}
