import { expect, test, type Page, type Route } from '@playwright/test';

test.describe('overview control plane proof', () => {
  test('renders the truthful overview control plane for super admins', async ({ page }) => {
    await loginViaUi(page, { expectedUrl: /\/overview$/ });

    await expect(page.getByTestId('overview-control-strip')).toBeVisible();
    await expect(page.getByTestId('overview-inline-diagnostics')).toBeVisible();
    await expect(page.getByTestId('overview-transport-mode')).toContainText(/live|polling|recovered/);
    await expect(page.getByTestId('overview-domain-card-knowledge_ingestion')).toBeVisible();
    await expect(page.getByTestId('overview-domain-card-knowledge_kg')).toBeVisible();
    await expect(page.getByTestId('overview-domain-card-mentor_audit')).toBeVisible();
    await expect(page.getByTestId('overview-domain-card-distribution')).toBeVisible();
    await expect(page.getByText('truthful placeholder')).toHaveCount(0);
  });

  test('renders one stale domain among fresh domains from the overview summary contract', async ({ page }) => {
    await loginViaUi(page, { expectedUrl: /\/overview$/ });

    const pattern = '**/api/admin/overview/summary';
    let intercepted = false;
    const handler = async (route: Route) => {
      if (intercepted || new URL(route.request().url()).pathname !== '/api/admin/overview/summary') {
        await route.continue();
        return;
      }

      intercepted = true;
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(
          buildOverviewSummaryPayload({
            mentorState: 'stale',
            mentorUpdatedAt: minutesAgo(32),
            transportMode: 'live',
          }),
        ),
      });
    };

    await page.route(pattern, handler);
    try {
      await page.getByTestId('overview-refresh-button').click();
    } finally {
      await page.unroute(pattern, handler);
    }

    expect(intercepted).toBe(true);
    await expect(page.getByTestId('overview-domain-state-mentor_audit')).toContainText('stale');
    await expect(page.getByTestId('overview-domain-state-distribution')).toContainText('fresh');
    await expect(page.getByTestId('overview-domain-next-action-mentor_audit')).toHaveAttribute(
      'href',
      '/mentor/audits?flag=blocked_fallback',
    );
  });

  test('falls back to polling after realtime loss, keeps the last good snapshot visible, and marks recovery', async ({
    page,
  }) => {
    await loginViaUi(page, { expectedUrl: /\/overview$/ });

    await page.context().setOffline(true);
    await expect(page.getByTestId('overview-polling-alert')).toBeVisible();
    await expect(page.getByTestId('overview-transport-mode')).toContainText('polling');
    await expect(page.getByTestId('overview-last-good-snapshot')).not.toContainText('—');
    await expect(page.getByTestId('overview-domain-card-knowledge_ingestion')).toBeVisible();

    await page.context().setOffline(false);
    await page.getByTestId('overview-resume-live').click();

    await expect(page.getByTestId('overview-recovery-alert')).toBeVisible();
    await expect(page.getByTestId('overview-transport-mode')).toContainText('recovered');
    await expect(page.getByTestId('overview-last-good-snapshot')).not.toContainText('—');
  });

  test('keeps the last good snapshot visible and surfaces contract failure on malformed summary refresh', async ({
    page,
  }) => {
    await loginViaUi(page, { expectedUrl: /\/overview$/ });
    await expect(page.getByTestId('overview-domain-card-knowledge_ingestion')).toBeVisible();

    const pattern = '**/api/admin/overview/summary';
    let intercepted = false;
    const handler = async (route: Route) => {
      if (intercepted || new URL(route.request().url()).pathname !== '/api/admin/overview/summary') {
        await route.continue();
        return;
      }

      intercepted = true;
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(buildMalformedOverviewSummaryPayload()),
      });
    };

    await page.route(pattern, handler);
    try {
      await page.getByTestId('overview-refresh-button').click();
    } finally {
      await page.unroute(pattern, handler);
    }

    expect(intercepted).toBe(true);
    await expect(page.getByTestId('overview-summary-error')).toContainText('invalid_response_payload');
    await expect(page.getByTestId('overview-domain-card-knowledge_ingestion')).toBeVisible();
    await expect(page.getByTestId('overview-control-strip')).toBeVisible();
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
    (response) => exactApiPath(response.url(), '/api/admin/auth/login') && response.request().method() === 'POST',
  );
  const meResponse = page.waitForResponse(
    (response) => exactApiPath(response.url(), '/api/admin/me') && response.request().method() === 'GET',
  );

  await page.getByLabel('用户名').fill(username);
  await page.getByLabel('密码').fill(password);
  await page.getByTestId('login-submit').click();

  expect((await loginResponse).status()).toBe(200);
  expect((await meResponse).status()).toBe(200);
  await expect(page).toHaveURL(options.expectedUrl);
  await expect(page.getByTestId('protected-shell')).toBeVisible();
}

function exactApiPath(rawUrl: string, pathname: string): boolean {
  return new URL(rawUrl).pathname === pathname;
}

function buildOverviewSummaryPayload(input: {
  transportMode: 'live' | 'polling_required';
  mentorState?: 'fresh' | 'stale' | 'degraded';
  mentorUpdatedAt?: string;
}) {
  const generatedAt = minutesAgo(1);
  const snapshotAt = minutesAgo(2);
  const mentorState = input.mentorState ?? 'fresh';
  const mentorUpdatedAt = input.mentorUpdatedAt ?? minutesAgo(4);
  const degradedDomainCount = mentorState === 'degraded' ? 1 : 0;

  return {
    generatedAt,
    lastSuccessfulSnapshotAt: snapshotAt,
    visibleDomainCount: 4,
    degradedDomainCount,
    transport: {
      eventId: 'evt-overview-summary-1',
      mode: input.transportMode,
      degradedReason: input.transportMode === 'polling_required' ? 'repository_timeout' : undefined,
      emittedAt: generatedAt,
      lastSuccessfulSnapshotAt: snapshotAt,
      activeSubscriberCount: 1,
      connectionCount: 1,
      reconnectCount: 0,
      replayed: false,
    },
    domains: [
      {
        key: 'knowledge_ingestion',
        title: 'Knowledge ingestion',
        requiredPermission: 'rag:read',
        visible: true,
        freshness: {
          state: 'all_clear',
          sourceUpdatedAt: minutesAgo(3),
          staleAfterSeconds: 900,
          degradedReason: undefined,
        },
        queue: {
          queueCount: 0,
          attentionCount: 0,
          allClear: true,
        },
        nextAction: {
          code: 'all_clear',
          label: 'All clear',
          href: '/knowledge-ops?view=ingestion&status=all',
        },
        counts: [
          { key: 'pending', value: 0 },
          { key: 'processing', value: 0 },
          { key: 'failed', value: 0 },
          { key: 'completed', value: 0 },
        ],
      },
      {
        key: 'knowledge_kg',
        title: 'Knowledge contradictions',
        requiredPermission: 'kg:read',
        visible: true,
        freshness: {
          state: 'fresh',
          sourceUpdatedAt: minutesAgo(5),
          staleAfterSeconds: 900,
          degradedReason: undefined,
        },
        queue: {
          queueCount: 2,
          attentionCount: 1,
          allClear: false,
        },
        nextAction: {
          code: 'review_escalated_contradictions',
          label: 'Review escalated contradictions',
          href: '/knowledge-ops?view=kg-review&status=escalated',
        },
        counts: [
          { key: 'open', value: 1 },
          { key: 'escalated', value: 1 },
          { key: 'unread_notifications', value: 1 },
          { key: 'resolved', value: 0 },
        ],
      },
      {
        key: 'mentor_audit',
        title: 'Mentor audit',
        requiredPermission: 'mentor:audit',
        visible: true,
        freshness: {
          state: mentorState,
          sourceUpdatedAt: mentorUpdatedAt,
          staleAfterSeconds: 900,
          degradedReason: mentorState === 'degraded' ? 'repository_timeout' : undefined,
        },
        queue: {
          queueCount: 1,
          attentionCount: 1,
          allClear: false,
        },
        nextAction: {
          code: 'review_blocked_fallback',
          label: 'Review blocked fallback incidents',
          href: '/mentor/audits?flag=blocked_fallback',
        },
        counts: [
          { key: 'flagged_incidents', value: 1 },
          { key: 'blocked_fallback', value: 1 },
          { key: 'rate_limited', value: 0 },
          { key: 'retryable', value: 0 },
        ],
      },
      {
        key: 'distribution',
        title: 'Distribution stats',
        requiredPermission: 'distribution:read',
        visible: true,
        freshness: {
          state: 'fresh',
          sourceUpdatedAt: minutesAgo(6),
          staleAfterSeconds: 1800,
          degradedReason: undefined,
        },
        queue: {
          queueCount: 1,
          attentionCount: 1,
          allClear: false,
        },
        nextAction: {
          code: 'inspect_distribution_failures',
          label: 'Inspect recent distribution failures',
          href: '/distribution/stats?range=30d',
        },
        counts: [
          { key: 'release_total_events', value: 12 },
          { key: 'release_failure_events', value: 1 },
          { key: 'share_total_events', value: 6 },
          { key: 'share_failure_events', value: 0 },
        ],
      },
    ],
  };
}

function buildMalformedOverviewSummaryPayload() {
  const payload = buildOverviewSummaryPayload({
    transportMode: 'live',
  }) as Record<string, unknown>;
  const domains = payload.domains as Array<Record<string, unknown>>;
  const brokenFreshness = {
    ...(domains[0].freshness as Record<string, unknown>),
    state: 'mystery_state',
  };
  domains[0] = {
    ...domains[0],
    freshness: brokenFreshness,
  };
  payload.domains = domains;
  return payload;
}

function minutesAgo(minutes: number): string {
  return new Date(Date.now() - minutes * 60_000).toISOString();
}
