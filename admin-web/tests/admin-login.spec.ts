import { expect, test } from '@playwright/test';

test.describe('admin login shell', () => {
  test('redirects unauthenticated visitors to login', async ({ page }) => {
    await page.goto('/protected');

    await expect(page).toHaveURL(/\/login$/);
    await expect(page.getByRole('heading', { name: 'BabyTalk Admin 登录' })).toBeVisible();
    await expect(page.getByTestId('login-banner')).toContainText('请先登录管理员账号');
    await expect(page.getByTestId('login-banner')).toContainText('admin_authentication_required');
  });

  test('shows a visible error for bad credentials', async ({ page }) => {
    await page.goto('/login');

    const failedLogin = page.waitForResponse((response) =>
      response.url().includes('/api/admin/auth/login') && response.request().method() === 'POST',
    );

    await page.getByLabel('用户名').fill('super_admin');
    await page.getByLabel('密码').fill('WrongPassword123!');
    await page.getByTestId('login-submit').click();

    const response = await failedLogin;
    expect(response.status()).toBe(401);

    await expect(page).toHaveURL(/\/login$/);
    await expect(page.getByTestId('login-error')).toContainText('用户名或密码错误');
    await expect(page.getByTestId('login-error')).toContainText('invalid_admin_credentials');
  });

  test('signs in, resolves /protected to mentor audit, and shows the workspace switcher', async ({ page }) => {
    await page.goto('/login');

    const loginResponse = page.waitForResponse((response) =>
      response.url().includes('/api/admin/auth/login') && response.request().method() === 'POST',
    );
    const meResponse = page.waitForResponse((response) =>
      response.url().includes('/api/admin/me') && response.request().method() === 'GET',
    );
    const mentorQueueResponse = page.waitForResponse((response) =>
      response.url().includes('/api/admin/mentor/audits') && response.request().method() === 'GET',
    );

    await page.getByLabel('用户名').fill('super_admin');
    await page.getByLabel('密码').fill('SuperAdmin123!');
    await page.getByTestId('login-submit').click();

    expect((await loginResponse).status()).toBe(200);
    expect((await meResponse).status()).toBe(200);
    expect((await mentorQueueResponse).status()).toBe(200);

    await expect(page).toHaveURL(/\/mentor\/audits$/);
    await expect(page.getByTestId('protected-shell')).toBeVisible();
    await expect(page.getByTestId('mentor-audit-page')).toBeVisible();
    await expect(page.getByTestId('session-user')).toContainText('super_admin');
    await expect(page.getByTestId('session-role')).toContainText('super_admin');
    await expect(page.getByTestId('workspace-switcher')).toBeVisible();
    await expect(page.getByTestId('workspace-link-mentor-audit')).toBeVisible();
    await expect(page.getByTestId('workspace-link-distribution-stats')).toBeVisible();
    await expect(page.getByTestId('workspace-current')).toContainText('Mentor Audit');
  });
});
