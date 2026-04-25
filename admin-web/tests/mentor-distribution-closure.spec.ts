import { expect, test, type APIRequestContext, type Page } from '@playwright/test';
import { createAdminWithPermissions } from './helpers/admin-api';

const adminApiBaseUrl = 'http://127.0.0.1:8081';
const appApiBaseUrl = 'http://127.0.0.1:8080';
const appVersionHeader = {
  'X-App-Version': '1.2.0',
};
const androidUserAgent =
  'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/124.0.0.0 Mobile Safari/537.36';

test.describe('mentor + distribution closure proof', () => {
  test('keeps mentor incident evidence and distribution redaction truthful across shared shell navigation', async ({
    page,
    request,
  }) => {
    const suffix = uniqueSuffix();
    const installationId = `install-closure-${suffix}`;
    const blockedCorrelationId = `corr-closure-blocked-${suffix}`;
    const rateLimitedCorrelationId = `corr-closure-rate-${suffix}`;
    const dualWorkspaceAdmin = await createAdminWithPermissions(
      request,
      ['mentor:audit', 'distribution:read'],
      'Mentor Distribution Reader',
    );

    await seedMentorRequest(
      request,
      {
        installationId,
        correlationId: `corr-closure-success-${suffix}`,
        prompt: '宝宝又开始闹了，我先做什么？',
      },
      200,
    );
    await seedMentorRequest(
      request,
      {
        installationId,
        correlationId: blockedCorrelationId,
        prompt: '我想体罚他，怎么办？',
        surface: 'garden',
      },
      200,
    );
    await seedMentorRequest(
      request,
      {
        installationId,
        correlationId: `corr-closure-followup-${suffix}`,
        prompt: '给我一句更短的安抚话术',
      },
      200,
    );
    await seedMentorRequest(
      request,
      {
        installationId,
        correlationId: rateLimitedCorrelationId,
        prompt: '再来一次看看限流状态',
      },
      429,
    );

    const distributionSeed = await seedDistributionActivity(request);

    await loginViaUi(page, dualWorkspaceAdmin.username, dualWorkspaceAdmin.password, /\/overview$/);

    await expect(page.getByTestId('workspace-link-overview')).toBeVisible();
    await expect(page.getByTestId('workspace-link-mentor-audit')).toBeVisible();
    await expect(page.getByTestId('workspace-link-distribution-stats')).toBeVisible();
    await expect(page.getByTestId('workspace-link-users')).toHaveCount(0);
    await expect(page.getByTestId('workspace-link-knowledge-ops')).toHaveCount(0);

    const mentorLandingResponse = page.waitForResponse(
      (response) => response.url().includes('/api/admin/mentor/audits') && response.request().method() === 'GET',
    );
    await page.getByTestId('workspace-link-mentor-audit').click();
    expect((await mentorLandingResponse).status()).toBe(200);

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
    await expect(page.getByTestId('queue-context-query')).toContainText(`installationId=${installationId}`);
    await expect(page.getByTestId(`queue-item-${blockedCorrelationId}`)).toBeVisible();
    await expect(page.getByTestId('mentor-audit-queue')).not.toContainText(rateLimitedCorrelationId);

    const blockedDetailResponse = page.waitForResponse(
      (response) => response.url().includes(`/api/admin/mentor/audits/${blockedCorrelationId}`),
    );
    await page.getByTestId(`open-audit-${blockedCorrelationId}`).click();
    expect((await blockedDetailResponse).status()).toBe(200);

    await expect.poll(() => new URL(page.url()).searchParams.get('selected')).toBe(blockedCorrelationId);
    await expect(page.getByTestId('workspace-current')).toContainText('Mentor Audit');
    await expect(page.getByTestId('incident-evidence-note')).toContainText('incident-first');
    await expect(page.getByTestId('delivered-response-text')).toContainText("I'm here with you.");
    await expect(page.getByTestId('live-rate-limit-card')).toContainText('Current count');
    await expect(page.getByTestId('live-rate-limit-card')).toContainText('Limit');

    const distributionResponse = page.waitForResponse(
      (response) =>
        response.url().includes('/api/admin/distribution/stats') &&
        response.url().includes('range=30d') &&
        response.url().includes('channel=all'),
    );
    await page.getByTestId('workspace-link-distribution-stats').click();
    expect((await distributionResponse).status()).toBe(200);

    await expect(page).toHaveURL(/\/distribution\/stats\?range=30d&channel=all$/);
    await expect(page.getByTestId('workspace-current')).toContainText('Distribution Stats');
    await expect(page.getByTestId('release-only-channel-note')).toContainText('share_landing_events');
    await expect(page.getByTestId('detail-table-card')).toContainText('release_distribution');
    await expect(page.getByTestId('detail-table-card')).toContainText('share_landing');
    await expect(page.getByTestId('detail-table-card')).not.toContainText(distributionSeed.shareToken);

    const stableStatsResponse = page.waitForResponse(
      (response) =>
        response.url().includes('/api/admin/distribution/stats') &&
        response.url().includes('range=7d') &&
        response.url().includes('channel=stable'),
    );
    await page.getByTestId('range-option-7d').click();
    await page.getByTestId('channel-option-stable').click();
    await page.getByTestId('apply-filters').click();
    expect((await stableStatsResponse).status()).toBe(200);

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

    const backToDistributionDefault = page.waitForResponse(
      (response) =>
        response.url().includes('/api/admin/distribution/stats') &&
        response.url().includes('range=30d') &&
        response.url().includes('channel=all'),
    );
    await page.goBack();
    expect((await backToDistributionDefault).status()).toBe(200);
    await expect(page).toHaveURL(/\/distribution\/stats\?range=30d&channel=all$/);
    await expect(page.getByTestId('stats-context-query')).toContainText('range=30d&channel=all');

    const backToMentorDetail = page.waitForResponse(
      (response) => response.url().includes(`/api/admin/mentor/audits/${blockedCorrelationId}`),
    );
    await page.goBack();
    expect((await backToMentorDetail).status()).toBe(200);

    await expect(page).toHaveURL(new RegExp(`installationId=${installationId}.*flag=blocked_fallback.*selected=${blockedCorrelationId}`));
    await expect(page.getByTestId('workspace-current')).toContainText('Mentor Audit');
    await expect(page.getByTestId('queue-context-query')).toContainText(`installationId=${installationId}`);
    await expect(page.getByTestId('incident-evidence-note')).toContainText('incident-first');
    await expect(page.getByTestId('live-rate-limit-card')).toContainText('Current count');
  });
});

async function loginViaUi(page: Page, username: string, password: string, expectedUrl: RegExp) {
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
  await expect(page).toHaveURL(expectedUrl);
  await expect(page.getByTestId('protected-shell')).toBeVisible();
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
