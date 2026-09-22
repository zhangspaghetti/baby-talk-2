import { expect, test, type Page, type Response } from '@playwright/test';
import {
  adminPresetScenesApiPath,
  createAdminWithPermissions,
  createPresetSceneDraft,
  getPresetScene,
  loginViaAdminApi,
  publishPresetScene,
  seedPresetSceneFixture,
  updatePresetSceneDraft,
  type PresetSceneDraftFixture,
} from './helpers/admin-api';

test.describe('preset-scene workbench', () => {
  test('lists a unique scene and edits/saves its draft with the server lock version', async ({ page, request }) => {
    const scene = seedPresetSceneFixture(`edit-${uniqueSuffix()}`);
    await loginViaUi(page);
    await gotoPresetScenes(page);

    await expect(page.getByTestId(`preset-scene-row-${scene.presetSceneId}`)).toBeVisible();
    await page.getByTestId(`preset-scene-edit-${scene.presetSceneId}`).click();
    await expect(page.getByRole('dialog')).toBeVisible();

    const createResponse = page.waitForResponse(
      (response) =>
        exactApiPath(response, `${adminPresetScenesApiPath}/${scene.presetSceneId}/draft`) &&
        response.request().method() === 'POST',
    );
    await page.getByRole('button', { name: '创建草稿', exact: true }).click();
    expect((await createResponse).status()).toBe(201);

    await page.getByLabel('title', { exact: true }).fill(`${scene.title} edited`);
    const saveRequest = page.waitForRequest(
      (requestEvent) =>
        new URL(requestEvent.url()).pathname === `${adminPresetScenesApiPath}/${scene.presetSceneId}/draft` &&
        requestEvent.method() === 'PUT',
    );
    const saveResponse = page.waitForResponse(
      (response) =>
        exactApiPath(response, `${adminPresetScenesApiPath}/${scene.presetSceneId}/draft`) &&
        response.request().method() === 'PUT',
    );
    await page.getByRole('button', { name: '保存草稿', exact: true }).click();
    const requestBody = saveRequest;
    expect((await requestBody).postDataJSON()).toMatchObject({ lockVersion: 0 });
    expect((await saveResponse).status()).toBe(200);
    await expect(page.getByTestId('preset-scene-mutation-feedback')).toContainText('草稿已保存');

    const adminSession = await loginViaAdminApi(request);
    const detail = await getPresetScene(request, adminSession.accessToken, scene.presetSceneId);
    expect(detail).toMatchObject({ draft: { title: `${scene.title} edited`, lockVersion: 1 } });
  });

  test('shows client validation and a server failure without losing the draft values', async ({ page }) => {
    const scene = seedPresetSceneFixture(`validation-${uniqueSuffix()}`);
    await loginViaUi(page);
    await gotoPresetScenes(page);
    await page.getByTestId(`preset-scene-edit-${scene.presetSceneId}`).click();
    await page.getByRole('button', { name: '创建草稿', exact: true }).click();

    await page.getByLabel('title', { exact: true }).fill('');
    await page.getByRole('button', { name: '保存草稿', exact: true }).click();
    await expect(page.getByText('title 不能为空。', { exact: true })).toBeVisible();

    await page.getByLabel('title', { exact: true }).fill(`${scene.title} server failure`);
    const draftPath = `${adminPresetScenesApiPath}/${scene.presetSceneId}/draft`;
    await page.route(`**${draftPath}`, async (route) => {
      if (route.request().method() === 'PUT') {
        await route.fulfill({
          status: 500,
          contentType: 'application/json',
          body: JSON.stringify({ status: 500, code: 'practice_draft_save_failed', message: 'forced draft failure' }),
        });
        return;
      }
      await route.continue();
    });
    await page.getByRole('button', { name: '保存草稿', exact: true }).click();
    await expect(page.getByTestId('preset-scene-mutation-feedback')).toContainText('forced draft failure');
    await expect(page.getByLabel('title', { exact: true })).toHaveValue(`${scene.title} server failure`);
  });

  test('reloads the server draft on stale conflict while preserving unsaved form values for comparison', async ({
    page,
    request,
  }) => {
    const scene = seedPresetSceneFixture(`stale-${uniqueSuffix()}`);
    const session = await loginViaAdminApi(request);
    const draft = draftFor(scene, { lockVersion: 0 });
    await createPresetSceneDraft(request, session.accessToken, scene.presetSceneId, draft);

    await loginViaUi(page);
    await gotoPresetScenes(page);
    await page.getByTestId(`preset-scene-edit-${scene.presetSceneId}`).click();
    await page.getByLabel('title', { exact: true }).fill(`${scene.title} local unsaved`);

    await updatePresetSceneDraft(request, session.accessToken, scene.presetSceneId, {
      ...draft,
      title: `${scene.title} server changed`,
      lockVersion: 0,
    });

    await page.getByRole('button', { name: '保存草稿', exact: true }).click();
    await expect(page.getByTestId('preset-scene-mutation-feedback')).toContainText('practice_draft_version_conflict');
    await expect(page.getByTestId('preset-scene-conflict')).toBeVisible();
    await expect(page.getByLabel('title', { exact: true })).toHaveValue(`${scene.title} local unsaved`);
    await expect(page.getByTestId('preset-scene-conflict-title')).toContainText('server:');
    await expect(page.getByTestId('preset-scene-conflict-title')).toContainText('server changed');
  });

  test('publishes a draft and shows the published status', async ({ page, request }) => {
    const scene = seedPresetSceneFixture(`publish-${uniqueSuffix()}`);
    const session = await loginViaAdminApi(request);
    await createPresetSceneDraft(request, session.accessToken, scene.presetSceneId, draftFor(scene));

    await loginViaUi(page);
    await gotoPresetScenes(page);
    await page.getByTestId(`preset-scene-edit-${scene.presetSceneId}`).click();
    const publishResponse = page.waitForResponse(
      (response) =>
        exactApiPath(response, `${adminPresetScenesApiPath}/${scene.presetSceneId}/publish`) &&
        response.request().method() === 'POST',
    );
    await page.getByRole('button', { name: '发布版本', exact: true }).click();
    expect((await publishResponse).status()).toBe(200);

    const row = sceneRow(page, scene.presetSceneId);
    await expect(row).toContainText('published v2');
    await expect(row).toContainText('no draft');
  });

  test('publishes a disabled draft as an explicit disabled scene', async ({ page, request }) => {
    const scene = seedPresetSceneFixture(`disable-${uniqueSuffix()}`);
    const session = await loginViaAdminApi(request);
    await createPresetSceneDraft(
      request,
      session.accessToken,
      scene.presetSceneId,
      draftFor(scene, { enabled: false }),
    );

    await loginViaUi(page);
    await gotoPresetScenes(page);
    await page.getByTestId(`preset-scene-edit-${scene.presetSceneId}`).click();
    await page.getByRole('button', { name: '发布版本', exact: true }).click();

    await expect(sceneRow(page, scene.presetSceneId)).toContainText('published v2 · disabled');
    await expect(page.getByTestId('preset-scene-mutation-feedback')).toContainText('已停用并发布');
  });

  test('opens version history and rolls back by creating a new published version', async ({ page, request }) => {
    const scene = seedPresetSceneFixture(`history-${uniqueSuffix()}`);
    const session = await loginViaAdminApi(request);
    const created = await createPresetSceneDraft(request, session.accessToken, scene.presetSceneId, draftFor(scene));
    const lockVersion = Number(created.lockVersion);
    await publishPresetScene(request, session.accessToken, scene.presetSceneId, lockVersion);

    await loginViaUi(page);
    await gotoPresetScenes(page);
    await page.getByTestId(`preset-scene-history-${scene.presetSceneId}`).click();
    const history = page.getByRole('dialog', { name: /版本历史/ });
    await expect(history).toBeVisible();
    await expect(history).toContainText('v1');
    await expect(history).toContainText('v2');

    const rollbackResponse = page.waitForResponse(
      (response) =>
        exactApiPath(response, `${adminPresetScenesApiPath}/${scene.presetSceneId}/rollback/1`) &&
        response.request().method() === 'POST',
    );
    await history.getByRole('button', { name: '回滚到 v1' }).click();
    await page.getByRole('button', { name: '确认回滚' }).click();
    expect((await rollbackResponse).status()).toBe(200);
    await expect(history).toContainText('v3');
  });

  test('keeps route visible for practice readers and disables write/publish actions', async ({ page, request }) => {
    const scene = seedPresetSceneFixture(`reader-${uniqueSuffix()}`);
    const superAdmin = await loginViaAdminApi(request);
    await createPresetSceneDraft(request, superAdmin.accessToken, scene.presetSceneId, draftFor(scene));
    const reader = await createAdminWithPermissions(request, ['practice:read'], 'Preset Scene Reader');

    await loginViaUi(page, {
      username: reader.username,
      password: reader.password,
      expectedUrl: /\/practice\/preset-scenes$/,
    });
    await expect(page.getByTestId('workspace-link-preset-scenes')).toBeVisible();
    await page.getByTestId(`preset-scene-edit-${scene.presetSceneId}`).click();
    await expect(page.getByRole('button', { name: '保存草稿', exact: true })).toBeDisabled();
    await expect(page.getByRole('button', { name: '发布版本', exact: true })).toBeDisabled();
    const readerDrawer = page.getByRole('dialog', { name: /编辑预置场景/ });
    await readerDrawer.getByRole('button', { name: '关闭', exact: true }).click();
    await expect(readerDrawer).toBeHidden();
    await page.getByTestId(`preset-scene-history-${scene.presetSceneId}`).click();
    await expect(
      page
        .getByRole('dialog', { name: /版本历史/ })
        .getByRole('button', { name: /回滚到 v/ })
        .first(),
    ).toBeDisabled();
  });

  test('keeps save enabled for editors while publish remains publisher-only', async ({ page, request }) => {
    const scene = seedPresetSceneFixture(`editor-${uniqueSuffix()}`);
    const superAdmin = await loginViaAdminApi(request);
    await createPresetSceneDraft(request, superAdmin.accessToken, scene.presetSceneId, draftFor(scene));
    const editor = await createAdminWithPermissions(
      request,
      ['practice:read', 'practice:write'],
      'Preset Scene Editor',
    );

    await loginViaUi(page, {
      username: editor.username,
      password: editor.password,
      expectedUrl: /\/practice\/preset-scenes$/,
    });
    await page.getByTestId(`preset-scene-edit-${scene.presetSceneId}`).click();
    await expect(page.getByRole('button', { name: '保存草稿', exact: true })).toBeEnabled();
    await expect(page.getByRole('button', { name: '发布版本', exact: true })).toBeDisabled();
  });

  test('keeps publish and rollback enabled for publisher-only admins while save stays disabled', async ({
    page,
    request,
  }) => {
    const scene = seedPresetSceneFixture(`publisher-${uniqueSuffix()}`);
    const superAdmin = await loginViaAdminApi(request);
    await createPresetSceneDraft(request, superAdmin.accessToken, scene.presetSceneId, draftFor(scene));
    const publisher = await createAdminWithPermissions(
      request,
      ['practice:read', 'practice:publish'],
      'Preset Scene Publisher',
    );

    await loginViaUi(page, {
      username: publisher.username,
      password: publisher.password,
      expectedUrl: /\/practice\/preset-scenes$/,
    });
    await page.getByTestId(`preset-scene-edit-${scene.presetSceneId}`).click();
    await expect(page.getByRole('button', { name: '保存草稿', exact: true })).toBeDisabled();
    await expect(page.getByRole('button', { name: '创建草稿', exact: true })).toBeDisabled();
    await expect(page.getByRole('button', { name: '发布版本', exact: true })).toBeEnabled();

    const publishResponse = page.waitForResponse(
      (response) =>
        exactApiPath(response, `${adminPresetScenesApiPath}/${scene.presetSceneId}/publish`) &&
        response.request().method() === 'POST',
    );
    await page.getByRole('button', { name: '发布版本', exact: true }).click();
    expect((await publishResponse).status()).toBe(200);
    await expect(sceneRow(page, scene.presetSceneId)).toContainText('published v2');
    await expect(sceneRow(page, scene.presetSceneId)).toContainText('no draft');

    const publisherDrawer = page.getByRole('dialog', { name: /编辑预置场景/ });
    await publisherDrawer.getByRole('button', { name: '关闭', exact: true }).click();
    await expect(publisherDrawer).toBeHidden();
    await sceneRow(page, scene.presetSceneId).getByRole('button', { name: '版本历史', exact: true }).click();
    await expect(
      page.getByRole('dialog', { name: /版本历史/ }).getByRole('button', { name: '回滚到 v1', exact: true }),
    ).toBeEnabled();
    const rollbackResponse = page.waitForResponse(
      (response) =>
        exactApiPath(response, `${adminPresetScenesApiPath}/${scene.presetSceneId}/rollback/1`) &&
        response.request().method() === 'POST',
    );
    await page
      .getByRole('dialog', { name: /版本历史/ })
      .getByRole('button', { name: '回滚到 v1', exact: true })
      .click();
    await page.getByRole('button', { name: '确认回滚', exact: true }).click();
    expect((await rollbackResponse).status()).toBe(200);
    await expect(page.getByRole('dialog', { name: /版本历史/ })).toContainText('v3');
    await expect(sceneRow(page, scene.presetSceneId)).toContainText('published v3');
  });

  test('hides the route for admins without practice:read and forbids direct navigation', async ({ page, request }) => {
    const usersOnly = await createAdminWithPermissions(request, ['users:read'], 'Users Without Practice Access');
    await loginViaUi(page, {
      username: usersOnly.username,
      password: usersOnly.password,
      expectedUrl: /\/users$/,
    });
    await expect(page.getByTestId('workspace-link-preset-scenes')).toHaveCount(0);

    await page.goto('/practice/preset-scenes');
    await expect(page).toHaveURL(/\/403\?from=%2Fpractice%2Fpreset-scenes/);
    await expect(page.getByTestId('forbidden-page')).toBeVisible();
    await expect(page.getByTestId('forbidden-query')).toContainText('required=practice%3Aread');
  });
});

async function gotoPresetScenes(page: Page) {
  const listResponse = page.waitForResponse(
    (response) => exactApiPath(response, adminPresetScenesApiPath) && response.request().method() === 'GET',
  );
  await page.goto('/practice/preset-scenes');
  expect((await listResponse).status()).toBe(200);
  await expect(page.getByTestId('preset-scenes-page')).toBeVisible();
}

async function loginViaUi(page: Page, options: { username?: string; password?: string; expectedUrl?: RegExp } = {}) {
  const username = options.username ?? 'super_admin';
  const password = options.password ?? 'SuperAdmin123!';
  const expectedUrl = options.expectedUrl ?? /\/overview$/;

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
  await expect(page).toHaveURL(expectedUrl);
  await expect(page.getByTestId('protected-shell')).toBeVisible();
}

function sceneRow(page: Page, presetSceneId: string) {
  return page.getByRole('row').filter({ has: page.getByTestId(`preset-scene-row-${presetSceneId}`) });
}

function draftFor(
  scene: { title: string; generationBrief: string },
  overrides: Partial<PresetSceneDraftFixture> = {},
): PresetSceneDraftFixture {
  return {
    title: scene.title,
    summary: 'Playwright 场景摘要。',
    sceneTag: 'Playwright scene',
    coachTip: '使用稳定节奏和短句陪伴宝宝。',
    sortOrder: 99,
    generationBrief: scene.generationBrief,
    enabled: true,
    lockVersion: 0,
    ...overrides,
  };
}

function exactApiPath(response: Response, pathname: string): boolean {
  return new URL(response.url()).pathname === pathname;
}

function uniqueSuffix(): string {
  return `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
}
