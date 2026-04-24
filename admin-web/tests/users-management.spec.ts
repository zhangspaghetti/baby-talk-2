import { expect, test, type Page, type Response, type Route } from '@playwright/test';
import { createAdminWithPermissions, createRoleWithPermissions } from './helpers/admin-api';
import { bootstrapWithAccessToken, provisionConsumerWithHistory } from './helpers/mobile-api';

test.describe('users management workspace', () => {
  test('shows URL-backed list/detail state, requires a reason, and invalidates stale mobile tokens after disable', async ({
    page,
    request,
  }) => {
    const seeded = await provisionConsumerWithHistory(request);

    const bootstrapBeforeDisable = await bootstrapWithAccessToken(request, seeded.installationId, seeded.mobileAccessToken);
    expect(bootstrapBeforeDisable.status()).toBe(200);

    await loginViaUi(page, { expectedUrl: /\/overview$/ });

    const initialListResponse = page.waitForResponse(
      (response) =>
        exactApiPath(response, '/api/admin/users') &&
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
        exactApiPath(response, '/api/admin/users') &&
        response.request().method() === 'GET' &&
        response.url().includes(`query=${encodeURIComponent(seeded.phoneNumber)}`),
    );
    await page.getByTestId('users-search-input').fill(seeded.phoneNumber);
    await page.getByTestId('users-apply-filters').click();
    expect((await filteredListResponse).status()).toBe(200);

    await expect.poll(() => new URL(page.url()).searchParams.get('query')).toBe(seeded.phoneNumber);
    await expect(page.getByTestId('users-context-query')).toContainText(`query=${seeded.phoneNumber}`);

    const detailResponse = page.waitForResponse(
      (response) => exactApiPath(response, `/api/admin/users/${seeded.accountId}`) && response.request().method() === 'GET',
    );
    await page.getByTestId(`open-user-${seeded.accountId}`).click();
    expect((await detailResponse).status()).toBe(200);

    await expect.poll(() => new URL(page.url()).searchParams.get('selected')).toBe(seeded.accountId);
    await expect(page.getByTestId('users-sessions-card')).toContainText(seeded.installationId);
    await expect(page.getByTestId('users-sessions-card')).toContainText(seeded.secondInstallationId);
    await expect(page.getByTestId('users-consent-card')).toContainText('accept');

    const reloadListResponse = page.waitForResponse(
      (response) =>
        exactApiPath(response, '/api/admin/users') &&
        response.request().method() === 'GET' &&
        response.url().includes(`query=${encodeURIComponent(seeded.phoneNumber)}`),
    );
    const reloadDetailResponse = page.waitForResponse(
      (response) => exactApiPath(response, `/api/admin/users/${seeded.accountId}`) && response.request().method() === 'GET',
    );
    await page.reload();
    expect((await reloadListResponse).status()).toBe(200);
    expect((await reloadDetailResponse).status()).toBe(200);
    await expect.poll(() => new URL(page.url()).searchParams.get('selected')).toBe(seeded.accountId);

    await page.getByTestId('disable-user-button').click();
    await page.getByRole('button', { name: '确认禁用' }).click();
    await expect(page.getByTestId('disable-confirmation-state')).toContainText('请输入禁用原因');

    const disableResponse = page.waitForResponse(
      (response) =>
        exactApiPath(response, `/api/admin/users/${seeded.accountId}/disable`) && response.request().method() === 'PATCH',
    );
    const refreshedListResponse = page.waitForResponse(
      (response) =>
        exactApiPath(response, '/api/admin/users') &&
        response.request().method() === 'GET' &&
        response.url().includes(`query=${encodeURIComponent(seeded.phoneNumber)}`),
    );
    const refreshedDetailResponse = page.waitForResponse(
      (response) => exactApiPath(response, `/api/admin/users/${seeded.accountId}`) && response.request().method() === 'GET',
    );
    await page.getByTestId('disable-reason-input').fill('admin_review_e2e');
    await page.getByRole('button', { name: '确认禁用' }).click();
    expect((await disableResponse).status()).toBe(200);
    expect((await refreshedListResponse).status()).toBe(200);
    expect((await refreshedDetailResponse).status()).toBe(200);

    await expect(page.getByTestId('users-disable-feedback')).toContainText('禁用已应用');
    await expect(page.getByTestId('users-disable-feedback')).toContainText('result=applied');
    await expect(page.getByTestId('users-detail-status')).toContainText('deleted');
    await expect(page.getByTestId('users-selected-missing')).toBeVisible();
    await expect(page.getByTestId('users-list-table')).toContainText('当前过滤条件下没有账号');

    const bootstrapAfterDisable = await bootstrapWithAccessToken(request, seeded.installationId, seeded.mobileAccessToken);
    expect(bootstrapAfterDisable.status()).toBe(401);
    expect(await bootstrapAfterDisable.json()).toMatchObject({
      code: 'account_deleted',
      details: {
        reason: 'account_deleted',
      },
    });
  });

  test('keeps malformed URL context visible and surfaces detail/list failures inline', async ({ page, request }) => {
    const seeded = await provisionConsumerWithHistory(request);
    await loginViaUi(page, { expectedUrl: /\/overview$/ });

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
    const missingDetailResponse = page.waitForResponse(
      (response) => exactApiPath(response, '/api/admin/users/acct_missing_browser') && response.request().method() === 'GET',
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

  test('super admins can manage hidden admin accounts and surface backend validation inline', async ({ page, request }) => {
    const managedRole = await createRoleWithPermissions(request, ['users:read'], 'Browser Managed Admin');
    const createdUsername = `browser_${uniqueSuffix()}`;

    await loginViaUi(page, { expectedUrl: /\/overview$/ });

    const usersListResponse = page.waitForResponse(
      (response) => exactApiPath(response, '/api/admin/users') && response.request().method() === 'GET',
    );
    await page.goto('/users');
    expect((await usersListResponse).status()).toBe(200);
    await expect(page.getByTestId('users-open-admin-accounts')).toBeVisible();

    const adminsListResponse = page.waitForResponse(
      (response) => exactApiPath(response, '/api/admin/admins') && response.request().method() === 'GET',
    );
    const rolesResponse = page.waitForResponse(
      (response) => exactApiPath(response, '/api/admin/roles') && response.request().method() === 'GET',
    );
    await page.getByTestId('users-open-admin-accounts').click();
    expect((await adminsListResponse).status()).toBe(200);
    expect((await rolesResponse).status()).toBe(200);

    await expect(page).toHaveURL(/\/users\/admins$/);
    await expect(page.getByTestId('admin-accounts-page')).toBeVisible();
    await expect(page.getByTestId('admin-accounts-context')).toContainText('admins:write enabled');

    await page.getByTestId('admin-create-username').fill(createdUsername);
    await page.getByTestId('admin-create-display-name').fill('Browser Managed Admin');
    await page.getByTestId('admin-create-password').fill('Browser123!');
    await page.getByLabel(new RegExp(managedRole.roleCode)).check();

    const createResponse = page.waitForResponse(
      (response) => exactApiPath(response, '/api/admin/admins') && response.request().method() === 'POST',
    );
    const reloadAfterCreate = page.waitForResponse(
      (response) => exactApiPath(response, '/api/admin/admins') && response.request().method() === 'GET',
    );
    await page.getByTestId('admin-create-submit').click();
    const createdResponse = await createResponse;
    expect(createdResponse.status()).toBe(201);
    expect((await reloadAfterCreate).status()).toBe(200);
    const createdAdmin = (await createdResponse.json()) as { principalId?: string };
    expect(typeof createdAdmin.principalId).toBe('string');

    await expect(page.getByTestId('admin-accounts-create-feedback')).toContainText('管理员创建成功');
    const createdRow = page
      .getByTestId('admin-accounts-list-card')
      .locator('tbody tr')
      .filter({ hasText: createdUsername })
      .first();
    await expect(createdRow).toContainText('active');

    await page.getByTestId('admin-create-username').fill(createdUsername);
    await page.getByTestId('admin-create-display-name').fill('Duplicate Browser Managed Admin');
    await page.getByTestId('admin-create-password').fill('Browser123!');
    const duplicateResponse = page.waitForResponse(
      (response) => exactApiPath(response, '/api/admin/admins') && response.request().method() === 'POST',
    );
    await page.getByTestId('admin-create-submit').click();
    expect((await duplicateResponse).status()).toBe(409);
    await expect(page.getByTestId('admin-accounts-create-feedback')).toContainText('admin_username_conflict');

    const invalidRoleUsername = `browser_invalid_${uniqueSuffix()}`;
    await page.getByTestId('admin-create-username').fill(invalidRoleUsername);
    await page.getByTestId('admin-create-display-name').fill('Browser Invalid Role');
    await page.getByTestId('admin-create-password').fill('Browser123!');

    const unknownRoleResponse = page.waitForResponse(
      (response) => exactApiPath(response, '/api/admin/admins') && response.request().method() === 'POST',
    );
    await tamperCreateAdminRequest(page, { roleCodes: ['missing_role'] }, async () => {
      await page.getByTestId('admin-create-submit').click();
    });
    expect((await unknownRoleResponse).status()).toBe(400);
    await expect(page.getByTestId('admin-accounts-create-feedback')).toContainText('unknown_admin_role');

    const disableButton = page.getByTestId(`disable-admin-${createdAdmin.principalId}`);
    const firstDisableResponse = page.waitForResponse(
      (response) =>
        response.url().includes('/api/admin/admins/') &&
        response.url().includes('/disable') &&
        response.request().method() === 'PATCH',
    );
    const reloadAfterDisable = page.waitForResponse(
      (response) => exactApiPath(response, '/api/admin/admins') && response.request().method() === 'GET',
    );
    await disableButton.click();
    expect((await firstDisableResponse).status()).toBe(200);
    expect((await reloadAfterDisable).status()).toBe(200);

    await expect(page.getByTestId('admin-accounts-disable-feedback')).toContainText('管理员已禁用');
    await expect(createdRow).toContainText('disabled');

    const secondDisableResponse = page.waitForResponse(
      (response) =>
        response.url().includes('/api/admin/admins/') &&
        response.url().includes('/disable') &&
        response.request().method() === 'PATCH',
    );
    const reloadAfterSecondDisable = page.waitForResponse(
      (response) => exactApiPath(response, '/api/admin/admins') && response.request().method() === 'GET',
    );
    await disableButton.click();
    expect((await secondDisableResponse).status()).toBe(200);
    expect((await reloadAfterSecondDisable).status()).toBe(200);

    await expect(page.getByTestId('admin-accounts-disable-feedback')).toContainText('管理员已处于 disabled 状态');
  });

  test('users-only admins keep /users/admins hidden, fail closed on deep links, and cannot disable users', async ({
    page,
    request,
  }) => {
    const seeded = await provisionConsumerWithHistory(request);
    const usersOnlyAdmin = await createAdminWithPermissions(request, ['users:read'], 'Users Reader');

    await loginViaUi(page, {
      username: usersOnlyAdmin.username,
      password: usersOnlyAdmin.password,
      expectedUrl: /\/users(?:\?.*)?$/,
    });

    const filteredListResponse = page.waitForResponse(
      (response) =>
        exactApiPath(response, '/api/admin/users') &&
        response.request().method() === 'GET' &&
        response.url().includes(`query=${encodeURIComponent(seeded.phoneNumber)}`),
    );
    await page.goto(`/users?query=${encodeURIComponent(seeded.phoneNumber)}`);
    expect((await filteredListResponse).status()).toBe(200);

    const detailResponse = page.waitForResponse(
      (response) => exactApiPath(response, `/api/admin/users/${seeded.accountId}`) && response.request().method() === 'GET',
    );
    await page.getByTestId(`open-user-${seeded.accountId}`).click();
    expect((await detailResponse).status()).toBe(200);

    await expect(page.getByTestId('users-page')).toBeVisible();
    await expect(page.getByText('users:write missing')).toBeVisible();
    await expect(page.getByTestId('users-open-admin-accounts')).toHaveCount(0);
    await expect(page.getByTestId('disable-user-button')).toHaveCount(0);
    await expect(page.getByTestId('users-sessions-card')).toContainText(seeded.installationId);

    await page.goto('/users/admins');

    await expect(page).toHaveURL(/\/403\?from=%2Fusers%2Fadmins/);
    await expect(page.getByTestId('forbidden-page')).toBeVisible();
    await expect(page.getByTestId('forbidden-query')).toContainText('routeKey=admin-accounts');
    await expect(page.getByTestId('forbidden-query')).toContainText('required=admins%3Aread');
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

async function tamperCreateAdminRequest(
  page: Page,
  patch: Partial<CreateAdminRequestPayload>,
  action: () => Promise<void>,
) {
  const pattern = '**/api/admin/admins';
  let intercepted = false;
  const handler = async (route: Route) => {
    if (route.request().method() !== 'POST' || new URL(route.request().url()).pathname !== '/api/admin/admins' || intercepted) {
      await route.continue();
      return;
    }

    intercepted = true;
    const originalPayload = route.request().postDataJSON() as CreateAdminRequestPayload;
    await route.continue({
      postData: JSON.stringify({
        ...originalPayload,
        ...patch,
      }),
    });
  };

  await page.route(pattern, handler);
  try {
    await action();
  } finally {
    await page.unroute(pattern, handler);
  }

  expect(intercepted).toBe(true);
}

function exactApiPath(response: Response, pathname: string): boolean {
  return new URL(response.url()).pathname === pathname;
}

function uniqueSuffix(): string {
  return `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
}

type CreateAdminRequestPayload = {
  username: string;
  displayName: string;
  password: string;
  roleCodes: string[];
};
