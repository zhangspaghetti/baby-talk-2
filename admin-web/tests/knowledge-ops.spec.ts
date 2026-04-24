import { expect, test, type Page } from '@playwright/test';

const sessionStorageKey = 'babytalk.admin.session';

test.describe('knowledge ops workspace', () => {
  test('shows the real ingestion queue, contradiction split view, and notification pane on /knowledge-ops', async ({ page }) => {
    await loginViaUi(page);

    await page.goto('/knowledge-ops');

    await expect(page.getByTestId('knowledge-ops-page')).toBeVisible();
    await expect(page.getByTestId('knowledge-ingestion-queue')).toBeVisible();
    await expect(page.getByTestId('knowledge-contradiction-list')).toBeVisible();
    await expect(page.getByTestId('knowledge-notification-list')).toBeVisible();
    await expect(page.getByTestId('knowledge-inline-diagnostics')).toBeVisible();
  });
});

async function loginViaUi(page: Page, username = 'super_admin', password = 'SuperAdmin123!') {
  await page.goto('/login');
  await page.evaluate((storageKey) => window.localStorage.removeItem(storageKey), sessionStorageKey);

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
