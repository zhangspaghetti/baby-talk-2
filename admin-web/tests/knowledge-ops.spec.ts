/// <reference types="node" />

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { expect, test, type Page, type Response } from '@playwright/test';
import {
  adminApiBaseUrl,
  createAdminWithPermissions,
  loginViaAdminApi,
  repointIngestionJobToSourceObject,
  seedFailedIngestionJobFixture,
  seedKnowledgeGraphFixture,
  sessionStorageKey,
} from './helpers/admin-api';

const currentDir = path.dirname(fileURLToPath(import.meta.url));
const validPdfPath = path.resolve(currentDir, 'fixtures', 'knowledge-upload.pdf');
const badPdfPath = path.resolve(currentDir, 'fixtures', 'knowledge-bad.pdf');
const POLL_SETTLE_WAIT_MS = 3_500;

test.describe('knowledge ops workspace', () => {
  test('handles real ingestion upload/failure/retry and KG mark-read/resolve while keeping context inline', async ({
    page,
  }) => {
    const suffix = uniqueSuffix();
    const seededContradiction = seedKnowledgeGraphFixture(suffix);
    const apiTraffic = trackResponses(page, (response) => new URL(response.url()).pathname.startsWith('/api/'));
    const ingestionReads = trackResponses(
      page,
      (response) =>
        response.request().method() === 'GET' &&
        new URL(response.url()).pathname.startsWith('/api/admin/knowledge/ingestion/jobs'),
    );

    try {
      await loginViaUi(page);
      await page.goto('/knowledge-ops?view=ingestion&status=all');

      await expect(page.getByTestId('knowledge-ops-page')).toBeVisible();
      await expect(page.getByTestId('knowledge-ingestion-queue')).toBeVisible();
      await expect(page.getByTestId('knowledge-inline-diagnostics')).toBeVisible();

      const uploadSuccessResponse = page.waitForResponse(
        (response) => exactApiPath(response, '/api/admin/knowledge/ingestion/upload') && response.request().method() === 'POST',
      );
      await page.getByTestId('knowledge-upload-book-title').fill(`Playwright Knowledge Success ${suffix}`);
      await page.getByTestId('knowledge-upload-file').setInputFiles(validPdfPath);
      await page.getByTestId('knowledge-upload-submit').click();

      const uploadSuccessPayload = (await (await uploadSuccessResponse).json()) as {
        jobId: string;
        status: string;
      };
      const successfulJobId = uploadSuccessPayload.jobId;
      expect(['PENDING', 'PROCESSING']).toContain(uploadSuccessPayload.status);

      await expect.poll(() => new URL(page.url()).searchParams.get('selected')).toBe(successfulJobId);
      await expect(page.getByTestId('knowledge-ingestion-feedback')).toContainText(successfulJobId);
      await expect
        .poll(async () => (await page.getByTestId('knowledge-ingestion-status').textContent())?.trim(), {
          timeout: 60_000,
        })
        .toBe('COMPLETED');
      await expect(page.getByTestId('knowledge-ingestion-feedback')).toContainText('上传任务已完成');
      await expect(page.getByTestId('knowledge-ingestion-feedback')).toContainText('COMPLETED');

      await expectIngestionSelectionToStayStable(
        page,
        ingestionReads,
        ingestionReads.events.length,
        successfulJobId,
        'COMPLETED',
      );
      expect(ingestionReads.events.length).toBeGreaterThan(0);

      const uploadFailureResponse = page.waitForResponse(
        (response) => exactApiPath(response, '/api/admin/knowledge/ingestion/upload') && response.request().method() === 'POST',
      );
      await page.getByTestId('knowledge-upload-book-title').fill(`Playwright Knowledge Failure ${suffix}`);
      await page.getByTestId('knowledge-upload-file').setInputFiles(badPdfPath);
      await page.getByTestId('knowledge-upload-submit').click();

      const uploadFailurePayload = (await (await uploadFailureResponse).json()) as {
        jobId: string;
        status: string;
      };
      const failedJobId = uploadFailurePayload.jobId;
      expect(['PENDING', 'PROCESSING']).toContain(uploadFailurePayload.status);

      await expect.poll(() => new URL(page.url()).searchParams.get('selected')).toBe(failedJobId);
      await expect
        .poll(async () => (await page.getByTestId('knowledge-ingestion-status').textContent())?.trim(), {
          timeout: 60_000,
        })
        .toBe('FAILED');
      await expect(page.getByTestId('knowledge-ingestion-feedback')).toContainText('上传任务已失败');
      await expect(page.getByTestId('knowledge-ingestion-feedback')).toContainText(failedJobId);
      await expect
        .poll(async () => (await page.getByTestId('knowledge-ingestion-feedback').textContent()) ?? '', {
          timeout: 10_000,
        })
        .toMatch(/errorMessage=(PARSE|SPLIT):/);
      await expect(page.getByTestId('knowledge-retry-job')).toBeVisible();

      repointIngestionJobToSourceObject(failedJobId, successfulJobId);

      const retryResponsePromise = page.waitForResponse(
        (response) =>
          exactApiPath(response, `/api/admin/knowledge/ingestion/jobs/${failedJobId}/retry`) &&
          response.request().method() === 'POST',
      );
      await page.getByTestId('knowledge-retry-job').click();

      const retryPayload = (await (await retryResponsePromise).json()) as {
        jobId: string;
        status: string;
      };
      expect(retryPayload.jobId).toBe(failedJobId);
      expect(['PENDING', 'PROCESSING']).toContain(retryPayload.status);
      await expect.poll(() => new URL(page.url()).searchParams.get('selected')).toBe(failedJobId);
      await expect.poll(() => new URL(page.url()).searchParams.get('status')).toBe('all');
      await expect
        .poll(async () => (await page.getByTestId('knowledge-ingestion-status').textContent())?.trim(), {
          timeout: 60_000,
        })
        .toBe('COMPLETED');
      await expect(page.getByTestId('knowledge-ingestion-feedback')).toContainText('retry 已完成');
      await expect(page.getByTestId('knowledge-ingestion-feedback')).toContainText(failedJobId);

      await expectIngestionSelectionToStayStable(
        page,
        ingestionReads,
        ingestionReads.events.length,
        failedJobId,
        'COMPLETED',
      );

      const kgQueueResponse = page.waitForResponse(
        (response) => exactApiPath(response, '/api/admin/knowledge/kg/contradictions') && response.request().method() === 'GET',
      );
      const kgDetailResponse = page.waitForResponse(
        (response) =>
          exactApiPath(response, `/api/admin/knowledge/kg/contradictions/${seededContradiction.contradictionId}`) &&
          response.request().method() === 'GET',
      );
      const notificationListResponse = page.waitForResponse(
        (response) =>
          exactApiPath(
            response,
            `/api/admin/knowledge/kg/contradictions/${seededContradiction.contradictionId}/notifications`,
          ) && response.request().method() === 'GET',
      );

      await page.goto(
        `/knowledge-ops?view=kg-review&status=escalated&selected=${encodeURIComponent(seededContradiction.contradictionId)}`,
      );

      expect((await kgQueueResponse).status()).toBe(200);
      expect((await kgDetailResponse).status()).toBe(200);
      expect((await notificationListResponse).status()).toBe(200);

      await expect(page.getByTestId('knowledge-contradiction-list')).toBeVisible();
      await expect(page.getByTestId('knowledge-notification-list')).toBeVisible();
      await expect(page.getByTestId('knowledge-kg-status')).toContainText('escalated');
      await expect(page.getByTestId(`knowledge-kg-row-${seededContradiction.contradictionId}`)).toContainText('unread 1');
      await expect(page.getByTestId(`knowledge-notification-row-${seededContradiction.notificationId}`)).toBeVisible();

      const markReadResponse = page.waitForResponse(
        (response) =>
          exactApiPath(response, `/api/admin/knowledge/kg/notifications/${seededContradiction.notificationId}/read`) &&
          response.request().method() === 'PATCH',
      );
      await page.getByTestId(`knowledge-notification-read-${seededContradiction.notificationId}`).click();
      expect((await markReadResponse).status()).toBe(200);

      await expect(page.getByTestId('knowledge-kg-feedback')).toContainText(seededContradiction.notificationId);
      await expect(page.getByTestId(`knowledge-notification-row-${seededContradiction.notificationId}`)).toContainText('read');
      await expect(page.getByTestId(`knowledge-kg-row-${seededContradiction.contradictionId}`)).toContainText('unread 0');
      await expect.poll(() => new URL(page.url()).searchParams.get('status')).toBe('escalated');
      await expect.poll(() => new URL(page.url()).searchParams.get('selected')).toBe(seededContradiction.contradictionId);

      const resolveResponse = page.waitForResponse(
        (response) =>
          exactApiPath(response, `/api/admin/knowledge/kg/contradictions/${seededContradiction.contradictionId}/resolve`) &&
          response.request().method() === 'PATCH',
      );
      await page.getByTestId('knowledge-resolve-notes').fill(`manual_resolution_${suffix}`);
      await page.getByTestId('knowledge-resolve-submit').click();
      expect((await resolveResponse).status()).toBe(200);

      await expect(page.getByTestId('knowledge-kg-feedback')).toContainText('resolved');
      await expect(page.getByTestId('knowledge-kg-feedback')).toContainText(`manual_resolution_${suffix}`);
      await expect(page.getByTestId('knowledge-kg-status')).toContainText('resolved');
      await expect.poll(() => new URL(page.url()).searchParams.get('status')).toBe('escalated');
      await expect.poll(() => new URL(page.url()).searchParams.get('selected')).toBe(seededContradiction.contradictionId);
      await expect(page.getByTestId('knowledge-kg-selected-missing')).toBeVisible();
      await expect(page.getByTestId(`knowledge-kg-row-${seededContradiction.contradictionId}`)).toHaveCount(0);
      await expect(page.getByTestId('knowledge-notification-list')).toBeVisible();

      const nonAdminApiPaths = [...new Set(apiTraffic.events.map((event) => event.path))].filter(
        (path) => path.startsWith('/api/') && !path.startsWith('/api/admin/'),
      );
      expect(nonAdminApiPaths).toEqual([]);

      const knowledgePaths = apiTraffic.events
        .map((event) => event.path)
        .filter((path) => path.includes('/knowledge/'));
      expect(knowledgePaths.length).toBeGreaterThan(0);
      expect(knowledgePaths.every((path) => path.startsWith('/api/admin/knowledge/'))).toBe(true);
    } finally {
      apiTraffic.stop();
      ingestionReads.stop();
    }
  });

  test('keeps sub-surface visibility scoped to the admin capability actually granted and forbids deep-link mutations', async ({
    page,
    request,
  }) => {
    const suffix = uniqueSuffix();
    const failedJobId = seedFailedIngestionJobFixture(suffix);
    const seededContradiction = seedKnowledgeGraphFixture(`readonly-${suffix}`);
    const ragReader = await createAdminWithPermissions(request, ['rag:read'], 'RAG Reader Only');
    const kgReader = await createAdminWithPermissions(request, ['kg:read'], 'KG Reader Only');

    const ragReaderSession = await loginViaAdminApi(request, ragReader.username, ragReader.password);
    const ragRetryResponse = await request.post(`${adminApiBaseUrl}/api/admin/knowledge/ingestion/jobs/${failedJobId}/retry`, {
      headers: {
        Authorization: `Bearer ${ragReaderSession.accessToken}`,
      },
    });
    expect(ragRetryResponse.status()).toBe(403);
    expect(((await ragRetryResponse.json()) as { code: string }).code).toBe('forbidden');

    await loginViaUi(page, ragReader.username, ragReader.password);
    await page.goto(`/knowledge-ops?view=kg-review&status=FAILED&selected=${encodeURIComponent(failedJobId)}`);

    await expect(page.getByTestId('knowledge-view-normalized')).toBeVisible();
    await expect(page.getByTestId('knowledge-ingestion-queue')).toBeVisible();
    await expect(page.getByTestId('knowledge-contradiction-list')).toHaveCount(0);
    await expect(page.getByTestId('knowledge-ingestion-readonly-note')).toBeVisible();
    await expect(page.getByTestId('knowledge-upload-submit')).toHaveCount(0);
    await expect(page.getByTestId('knowledge-retry-job')).toHaveCount(0);
    await expect(page.getByTestId('knowledge-ingestion-status')).toContainText('FAILED');

    const kgReaderSession = await loginViaAdminApi(request, kgReader.username, kgReader.password);
    const kgResolveResponse = await request.patch(
      `${adminApiBaseUrl}/api/admin/knowledge/kg/contradictions/${seededContradiction.contradictionId}/resolve`,
      {
        headers: {
          Authorization: `Bearer ${kgReaderSession.accessToken}`,
          'Content-Type': 'application/json',
        },
        data: {
          adminNotes: 'forbidden_write',
        },
      },
    );
    expect(kgResolveResponse.status()).toBe(403);
    expect(((await kgResolveResponse.json()) as { code: string }).code).toBe('forbidden');

    await loginViaUi(page, kgReader.username, kgReader.password);
    await page.goto(
      `/knowledge-ops?view=ingestion&status=escalated&selected=${encodeURIComponent(seededContradiction.contradictionId)}`,
    );

    await expect(page.getByTestId('knowledge-view-normalized')).toBeVisible();
    await expect(page.getByTestId('knowledge-ingestion-queue')).toHaveCount(0);
    await expect(page.getByTestId('knowledge-contradiction-list')).toBeVisible();
    await expect(page.getByTestId('knowledge-notification-list')).toBeVisible();
    await expect(page.getByTestId('knowledge-kg-readonly-note')).toBeVisible();
    await expect(page.getByTestId('knowledge-kg-status')).toContainText('escalated');
    await expect(page.getByTestId('knowledge-resolve-submit')).toBeDisabled();
    await expect(page.getByTestId(`knowledge-notification-read-${seededContradiction.notificationId}`)).toHaveCount(0);
  });
});

async function loginViaUi(page: Page, username: string = 'super_admin', password: string = 'SuperAdmin123!') {
  await page.goto('/login');
  await page.evaluate((storageKey) => window.localStorage.removeItem(storageKey), sessionStorageKey);
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
  await expect(page).toHaveURL(/\/overview$|\/users$|\/knowledge-ops(?:\?.*)?$|\/mentor\/audits$|\/distribution\/stats(?:\?.*)?$/);
  await expect(page.getByTestId('protected-shell')).toBeVisible();
}

async function expectIngestionSelectionToStayStable(
  page: Page,
  tracker: { events: Array<{ path: string; status: number; method: string }> },
  baselineCount: number,
  selectedJobId: string,
  expectedStatus: 'COMPLETED' | 'FAILED',
) {
  await page.waitForTimeout(POLL_SETTLE_WAIT_MS);
  expect(tracker.events.length).toBeGreaterThanOrEqual(baselineCount);
  await expect.poll(() => new URL(page.url()).searchParams.get('selected')).toBe(selectedJobId);
  await expect(page.getByTestId('knowledge-ingestion-status')).toContainText(expectedStatus);
  await expect(page.getByTestId('knowledge-ingestion-feedback')).toContainText(selectedJobId);
  await expect(page.getByTestId('knowledge-ingestion-stale')).toHaveCount(0);
}

function trackResponses(page: Page, matcher: (response: Response) => boolean) {
  const events: Array<{ path: string; status: number; method: string }> = [];
  const listener = (response: Response) => {
    if (!matcher(response)) {
      return;
    }

    const request = response.request();
    events.push({
      path: new URL(response.url()).pathname,
      status: response.status(),
      method: request.method(),
    });
  };

  page.on('response', listener);

  return {
    events,
    stop: () => page.off('response', listener),
  };
}

function exactApiPath(response: Response, pathname: string): boolean {
  return new URL(response.url()).pathname === pathname;
}

function uniqueSuffix(): string {
  return `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
}
