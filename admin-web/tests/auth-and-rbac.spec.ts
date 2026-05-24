import { expect, test, type Page, type Response } from '@playwright/test';
import {
  createAdminWithPermissions,
  revokeRefreshToken,
  sessionStorageKey,
  type AdminSessionFixture,
} from './helpers/admin-api';

const E2E_RESPONSE_TIMEOUT_MS = Number(process.env['BABY_TALK_PLAYWRIGHT_RESPONSE_TIMEOUT_MS'] ?? 10_000);
const E2E_POLL_TIMEOUT_MS = Number(process.env['BABY_TALK_PLAYWRIGHT_POLL_TIMEOUT_MS'] ?? 15_000);

type StoredAdminSession = {
  admin: AdminSessionFixture['admin'];
  accessToken?: string;
  refreshToken?: string;
  tokenType?: string;
  accessTokenExpiresAt?: string;
  refreshTokenExpiresAt?: string;
};

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
      { timeout: E2E_RESPONSE_TIMEOUT_MS },
    );

    await page.getByLabel('用户名').fill('super_admin');
    await page.getByLabel('密码').fill('WrongPassword123!');
    await page.getByTestId('login-submit').click();

    expect((await failedLogin).status()).toBe(401);
    await expect(page).toHaveURL(/\/login$/);
    await expect(page.getByTestId('login-error')).toContainText('用户名或密码错误');
    await expect(page.getByTestId('login-error')).toContainText('invalid_admin_credentials');
  });

  test('lands super admins on overview control plane', async ({ page }) => {
    await loginViaUi(page, { expectedUrl: /\/overview$/ });
    const domainCards = page.locator('[data-testid^="overview-domain-card-"]');

    await expect(page.getByTestId('protected-shell')).toBeVisible();
    await expect(page.getByTestId('overview-page')).toBeVisible();
    await expect(page.getByTestId('overview-control-strip')).toBeVisible();
    await expect(domainCards.first()).toBeVisible();
    await expect(page).toHaveURL(/\/overview(?:\?.*)?$/);
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

    await page.goto('/overview');

    await expect(page).toHaveURL(/\/403\?from=%2Foverview/);
    await expect(page.getByTestId('forbidden-page')).toBeVisible();
    await expect(page.getByTestId('forbidden-query')).toContainText('routeKey=overview');
    await expect(page.getByTestId('forbidden-query')).toContainText('required=rag%3Aread%2Ckg%3Aread%2Cmentor%3Aaudit%2Cdistribution%3Aread');
    await expect(page.getByTestId('workspace-link-users')).toBeVisible();
    await expect(page.getByTestId('workspace-link-overview')).toHaveCount(0);

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
    expect(originalSession.accessToken, 'stored session must expose accessToken for stale-token proof').toBeTruthy();
    expect(originalSession.refreshToken, 'stored session must expose refreshToken for stale-token proof').toBeTruthy();
    const staleSourceToken = originalSession.accessToken;
    const previousRefreshToken = originalSession.refreshToken;
    if (!staleSourceToken || !previousRefreshToken) {
      throw new Error('stored session is missing required tokens for stale-token proof.');
    }

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
      await expect.poll(() => meTracker.statuses.slice(0, 2).join(','), { timeout: E2E_POLL_TIMEOUT_MS }).toBe('401,200');
      await expect.poll(() => meTracker.statuses.filter((status) => status === 401).length, { timeout: E2E_POLL_TIMEOUT_MS }).toBe(1);
      await expect.poll(() => refreshTracker.statuses.join(','), { timeout: E2E_POLL_TIMEOUT_MS }).toBe('200');

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
          previousRefreshToken,
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
    const refreshToken = session.refreshToken;
    expect(refreshToken, 'stored session must expose refreshToken for revoke proof').toBeTruthy();
    if (!refreshToken) {
      throw new Error('stored session is missing refreshToken for revoke proof.');
    }
    await revokeRefreshToken(request, refreshToken);

    const meTracker = trackEndpointResponses(page, '/api/admin/me', 'GET');
    const refreshTracker = trackEndpointResponses(page, '/api/admin/auth/refresh', 'POST');

    try {
      await page.goto('/mentor/audits?flag=blocked_fallback');

      await expect(page).toHaveURL(/\/login\?returnTo=%2Fmentor%2Faudits%3Fflag%3Dblocked_fallback$/);
      await expect(page.getByTestId('login-banner')).toContainText('refresh token 已失效，请重新登录。');
      await expect(page.getByTestId('login-banner')).toContainText('refresh_token_revoked');
      await expect(page.getByTestId('login-return-to')).toContainText('/mentor/audits?flag=blocked_fallback');
      await expect.poll(() => meTracker.statuses.join(','), { timeout: E2E_POLL_TIMEOUT_MS }).toBe('401');
      await expect.poll(() => refreshTracker.statuses.join(','), { timeout: E2E_POLL_TIMEOUT_MS }).toBe('401');
      await expect.poll(() => readStoredSessionPresence(page), { timeout: E2E_POLL_TIMEOUT_MS }).toBe(false);
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
    await expect.poll(() => readStoredSessionPresence(page), { timeout: E2E_POLL_TIMEOUT_MS }).toBe(false);
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

  for (let attempt = 0; attempt < 3; attempt += 1) {
    await page.goto('/login');

    const loginResponse = page.waitForResponse(
      (response) => exactApiPath(response, '/api/admin/auth/login') && response.request().method() === 'POST',
      { timeout: E2E_RESPONSE_TIMEOUT_MS },
    );
    const meResponse = page
      .waitForResponse(
        (response) => exactApiPath(response, '/api/admin/me') && response.request().method() === 'GET',
        { timeout: E2E_RESPONSE_TIMEOUT_MS },
      )
      .catch(() => null);

    await page.getByLabel('用户名').fill(username);
    await page.getByLabel('密码').fill(password);
    await page.getByTestId('login-submit').click();

    expect((await loginResponse).status()).toBe(200);
    const me = await meResponse;
    if (me?.status() === 401 && attempt < 2) {
      const loginBanner = page.getByTestId('login-banner');
      const loginBannerText = (await loginBanner.count()) > 0 ? (await loginBanner.textContent()) ?? '' : '';
      if (loginBannerText.includes('admin_session_invalid')) {
        await page.context().clearCookies();
        await page.evaluate((storageKey) => {
          window.localStorage.removeItem(storageKey);
          window.sessionStorage.clear();
        }, sessionStorageKey);
        continue;
      }
    }
    if (me) {
      expect(me.status()).toBe(200);
    }

    try {
      await expect(page).toHaveURL(options.expectedUrl);
      await expect(page.getByTestId('protected-shell')).toBeVisible();
      return;
    } catch (error) {
      const loginBanner = page.getByTestId('login-banner');
      if (attempt < 2 && (await loginBanner.count()) > 0) {
        await expect(loginBanner).toContainText('admin_session_invalid');
        await page.context().clearCookies();
        await page.evaluate((storageKey) => {
          window.localStorage.removeItem(storageKey);
          window.sessionStorage.clear();
        }, sessionStorageKey);
        continue;
      }
      throw error;
    }
  }
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

async function readStoredSession(page: Page): Promise<StoredAdminSession> {
  const payload = await page.evaluate((storageKey) => window.localStorage.getItem(storageKey), sessionStorageKey);
  if (!payload) {
    throw new Error('Expected babytalk.admin.session to exist, but it was empty.');
  }
  const parsed = JSON.parse(payload) as Partial<StoredAdminSession>;
  if (!parsed || typeof parsed !== 'object' || !parsed.admin || typeof parsed.admin !== 'object') {
    throw new Error('Expected babytalk.admin.session to contain an admin payload.');
  }
  return parsed as StoredAdminSession;
}

async function readStoredSessionPresence(page: Page): Promise<boolean> {
  return await page.evaluate((storageKey) => window.localStorage.getItem(storageKey) !== null, sessionStorageKey);
}

async function writeStoredSession(page: Page, session: StoredAdminSession) {
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
