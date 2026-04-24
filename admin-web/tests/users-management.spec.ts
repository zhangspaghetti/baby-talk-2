import { expect, test, type APIRequestContext, type Page } from '@playwright/test';
import { createAdminWithPermissions } from './helpers/admin-api';

const appApiBaseUrl = 'http://127.0.0.1:8080';
const appVersionHeader = {
  'X-App-Version': '1.2.0',
};

test.describe('users management workspace', () => {
  test('shows URL-backed list/detail state, requires a reason, and invalidates stale mobile tokens after disable', async ({
    page,
    request,
  }) => {
    const seeded = await provisionConsumerWithHistory(request);

    const bootstrapBeforeDisable = await request.get(`${appApiBaseUrl}/api/v1/bootstrap?installationId=${seeded.installationId}`, {
      headers: {
        ...appVersionHeader,
        Authorization: `Bearer ${seeded.mobileAccessToken}`,
      },
    });
    expect(bootstrapBeforeDisable.status()).toBe(200);

    await loginViaUi(page);

    const initialListResponse = page.waitForResponse(
      (response) =>
        response.url().includes('/api/admin/users') &&
        response.request().method() === 'GET' &&
        response.url().includes('page=1') &&
        response.url().includes('pageSize=20') &&
        response.url().includes('status=all'),
    );
    await page.goto('/users');
    expect((await initialListResponse).status()).toBe(200);

    await expect.poll(() => new URL(page.url()).searchParams.get('page')).toBe('1');
    await expect.poll(() => new URL(page.url()).searchParams.get('pageSize')).toBe('20');
    await expect.poll(() => new URL(page.url()).searchParams.get('status')).toBe('all');
    await expect(page.getByTestId('users-list-table')).toContainText(seeded.phoneNumber);

    const filteredListResponse = page.waitForResponse(
      (response) =>
        response.url().includes('/api/admin/users') &&
        response.request().method() === 'GET' &&
        response.url().includes(`query=${encodeURIComponent(seeded.phoneNumber)}`),
    );
    await page.getByTestId('users-search-input').fill(seeded.phoneNumber);
    await page.getByTestId('users-apply-filters').click();
    expect((await filteredListResponse).status()).toBe(200);

    await expect.poll(() => new URL(page.url()).searchParams.get('query')).toBe(seeded.phoneNumber);
    await expect(page.getByTestId('users-context-query')).toContainText(`query=${seeded.phoneNumber}`);

    const detailResponse = page.waitForResponse((response) =>
      response.url().includes(`/api/admin/users/${seeded.accountId}`) && response.request().method() === 'GET',
    );
    await page.getByTestId(`open-user-${seeded.accountId}`).click();
    expect((await detailResponse).status()).toBe(200);

    await expect.poll(() => new URL(page.url()).searchParams.get('selected')).toBe(seeded.accountId);
    await expect(page.getByTestId('users-sessions-card')).toContainText(seeded.installationId);
    await expect(page.getByTestId('users-sessions-card')).toContainText(seeded.secondInstallationId);
    await expect(page.getByTestId('users-consent-card')).toContainText('accept');

    const reloadListResponse = page.waitForResponse(
      (response) =>
        response.url().includes('/api/admin/users') &&
        response.request().method() === 'GET' &&
        response.url().includes(`query=${encodeURIComponent(seeded.phoneNumber)}`),
    );
    const reloadDetailResponse = page.waitForResponse((response) =>
      response.url().includes(`/api/admin/users/${seeded.accountId}`) && response.request().method() === 'GET',
    );
    await page.reload();
    expect((await reloadListResponse).status()).toBe(200);
    expect((await reloadDetailResponse).status()).toBe(200);
    await expect.poll(() => new URL(page.url()).searchParams.get('selected')).toBe(seeded.accountId);

    await page.getByTestId('disable-user-button').click();
    await page.getByRole('button', { name: '确认禁用' }).click();
    await expect(page.getByTestId('disable-confirmation-state')).toContainText('请输入禁用原因');

    const disableResponse = page.waitForResponse((response) =>
      response.url().includes(`/api/admin/users/${seeded.accountId}/disable`) && response.request().method() === 'PATCH',
    );
    const refreshedListResponse = page.waitForResponse(
      (response) =>
        response.url().includes('/api/admin/users') &&
        response.request().method() === 'GET' &&
        response.url().includes(`query=${encodeURIComponent(seeded.phoneNumber)}`),
    );
    const refreshedDetailResponse = page.waitForResponse((response) =>
      response.url().includes(`/api/admin/users/${seeded.accountId}`) && response.request().method() === 'GET',
    );
    await page.getByTestId('disable-reason-input').fill('admin_review_e2e');
    await page.getByRole('button', { name: '确认禁用' }).click();
    expect((await disableResponse).status()).toBe(200);
    expect((await refreshedListResponse).status()).toBe(200);
    expect((await refreshedDetailResponse).status()).toBe(200);

    await expect(page.getByTestId('users-disable-feedback')).toContainText('禁用已应用');
    await expect(page.getByTestId('users-disable-feedback')).toContainText('result=applied');
    await expect(page.getByTestId('users-detail-status')).toContainText('deleted');
    await expect(page.getByTestId('users-list-table')).toContainText('deleted');

    const bootstrapAfterDisable = await request.get(`${appApiBaseUrl}/api/v1/bootstrap?installationId=${seeded.installationId}`, {
      headers: {
        ...appVersionHeader,
        Authorization: `Bearer ${seeded.mobileAccessToken}`,
      },
    });
    expect(bootstrapAfterDisable.status()).toBe(401);
    await expect(bootstrapAfterDisable.json()).resolves.toMatchObject({
      code: 'account_deleted',
      details: {
        reason: 'account_deleted',
      },
    });
  });

  test('keeps malformed URL context visible and surfaces detail/list failures inline', async ({ page, request }) => {
    const seeded = await provisionConsumerWithHistory(request);
    await loginViaUi(page);

    const malformedListResponse = page.waitForResponse(
      (response) =>
        response.url().includes('/api/admin/users?page=0&pageSize=101&status=all') &&
        response.request().method() === 'GET',
    );
    await page.goto('/users?page=0&pageSize=101&status=all');
    expect((await malformedListResponse).status()).toBe(400);

    await expect(page).toHaveURL(/\/users\?page=0&pageSize=101&status=all$/);
    await expect(page.getByTestId('users-list-error-state')).toContainText('validation_failed');
    await expect(page.getByTestId('users-context-query')).toContainText('page=0&pageSize=101&status=all');

    const missingDetailListResponse = page.waitForResponse(
      (response) =>
        response.url().includes(`/api/admin/users?page=1&pageSize=20&status=all&query=${encodeURIComponent(seeded.phoneNumber)}`) &&
        response.request().method() === 'GET',
    );
    const missingDetailResponse = page.waitForResponse((response) =>
      response.url().includes('/api/admin/users/acct_missing_browser') && response.request().method() === 'GET',
    );
    await page.goto(
      `/users?page=1&pageSize=20&status=all&query=${encodeURIComponent(seeded.phoneNumber)}&selected=acct_missing_browser`,
    );
    expect((await missingDetailListResponse).status()).toBe(200);
    expect((await missingDetailResponse).status()).toBe(404);

    await expect(page.getByTestId('users-detail-error-state')).toContainText('user_account_not_found');
    await expect(page.getByTestId('users-selected-missing')).toBeVisible();
    await expect.poll(() => new URL(page.url()).searchParams.get('selected')).toBe('acct_missing_browser');
  });

  test('hides destructive controls for read-only admins', async ({ page, request }) => {
    const seeded = await provisionConsumerWithHistory(request);
    const limitedAdmin = await createAdminWithPermissions(request, ['users:read'], 'Users Reader');

    await loginViaUi(page, limitedAdmin.username, limitedAdmin.password);

    const filteredListResponse = page.waitForResponse(
      (response) =>
        response.url().includes('/api/admin/users') &&
        response.request().method() === 'GET' &&
        response.url().includes(`query=${encodeURIComponent(seeded.phoneNumber)}`),
    );
    await page.goto(`/users?query=${encodeURIComponent(seeded.phoneNumber)}`);
    expect((await filteredListResponse).status()).toBe(200);

    const detailResponse = page.waitForResponse((response) =>
      response.url().includes(`/api/admin/users/${seeded.accountId}`) && response.request().method() === 'GET',
    );
    await page.getByTestId(`open-user-${seeded.accountId}`).click();
    expect((await detailResponse).status()).toBe(200);

    await expect(page.getByTestId('users-page')).toBeVisible();
    await expect(page.getByText('users:write missing')).toBeVisible();
    await expect(page.getByTestId('disable-user-button')).toHaveCount(0);
    await expect(page.getByTestId('users-sessions-card')).toContainText(seeded.installationId);
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
  await expect(page).toHaveURL(/\/overview$|\/users(?:\?.*)?$/);
  await expect(page.getByTestId('protected-shell')).toBeVisible();
}

async function provisionConsumerWithHistory(request: APIRequestContext) {
  const phoneNumber = `138${uniqueDigits(8)}`;
  const installationId = `install-alpha-${uniqueSuffix()}`;
  const secondInstallationId = `install-beta-${uniqueSuffix()}`;

  const firstChallengeId = await createChallenge(request, phoneNumber);
  const firstSession = await verifyChallenge(request, firstChallengeId, installationId);
  await acceptConsent(request, firstSession.accessToken);

  const secondChallengeId = await createChallenge(request, phoneNumber);
  const secondSession = await verifyChallenge(request, secondChallengeId, secondInstallationId);
  await acceptConsent(request, secondSession.accessToken);

  return {
    accountId: firstSession.accountId,
    phoneNumber,
    installationId,
    secondInstallationId,
    mobileAccessToken: firstSession.accessToken,
  };
}

async function createChallenge(request: APIRequestContext, phoneNumber: string): Promise<string> {
  const response = await request.post(`${appApiBaseUrl}/api/v1/auth/challenges`, {
    headers: {
      ...appVersionHeader,
      'Content-Type': 'application/json',
    },
    data: {
      phoneNumber,
    },
  });
  expect(response.status()).toBe(201);
  const payload = (await response.json()) as { challengeId: string };
  expect(payload.challengeId).toBeTruthy();
  return payload.challengeId;
}

async function verifyChallenge(request: APIRequestContext, challengeId: string, installationId: string) {
  const response = await request.post(`${appApiBaseUrl}/api/v1/auth/verify`, {
    headers: {
      ...appVersionHeader,
      'Content-Type': 'application/json',
    },
    data: {
      challengeId,
      verificationCode: '246810',
      installationId,
    },
  });
  expect(response.status()).toBe(200);
  return (await response.json()) as {
    accountId: string;
    sessionId: string;
    accessToken: string;
    refreshToken: string;
  };
}

async function acceptConsent(request: APIRequestContext, accessToken: string) {
  const response = await request.post(`${appApiBaseUrl}/api/v1/consent/accept`, {
    headers: {
      ...appVersionHeader,
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    data: {
      consentVersion: 'pipl-v1',
    },
  });
  expect(response.status()).toBe(200);
}

function uniqueSuffix(): string {
  return `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
}

function uniqueDigits(length: number): string {
  return Array.from({ length }, () => Math.floor(Math.random() * 10)).join('');
}
