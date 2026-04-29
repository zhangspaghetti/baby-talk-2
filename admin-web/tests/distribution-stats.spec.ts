import { expect, test, type APIRequestContext, type Page } from '@playwright/test';

const adminApiBaseUrl = 'http://127.0.0.1:8081';
const appApiBaseUrl = 'http://127.0.0.1:8080';
const appVersionHeader = {
  'X-App-Version': '1.2.0',
};
const androidUserAgent = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/124.0.0.0 Mobile Safari/537.36';

test.describe('distribution stats workspace', () => {
  test('shows truthful seeded stats, keeps filter query in URL, and redacts share tokens', async ({ page, request }) => {
    const seeded = await seedDistributionActivity(request);

    await loginViaUi(page);

    const initialStatsResponse = page.waitForResponse(
      (response) =>
        response.url().includes('/api/admin/distribution/stats') &&
        response.url().includes('range=30d') &&
        response.url().includes('channel=all'),
    );
    await page.getByTestId('workspace-link-distribution-stats').click();
    expect((await initialStatsResponse).status()).toBe(200);

    await expect(page).toHaveURL(/\/distribution\/stats\?range=30d&channel=all$/);
    await expect(page.getByTestId('distribution-stats-page')).toBeVisible();
    await expect(page.getByTestId('release-only-channel-note')).toContainText('share_landing_events');
    await expect(page.getByTestId('detail-table-card')).toContainText('release_distribution');
    await expect(page.getByTestId('detail-table-card')).toContainText('share_landing');
    await expect(page.getByTestId('share-funnel-card')).toContainText('create');
    await expect(page.getByTestId('share-funnel-card')).toContainText('download');
    await expect(page.getByTestId('share-handoff-card')).toContainText('share download fallback');
    await expect(page.getByTestId('detail-table-card')).not.toContainText(seeded.shareToken);

    const stableFilterResponse = page.waitForResponse(
      (response) =>
        response.url().includes('/api/admin/distribution/stats') &&
        response.url().includes('range=7d') &&
        response.url().includes('channel=stable'),
    );
    await page.getByTestId('range-option-7d').click();
    await page.getByTestId('channel-option-stable').click();
    await page.getByTestId('apply-filters').click();
    expect((await stableFilterResponse).status()).toBe(200);

    await expect(page).toHaveURL(/\/distribution\/stats\?range=7d&channel=stable$/);
    await expect(page.getByTestId('stats-context-query')).toContainText('range=7d&channel=stable');
    await expect(page.getByTestId('detail-table-card')).toContainText('stable');
    await expect(page.getByTestId('detail-table-card')).not.toContainText('beta');

    const reloadResponse = page.waitForResponse(
      (response) =>
        response.url().includes('/api/admin/distribution/stats') &&
        response.url().includes('range=7d') &&
        response.url().includes('channel=stable'),
    );
    await page.reload();
    expect((await reloadResponse).status()).toBe(200);
    await expect(page).toHaveURL(/\/distribution\/stats\?range=7d&channel=stable$/);
    await expect(page.getByTestId('stats-context-query')).toContainText('range=7d&channel=stable');

    const betaFilterResponse = page.waitForResponse(
      (response) =>
        response.url().includes('/api/admin/distribution/stats') &&
        response.url().includes('range=7d') &&
        response.url().includes('channel=beta'),
    );
    await page.getByTestId('channel-option-beta').click();
    await page.getByTestId('apply-filters').click();
    expect((await betaFilterResponse).status()).toBe(200);
    await expect(page).toHaveURL(/\/distribution\/stats\?range=7d&channel=beta$/);

    const backResponse = page.waitForResponse(
      (response) =>
        response.url().includes('/api/admin/distribution/stats') &&
        response.url().includes('range=7d') &&
        response.url().includes('channel=stable'),
    );
    await page.goBack();
    expect((await backResponse).status()).toBe(200);
    await expect(page).toHaveURL(/\/distribution\/stats\?range=7d&channel=stable$/);
  });

  test('lands distribution-only admins in stats workspace and hides mentor-only navigation', async ({ page, request }) => {
    const limitedAdmin = await createAdminWithPermissions(request, ['distribution:read'], 'Distribution Reader');

    await page.goto('/login');

    const loginResponse = page.waitForResponse((response) =>
      response.url().includes('/api/admin/auth/login') && response.request().method() === 'POST',
    );
    const meResponse = page.waitForResponse((response) =>
      response.url().includes('/api/admin/me') && response.request().method() === 'GET',
    );
    const statsResponse = page.waitForResponse((response) =>
      response.url().includes('/api/admin/distribution/stats') && response.request().method() === 'GET',
    );

    await page.getByLabel('用户名').fill(limitedAdmin.username);
    await page.getByLabel('密码').fill(limitedAdmin.password);
    await page.getByTestId('login-submit').click();

    expect((await loginResponse).status()).toBe(200);
    expect((await meResponse).status()).toBe(200);
    expect((await statsResponse).status()).toBe(200);

    await expect(page).toHaveURL(/\/distribution\/stats\?range=30d&channel=all$/);
    await expect(page.getByTestId('distribution-stats-page')).toBeVisible();
    await expect(page.getByTestId('workspace-link-distribution-stats')).toBeVisible();
    await expect(page.getByTestId('workspace-link-mentor-audit')).toHaveCount(0);
    await expect(page.getByTestId('workspace-current')).toContainText('Distribution Stats');
  });

  test('normalizes invalid URL filters to safe defaults while keeping query context recoverable', async ({ page }) => {
    await loginViaUi(page);

    const invalidResponse = page.waitForResponse(
      (response) =>
        response.url().includes('/api/admin/distribution/stats') &&
        response.url().includes('range=30d') &&
        response.url().includes('channel=all'),
    );
    await page.goto('/distribution/stats?range=14d&channel=all');
    expect((await invalidResponse).status()).toBe(200);

    await expect(page.getByTestId('stats-query-normalized-state')).toBeVisible();
    await expect(page.getByTestId('stats-query-normalized-state')).toContainText('range=30d, channel=all');
    await expect(page.getByTestId('distribution-error-state')).toHaveCount(0);
    await expect(page).toHaveURL(/\/distribution\/stats\?range=14d&channel=all$/);
    await expect(page.getByTestId('stats-context-query')).toContainText('range=14d&channel=all');
    await expect(page.getByTestId('range-badge')).toContainText('14d → 30d');

    await page.getByTestId('reset-filters').click();

    await expect(page).toHaveURL(/\/distribution\/stats\?range=30d&channel=all$/);
    await expect(page.getByTestId('stats-query-normalized-state')).toHaveCount(0);
    await expect(page.getByTestId('distribution-stats-page')).toBeVisible();
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
  await expect(page).toHaveURL(/\/overview(?:\?.*)?$|\/users(?:\?.*)?$|\/knowledge-ops(?:\?.*)?$|\/mentor\/audits(?:\?.*)?$|\/distribution\/stats(?:\?.*)?$/);
  await expect(page.getByTestId('protected-shell')).toBeVisible();
}

async function createAdminWithPermissions(
  request: APIRequestContext,
  permissionCodes: string[],
  displayName: string,
) {
  const suffix = uniqueSuffix();
  const roleCode = `role_${suffix}`;
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
      permissionCodes,
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
      displayName,
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

async function seedDistributionActivity(request: APIRequestContext) {
  const shareToken = await createShareLink(request);

  const shareLandingResponse = await request.get(`${appApiBaseUrl}/share/${shareToken}`, {
    headers: {
      'User-Agent': androidUserAgent,
    },
  });
  expect(shareLandingResponse.status()).toBe(200);
  await expect(shareLandingResponse.text()).resolves.toContain('Warm water, please.');

  const shareDownloadResponse = await request.get(`${appApiBaseUrl}/share/${shareToken}/download?platform=android`, {
    headers: {
      'User-Agent': androidUserAgent,
    },
  });
  expect(shareDownloadResponse.status()).toBe(200);
  await expect(shareDownloadResponse.text()).resolves.toContain('下载 Baby Talk');

  const stableDownloadResponse = await request.get(`${appApiBaseUrl}/download?channel=stable&source=public_link`, {
    headers: {
      'User-Agent': androidUserAgent,
    },
  });
  expect(stableDownloadResponse.status()).toBe(200);
  await expect(stableDownloadResponse.text()).resolves.toContain('下载 Baby Talk');

  const stableRedirectResponse = await request.get(
    `${appApiBaseUrl}/download/redirect?channel=stable&source=public_link&platform=android`,
    {
      maxRedirects: 0,
    },
  );
  expect(stableRedirectResponse.status()).toBe(302);

  const betaDownloadResponse = await request.get(`${appApiBaseUrl}/download?channel=beta&source=public_link`, {
    headers: {
      'User-Agent': androidUserAgent,
    },
  });
  expect(betaDownloadResponse.status()).toBe(200);
  await expect(betaDownloadResponse.text()).resolves.toContain('下载 Baby Talk');

  const betaRedirectResponse = await request.get(
    `${appApiBaseUrl}/download/redirect?channel=beta&source=public_link&platform=android`,
    {
      maxRedirects: 0,
    },
  );
  expect(betaRedirectResponse.status()).toBe(302);

  return {
    shareToken,
  };
}

async function createShareLink(request: APIRequestContext): Promise<string> {
  const suffix = uniqueSuffix();
  const response = await request.post(`${appApiBaseUrl}/api/v1/share-links`, {
    headers: {
      ...appVersionHeader,
      'Content-Type': 'application/json',
    },
    data: {
      source: 'paired_progress',
      platformHint: 'android',
      headline: `今晚洗澡时，她第一次主动说 warm water · ${suffix}`,
      storyText: `我们在浴室里重复了两次，宝宝笑着拍水回应 · ${suffix}`,
      phraseText: 'Warm water, please.',
      phraseTranslation: '请给我温温的水。',
      recommendationTitle: '睡前再重复一次这句短语',
      recommendationReason: '趁今天记忆最鲜活时，再在睡前重复一次。',
      spaceId: 'daily_care',
      activityId: 'bath_time',
    },
  });

  expect(response.status()).toBe(201);
  const payload = (await response.json()) as { token: string };
  expect(payload.token).toBeTruthy();
  return payload.token;
}

function uniqueSuffix(): string {
  return `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
}
