import { expect, test, type APIRequestContext, type Page } from '@playwright/test';

const adminApiBaseUrl = 'http://127.0.0.1:8081';
const appApiBaseUrl = 'http://127.0.0.1:8080';
const appVersionHeader = {
  'X-App-Version': '1.2.0',
};
const sessionStorageKey = 'babytalk.admin.session';

test.describe('mentor audit workspace', () => {
  test('uses real mentor incidents, keeps queue context in URL, and shows incident-first detail states', async ({ page, request }) => {
    const suffix = uniqueSuffix();
    const installationId = `install-e2e-${suffix}`;
    const blockedCorrelationId = `corr-blocked-${suffix}`;
    const rateLimitedCorrelationId = `corr-rate-${suffix}`;

    await seedMentorRequest(request, {
      installationId,
      correlationId: `corr-success-a-${suffix}`,
      prompt: '宝宝哭了我现在该怎么说？',
    }, 200);
    await seedMentorRequest(request, {
      installationId,
      correlationId: blockedCorrelationId,
      prompt: '我想体罚他，怎么办？',
      surface: 'garden',
    }, 200);
    await seedMentorRequest(request, {
      installationId,
      correlationId: `corr-success-b-${suffix}`,
      prompt: '再给我一句睡前安抚建议',
    }, 200);
    await seedMentorRequest(request, {
      installationId,
      correlationId: rateLimitedCorrelationId,
      prompt: '第四次请求应该触发 rate limit',
    }, 429);

    await loginViaUi(page);

    const mentorPageQueue = page.waitForResponse(
      (response) => response.url().includes('/api/admin/mentor/audits') && response.request().method() === 'GET',
    );
    await page.goto('/mentor/audits');
    expect((await mentorPageQueue).status()).toBe(200);
    await expect(page.getByTestId('mentor-audit-page')).toBeVisible();

    const blockedQueueResponse = page.waitForResponse(
      (response) =>
        response.url().includes('/api/admin/mentor/audits') &&
        response.url().includes(`installationId=${encodeURIComponent(installationId)}`) &&
        response.url().includes('flag=blocked_fallback'),
    );
    await page.getByTestId('installation-filter').fill(installationId);
    await page.getByTestId('flag-filter').fill('blocked_fallback');
    await page.getByTestId('apply-filters').click();
    expect((await blockedQueueResponse).status()).toBe(200);

    await expect.poll(() => new URL(page.url()).searchParams.get('installationId')).toBe(installationId);
    await expect.poll(() => new URL(page.url()).searchParams.get('flag')).toBe('blocked_fallback');
    await expect(page.getByTestId(`queue-item-${blockedCorrelationId}`)).toBeVisible();
    await expect(page.getByTestId('mentor-audit-queue')).not.toContainText(rateLimitedCorrelationId);

    const blockedDetailResponse = page.waitForResponse(
      (response) => response.url().includes(`/api/admin/mentor/audits/${blockedCorrelationId}`),
    );
    await page.getByTestId(`open-audit-${blockedCorrelationId}`).click();
    expect((await blockedDetailResponse).status()).toBe(200);

    await expect.poll(() => new URL(page.url()).searchParams.get('selected')).toBe(blockedCorrelationId);
    await expect(page.getByText('Incident evidence only')).toBeVisible();
    await expect(page.getByTestId('request-summary')).toContainText('surface=');
    await expect(page.getByTestId('delivered-response-text')).toContainText("I'm here with you.");
    await expect(page.getByTestId('live-rate-limit-card')).toBeVisible();

    await page.getByTestId('close-detail').click();
    await expect.poll(() => new URL(page.url()).searchParams.get('selected')).toBe(null);
    await expect.poll(() => new URL(page.url()).searchParams.get('flag')).toBe('blocked_fallback');

    const rateLimitedQueueResponse = page.waitForResponse(
      (response) =>
        response.url().includes('/api/admin/mentor/audits') &&
        response.url().includes(`installationId=${encodeURIComponent(installationId)}`) &&
        response.url().includes('flag=rate_limited'),
    );
    await page.getByTestId('flag-filter').fill('rate_limited');
    await page.getByTestId('apply-filters').click();
    expect((await rateLimitedQueueResponse).status()).toBe(200);

    await expect.poll(() => new URL(page.url()).searchParams.get('flag')).toBe('rate_limited');
    await page.reload();
    await expect.poll(() => new URL(page.url()).searchParams.get('flag')).toBe('rate_limited');
    await expect(page.getByTestId('flag-filter')).toHaveValue('rate_limited');
    await expect(page.getByTestId(`queue-item-${rateLimitedCorrelationId}`)).toBeVisible();

    const rateLimitedDetailResponse = page.waitForResponse(
      (response) => response.url().includes(`/api/admin/mentor/audits/${rateLimitedCorrelationId}`),
    );
    await page.getByTestId(`open-audit-${rateLimitedCorrelationId}`).click();
    expect((await rateLimitedDetailResponse).status()).toBe(200);

    await expect(page.getByTestId('missing-delivered-response-state')).toBeVisible();
    await expect(page.getByTestId('live-rate-limit-card')).toContainText('Current count');
    await expect(page.getByTestId('live-rate-limit-card')).toContainText('Limit');
  });

  test('shows stable 403 UI when current backend permissions omit mentor:audit', async ({ page, request }) => {
    const limitedAdmin = await createLimitedAdmin(request);

    await loginViaUi(page, limitedAdmin.username, limitedAdmin.password);
    await page.goto('/mentor/audits');

    await expect(page.getByTestId('permission-denied-state')).toBeVisible();
    await expect(page.getByTestId('permission-denied-state')).toContainText('mentor:audit');
    await expect(page.getByTestId('permission-denied-state')).toContainText('forbidden');
  });

  test('clears stale local session and returns to login when /api/admin/me is 401', async ({ page }) => {
    await page.goto('/login');
    await page.evaluate((storageKey) => {
      window.localStorage.setItem(
        storageKey,
        JSON.stringify({
          accessToken: 'invalid-access-token',
          refreshToken: 'invalid-refresh-token',
          tokenType: 'Bearer',
          accessTokenExpiresAt: '2099-01-01T00:00:00Z',
          refreshTokenExpiresAt: '2099-01-02T00:00:00Z',
          admin: {
            principalId: 'admin_stale',
            username: 'super_admin',
            displayName: 'Super Admin',
            roles: ['super_admin'],
            permissions: ['mentor:audit'],
          },
        }),
      );
    }, sessionStorageKey);

    const meResponse = page.waitForResponse(
      (response) => response.url().includes('/api/admin/me') && response.request().method() === 'GET',
    );
    await page.goto('/mentor/audits?flag=blocked_fallback');
    expect((await meResponse).status()).toBe(401);

    await expect(page).toHaveURL(/\/login$/);
    await expect(page.getByTestId('login-banner')).toContainText('管理员会话已失效，请重新登录。');
    await expect(page.getByTestId('login-banner')).toContainText('admin_session_invalid');
  });

  test('shows explicit empty, missing-detail, and malformed-filter states', async ({ page }) => {
    const suffix = uniqueSuffix();
    const emptyInstallationId = `install-missing-${suffix}`;

    await loginViaUi(page);

    const detailOnlyQueueResponse = page.waitForResponse(
      (response) => response.url().includes('/api/admin/mentor/audits') && response.request().method() === 'GET',
    );
    const missingDetailResponse = page.waitForResponse(
      (response) => response.url().includes('/api/admin/mentor/audits/corr_missing_e2e'),
    );
    await page.goto('/mentor/audits?installationId=&selected=corr_missing_e2e');
    expect((await detailOnlyQueueResponse).status()).toBe(200);
    expect((await missingDetailResponse).status()).toBe(404);

    await expect(page.getByTestId('detail-error-state')).toContainText('mentor_audit_not_found');

    const emptyQueueResponse = page.waitForResponse(
      (response) =>
        response.url().includes('/api/admin/mentor/audits') &&
        response.url().includes(`installationId=${encodeURIComponent(emptyInstallationId)}`),
    );
    await page.goto(`/mentor/audits?installationId=${encodeURIComponent(emptyInstallationId)}`);
    expect((await emptyQueueResponse).status()).toBe(200);

    await expect(page.getByTestId('audit-empty-state')).toBeVisible();

    const malformedQueueResponse = page.waitForResponse(
      (response) => response.url().includes('/api/admin/mentor/audits') && response.url().includes('flag=nope'),
    );
    await page.goto('/mentor/audits?flag=nope');
    expect((await malformedQueueResponse).status()).toBe(400);

    await expect(page.getByTestId('queue-error-state')).toContainText('unknown_mentor_audit_flag');
  });
});

async function loginViaUi(page: Page, username = 'super_admin', password = 'SuperAdmin123!') {
  await page.goto('/login');

  const loginResponse = page.waitForResponse(
    (response) => response.url().includes('/api/admin/auth/login') && response.request().method() === 'POST',
  );
  const meResponse = page.waitForResponse(
    (response) => response.url().includes('/api/admin/me') && response.request().method() === 'GET',
  );

  await page.getByLabel('用户名').fill(username);
  await page.getByLabel('密码').fill(password);
  await page.getByTestId('login-submit').click();

  expect((await loginResponse).status()).toBe(200);
  expect((await meResponse).status()).toBe(200);
  await expect(page).toHaveURL(/\/overview$|\/users$|\/knowledge-ops$|\/mentor\/audits$|\/distribution\/stats(?:\?.*)?$/);
  await expect(page.getByTestId('protected-shell')).toBeVisible();
}

async function createLimitedAdmin(request: APIRequestContext) {
  const suffix = uniqueSuffix();
  const roleCode = `users_reader_${suffix}`;
  const username = `reader_${suffix}`;
  const password = 'Reader123!';
  const superAdmin = await loginViaAdminApi(request);

  const createRoleResponse = await request.post(`${adminApiBaseUrl}/api/admin/roles`, {
    headers: {
      Authorization: `Bearer ${superAdmin.accessToken}`,
      'Content-Type': 'application/json',
    },
    data: {
      roleCode,
      description: `Role ${roleCode}`,
      permissionCodes: ['users:read'],
    },
  });
  expect(createRoleResponse.status()).toBe(201);

  const createAdminResponse = await request.post(`${adminApiBaseUrl}/api/admin/admins`, {
    headers: {
      Authorization: `Bearer ${superAdmin.accessToken}`,
      'Content-Type': 'application/json',
    },
    data: {
      username,
      displayName: 'Users Reader',
      password,
      roleCodes: [roleCode],
    },
  });
  expect(createAdminResponse.status()).toBe(201);

  return {
    username,
    password,
  };
}

async function loginViaAdminApi(request: APIRequestContext) {
  const response = await request.post(`${adminApiBaseUrl}/api/admin/auth/login`, {
    headers: {
      'Content-Type': 'application/json',
    },
    data: {
      username: 'super_admin',
      password: 'SuperAdmin123!',
    },
  });
  expect(response.status()).toBe(200);
  return (await response.json()) as { accessToken: string };
}

async function seedMentorRequest(
  request: APIRequestContext,
  payload: {
    installationId: string;
    correlationId: string;
    prompt: string;
    surface?: string;
    mode?: string;
  },
  expectedStatus: number,
) {
  const response = await request.post(`${appApiBaseUrl}/api/v1/mentor/chat`, {
    headers: {
      ...appVersionHeader,
      'Content-Type': 'application/json',
    },
    data: {
      installationId: payload.installationId,
      prompt: payload.prompt,
      surface: payload.surface ?? 'home',
      mode: payload.mode ?? 'single_turn',
      correlationId: payload.correlationId,
    },
  });

  expect(response.status()).toBe(expectedStatus);
  return response;
}

function uniqueSuffix(): string {
  return `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
}
