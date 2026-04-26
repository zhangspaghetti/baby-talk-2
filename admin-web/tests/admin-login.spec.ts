import { expect, test } from '@playwright/test';

test.describe('legacy /protected login smoke', () => {
  test('keeps the compatibility alias redirecting unauthenticated visitors to /login', async ({ page }) => {
    await page.goto('/protected');

    await expect(page).toHaveURL(/\/login\?returnTo=%2Fprotected$/);
    await expect(page.getByRole('heading', { name: 'BabyTalk Admin 登录' })).toBeVisible();
    await expect(page.getByTestId('login-banner')).toContainText('admin_authentication_required');
  });
});
