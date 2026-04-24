/// <reference types="node" />

import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { expect, test, type Page, type Response } from '@playwright/test';
import { createAdminWithPermissions, sessionStorageKey } from './helpers/admin-api';

const currentDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(currentDir, '..', '..');
const trackedPdfPath = path.resolve(repoRoot, 'backend/admin-api/src/test/resources/knowledge-upload.pdf');

test.describe('knowledge ops workspace', () => {
  test('handles real ingestion upload/retry and KG resolve/read while keeping URL context visible', async ({ page }) => {
    const suffix = uniqueSuffix();
    const seededContradiction = seedKnowledgeGraphFixture(suffix);

    await loginViaUi(page);
    await page.goto('/knowledge-ops?view=ingestion&status=all');

    await expect(page.getByTestId('knowledge-ops-page')).toBeVisible();
    await expect(page.getByTestId('knowledge-ingestion-queue')).toBeVisible();
    await expect(page.getByTestId('knowledge-inline-diagnostics')).toBeVisible();

    const uploadResponsePromise = page.waitForResponse(
      (response) => exactApiPath(response, '/api/admin/knowledge/ingestion/upload') && response.request().method() === 'POST',
    );
    await page.getByTestId('knowledge-upload-book-title').fill(`Playwright Knowledge Ops ${suffix}`);
    await page.getByTestId('knowledge-upload-file').setInputFiles(trackedPdfPath);
    await page.getByTestId('knowledge-upload-submit').click();

    const uploadResponse = await uploadResponsePromise;
    expect(uploadResponse.status()).toBe(202);
    const uploadPayload = (await uploadResponse.json()) as { jobId: string; status: string };
    const jobId = uploadPayload.jobId;

    await expect.poll(() => new URL(page.url()).searchParams.get('selected')).toBe(jobId);
    await expect(page.getByTestId('knowledge-ingestion-feedback')).toContainText(jobId);
    await expect
      .poll(
        async () => (await page.getByTestId('knowledge-ingestion-status').textContent())?.trim(),
        { timeout: 60_000 },
      )
      .toBe('COMPLETED');

    forceIngestionJobFailed(jobId, `forced FAILED by knowledge-ops.spec ${suffix}`);
    const reloadQueuePromise = page.waitForResponse(
      (response) => exactApiPath(response, '/api/admin/knowledge/ingestion/jobs') && response.request().method() === 'GET',
    );
    await page.getByTestId('knowledge-ingestion-reload').click();
    expect((await reloadQueuePromise).status()).toBe(200);
    await expect
      .poll(
        async () => (await page.getByTestId('knowledge-ingestion-status').textContent())?.trim(),
        { timeout: 20_000 },
      )
      .toBe('FAILED');
    await expect(page.getByTestId('knowledge-retry-job')).toBeVisible();
    await expect(page.getByTestId('knowledge-ingestion-feedback')).toContainText('forced FAILED by knowledge-ops.spec');

    const retryResponsePromise = page.waitForResponse(
      (response) =>
        exactApiPath(response, `/api/admin/knowledge/ingestion/jobs/${jobId}/retry`) &&
        response.request().method() === 'POST',
    );
    await page.getByTestId('knowledge-retry-job').click();
    const retryResponse = await retryResponsePromise;
    expect(retryResponse.status()).toBe(202);
    await expect(page.getByTestId('knowledge-ingestion-feedback')).toContainText(jobId);
    await expect
      .poll(
        async () => (await page.getByTestId('knowledge-ingestion-status').textContent())?.trim(),
        { timeout: 60_000 },
      )
      .toBe('COMPLETED');

    const kgQueuePromise = page.waitForResponse(
      (response) => exactApiPath(response, '/api/admin/knowledge/kg/contradictions') && response.request().method() === 'GET',
    );
    const kgDetailPromise = page.waitForResponse(
      (response) =>
        exactApiPath(response, `/api/admin/knowledge/kg/contradictions/${seededContradiction.contradictionId}`) &&
        response.request().method() === 'GET',
    );
    const notificationPromise = page.waitForResponse(
      (response) =>
        exactApiPath(
          response,
          `/api/admin/knowledge/kg/contradictions/${seededContradiction.contradictionId}/notifications`,
        ) && response.request().method() === 'GET',
    );
    await page.goto(
      `/knowledge-ops?view=kg-review&status=escalated&selected=${encodeURIComponent(seededContradiction.contradictionId)}`,
    );
    expect((await kgQueuePromise).status()).toBe(200);
    expect((await kgDetailPromise).status()).toBe(200);
    expect((await notificationPromise).status()).toBe(200);

    await expect(page.getByTestId('knowledge-contradiction-list')).toBeVisible();
    await expect(page.getByTestId('knowledge-notification-list')).toBeVisible();
    await expect(page.getByTestId('knowledge-kg-status')).toContainText('escalated');
    await expect(page.getByTestId(`knowledge-notification-row-${seededContradiction.notificationId}`)).toBeVisible();
    await expect(page.getByTestId('knowledge-resolve-submit')).toBeEnabled();

    const resolveResponsePromise = page.waitForResponse(
      (response) =>
        exactApiPath(
          response,
          `/api/admin/knowledge/kg/contradictions/${seededContradiction.contradictionId}/resolve`,
        ) && response.request().method() === 'PATCH',
    );
    await page.getByTestId('knowledge-resolve-notes').fill(`manual_resolution_${suffix}`);
    await page.getByTestId('knowledge-resolve-submit').click();
    expect((await resolveResponsePromise).status()).toBe(200);

    await expect(page.getByTestId('knowledge-kg-feedback')).toContainText('resolved');
    await expect(page.getByTestId('knowledge-kg-feedback')).toContainText(`manual_resolution_${suffix}`);
    await expect.poll(() => new URL(page.url()).searchParams.get('status')).toBe('escalated');
    await expect.poll(() => new URL(page.url()).searchParams.get('selected')).toBe(seededContradiction.contradictionId);
    await expect(page.getByTestId('knowledge-kg-selected-missing')).toBeVisible();
    await expect(page.getByTestId('knowledge-notification-list')).toBeVisible();

    const markReadResponsePromise = page.waitForResponse(
      (response) =>
        exactApiPath(
          response,
          `/api/admin/knowledge/kg/notifications/${seededContradiction.notificationId}/read`,
        ) && response.request().method() === 'PATCH',
    );
    await page.getByTestId(`knowledge-notification-read-${seededContradiction.notificationId}`).click();
    expect((await markReadResponsePromise).status()).toBe(200);
    await expect(page.getByTestId('knowledge-kg-feedback')).toContainText(seededContradiction.notificationId);
    await expect(page.getByTestId(`knowledge-notification-row-${seededContradiction.notificationId}`)).toContainText('read');
  });

  test('keeps sub-surface visibility scoped to the admin capability actually granted', async ({ page, request }) => {
    const suffix = uniqueSuffix();
    const failedJobId = seedIngestionJobFixture(suffix);
    const seededContradiction = seedKnowledgeGraphFixture(`readonly-${suffix}`);
    const ragReader = await createAdminWithPermissions(request, ['rag:read'], 'RAG Reader Only');
    const kgReader = await createAdminWithPermissions(request, ['kg:read'], 'KG Reader Only');

    await loginViaUi(page, ragReader.username, ragReader.password);
    await page.goto(
      `/knowledge-ops?view=kg-review&status=FAILED&selected=${encodeURIComponent(failedJobId)}`,
    );

    await expect(page.getByTestId('knowledge-view-normalized')).toBeVisible();
    await expect(page.getByTestId('knowledge-ingestion-queue')).toBeVisible();
    await expect(page.getByTestId('knowledge-contradiction-list')).toHaveCount(0);
    await expect(page.getByTestId('knowledge-ingestion-readonly-note')).toBeVisible();
    await expect(page.getByTestId('knowledge-upload-submit')).toHaveCount(0);
    await expect(page.getByTestId('knowledge-retry-job')).toHaveCount(0);
    await expect(page.getByTestId('knowledge-ingestion-status')).toContainText('FAILED');

    await loginViaUi(page, kgReader.username, kgReader.password);
    await page.goto(
      `/knowledge-ops?view=ingestion&status=escalated&selected=${encodeURIComponent(seededContradiction.contradictionId)}`,
    );

    await expect(page.getByTestId('knowledge-view-normalized')).toBeVisible();
    await expect(page.getByTestId('knowledge-ingestion-queue')).toHaveCount(0);
    await expect(page.getByTestId('knowledge-contradiction-list')).toBeVisible();
    await expect(page.getByTestId('knowledge-notification-list')).toBeVisible();
    await expect(page.getByTestId('knowledge-kg-readonly-note')).toBeVisible();
    await expect(page.getByTestId('knowledge-resolve-submit')).toBeDisabled();
    await expect(page.getByTestId(`knowledge-notification-read-${seededContradiction.notificationId}`)).toHaveCount(0);
  });
});

async function loginViaUi(page: Page, username = 'super_admin', password = 'SuperAdmin123!') {
  await page.goto('/login');
  await page.evaluate((storageKey) => window.localStorage.removeItem(storageKey), sessionStorageKey);

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

function exactApiPath(response: Response, pathname: string): boolean {
  return new URL(response.url()).pathname === pathname;
}

function seedIngestionJobFixture(label: string): string {
  const jobId = randomUUID();
  runSql(`
    insert into ingestion_jobs (
      id,
      original_filename,
      minio_object_key,
      status,
      total_chunks,
      error_message,
      created_at,
      updated_at
    ) values (
      ${sqlLiteral(jobId)},
      ${sqlLiteral(`forced-${label}.pdf`)},
      ${sqlLiteral(`ingestion/private/${jobId}.pdf`)},
      'FAILED',
      0,
      ${sqlLiteral(`forced failure ${label}`)},
      current_timestamp - interval '5 minutes',
      current_timestamp - interval '1 minute'
    );
  `);
  return jobId;
}

function forceIngestionJobFailed(jobId: string, errorMessage: string) {
  runSql(`
    update ingestion_jobs
       set status = 'FAILED',
           error_message = ${sqlLiteral(errorMessage)},
           updated_at = current_timestamp
     where id = ${sqlLiteral(jobId)};
  `);
}

function seedKnowledgeGraphFixture(label: string) {
  const contradictionId = randomUUID();
  const notificationId = randomUUID();
  const sourceEntityId = randomUUID();
  const targetEntityId = randomUUID();
  const relationshipAId = randomUUID();
  const relationshipBId = randomUUID();

  runSql(`
    insert into kg_entities (id, name, entity_type, description)
    values
      (${sqlLiteral(sourceEntityId)}, ${sqlLiteral(`topic-source-${label}`)}, 'concept', ${sqlLiteral(`desc-source-${label}`)}),
      (${sqlLiteral(targetEntityId)}, ${sqlLiteral(`topic-target-${label}`)}, 'concept', ${sqlLiteral(`desc-target-${label}`)});

    insert into kg_relationships (
      id,
      source_entity_id,
      target_entity_id,
      relation_type,
      source_book,
      context_note
    ) values
      (
        ${sqlLiteral(relationshipAId)},
        ${sqlLiteral(sourceEntityId)},
        ${sqlLiteral(targetEntityId)},
        'contradicts',
        ${sqlLiteral(`source-a-${label}.pdf`)},
        ${sqlLiteral(`context-a-${label}`)}
      ),
      (
        ${sqlLiteral(relationshipBId)},
        ${sqlLiteral(sourceEntityId)},
        ${sqlLiteral(targetEntityId)},
        'contradicts',
        ${sqlLiteral(`source-b-${label}.pdf`)},
        ${sqlLiteral(`context-b-${label}`)}
      );

    insert into kg_contradictions (
      id,
      entity_topic,
      relationship_a_id,
      relationship_b_id,
      source_a_book,
      source_b_book,
      description,
      status,
      agent_review_result,
      admin_notes,
      detected_at,
      reviewed_at,
      resolved_at
    ) values (
      ${sqlLiteral(contradictionId)},
      ${sqlLiteral(`sleep-topic-${label}`)},
      ${sqlLiteral(relationshipAId)},
      ${sqlLiteral(relationshipBId)},
      ${sqlLiteral(`source-a-${label}.pdf`)},
      ${sqlLiteral(`source-b-${label}.pdf`)},
      ${sqlLiteral(`需要人工确认的矛盾 ${label}`)},
      'escalated',
      ${sqlLiteral('{"verdict":"escalated"}')},
      null,
      current_timestamp - interval '6 minutes',
      current_timestamp - interval '5 minutes',
      null
    );

    insert into kg_admin_notifications (
      id,
      contradiction_id,
      notification_type,
      message,
      is_read,
      created_at
    ) values (
      ${sqlLiteral(notificationId)},
      ${sqlLiteral(contradictionId)},
      'contradiction_escalated',
      ${sqlLiteral(`管理员通知 ${label}`)},
      false,
      current_timestamp - interval '4 minutes'
    );
  `);

  return {
    contradictionId,
    notificationId,
  };
}

function runSql(sql: string) {
  const result = spawnSync(
    'docker',
    ['compose', 'exec', '-T', 'postgres', 'psql', '-U', 'babytalk', '-d', 'babytalk', '-v', 'ON_ERROR_STOP=1', '-c', sql],
    {
      cwd: repoRoot,
      encoding: 'utf-8',
      stdio: 'pipe',
    },
  );

  if (result.status !== 0) {
    throw new Error(
      `[knowledge-ops sql] failed with status ${result.status ?? 'unknown'}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`,
    );
  }
}

function sqlLiteral(value: string | null): string {
  if (value === null) {
    return 'null';
  }
  return `'${value.replace(/'/g, "''")}'`;
}

function uniqueSuffix(): string {
  return `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
}
