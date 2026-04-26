import { expect, test, type Page, type Response } from '@playwright/test';
import { createAdminWithPermissions, createRoleWithPermissions } from './helpers/admin-api';

test.describe('admin accounts hidden route', () => {
  test('super admins can open the hidden page from Users and reuse existing create/disable contracts', async ({
    page,
    request,
  }) => {
    const managedRole = await createRoleWithPermissions(request, ['users:read'], 'Browser Managed Admin');
    const username = `browser_${uniqueSuffix()}`;

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

    await page.getByTestId('admin-create-username').fill(username);
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
    const createdAdmin = (await createdResponse.json()) as { principalId: string };

    await expect(page.getByTestId('admin-accounts-create-feedback')).toContainText('管理员创建成功');
    const createdRow = page.locator('tbody tr').filter({ hasText: username }).first();
    const disableButton = page.getByTestId(`disable-admin-${createdAdmin.principalId}`);
    await expect(createdRow).toContainText('active');

    const firstDisableResponse = page.waitForResponse(
      (response) => response.url().includes('/api/admin/admins/') && response.url().includes('/disable') && response.request().method() === 'PATCH',
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
      (response) => response.url().includes('/api/admin/admins/') && response.url().includes('/disable') && response.request().method() === 'PATCH',
    );
    const reloadAfterSecondDisable = page.waitForResponse(
      (response) => exactApiPath(response, '/api/admin/admins') && response.request().method() === 'GET',
    );
    await disableButton.click();
    expect((await secondDisableResponse).status()).toBe(200);
    expect((await reloadAfterSecondDisable).status()).toBe(200);

    await expect(page.getByTestId('admin-accounts-disable-feedback')).toContainText('管理员已处于 disabled 状态');
  });

  test('admins with users:read + admins:read can enter the hidden page but cannot write', async ({ page, request }) => {
    const readOnlyAdmin = await createAdminWithPermissions(request, ['users:read', 'admins:read', 'rbac:read'], 'Admin Reader');

    await loginViaUi(page, {
      username: readOnlyAdmin.username,
      password: readOnlyAdmin.password,
      expectedUrl: /\/users(?:\?.*)?$/,
    });

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
    await expect(page.getByTestId('admin-accounts-readonly-note')).toBeVisible();
    await expect(page.getByTestId('admin-create-submit')).toBeDisabled();
    await expect(page.getByTestId('admin-accounts-context')).toContainText('admins:write missing');
    await expect(page.getByTestId('admin-accounts-list-card')).toContainText(readOnlyAdmin.username);
    await expect(page.getByRole('button', { name: /禁用|再次禁用/ })).toHaveCount(0);
  });

  test('users-only admins do not see the entry and direct hidden-route visits land on explicit /403', async ({ page, request }) => {
    const usersOnlyAdmin = await createAdminWithPermissions(request, ['users:read'], 'Users Reader');

    await loginViaUi(page, {
      username: usersOnlyAdmin.username,
      password: usersOnlyAdmin.password,
      expectedUrl: /\/users(?:\?.*)?$/,
    });

    await expect(page.getByTestId('users-open-admin-accounts')).toHaveCount(0);

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

function exactApiPath(response: Response, pathname: string): boolean {
  return new URL(response.url()).pathname === pathname;
}

function uniqueSuffix(): string {
  return `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
}
