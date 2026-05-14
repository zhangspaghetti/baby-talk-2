import { expect, test, type Page } from '@playwright/test';

const admin = {
  principalId: 'admin-1',
  username: 'super_admin',
  displayName: 'Super Admin',
  roles: ['super_admin'],
  permissions: ['rag:read', 'kg:read', 'mentor:audit', 'distribution:read', 'users:read'],
};

test.describe('P0 cookie-backed admin session contract', () => {
  test('logs in without writing localStorage or sending bearer auth headers', async ({ page }) => {
    const meAuthorizationHeaders: Array<string | undefined> = [];

    await page.route('**/api/admin/auth/login', async (route) => {
      await route.fulfill({
        status: 200,
        headers: {
          'content-type': 'application/json',
          'set-cookie': 'admin_session=p0-contract; Path=/api/admin; HttpOnly; SameSite=Strict',
        },
        body: JSON.stringify({ admin }),
      });
    });
    await page.route('**/api/admin/me', async (route) => {
      meAuthorizationHeaders.push(route.request().headers().authorization);
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(admin) });
    });
    await page.route('**/api/admin/**', async (route) => {
      const url = route.request().url();
      if (url.includes('/api/admin/auth/login') || url.includes('/api/admin/me')) {
        await route.fallback();
        return;
      }
      await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' });
    });

    await login(page);

    await expect(page).toHaveURL(/\/overview$/);
    await expect(page.getByTestId('protected-shell')).toBeVisible();
    expect(await page.evaluate(() => window.localStorage.getItem('babytalk.admin.session'))).toBeNull();
    expect(meAuthorizationHeaders).toEqual([undefined]);
    expect((await page.context().cookies()).some((cookie) => cookie.name === 'admin_session' && cookie.httpOnly)).toBe(
      true,
    );
  });
});

async function login(page: Page) {
  await page.goto('/login');
  await page.getByLabel('用户名').fill('super_admin');
  await page.getByLabel('密码').fill('SuperAdmin123!');
  await page.getByTestId('login-submit').click();
}
