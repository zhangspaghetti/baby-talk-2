import { beforeEach, describe, expect, it, vi } from 'vitest';

const requestJson = vi.fn();

vi.mock('../../src/lib/authClient', async () => {
  const actual = await vi.importActual<typeof import('../../src/lib/authClient')>('../../src/lib/authClient');
  return {
    ...actual,
    requestJson,
  };
});

describe('preset scenes client', () => {
  beforeEach(() => {
    requestJson.mockReset();
  });

  it('parses scene summaries and details without leaking a malformed payload', async () => {
    const { presetScenesClient } = await import('../../src/lib/presetScenesClient');

    requestJson.mockResolvedValueOnce([
      {
        presetSceneId: 'bath_time',
        spaceId: 'daily_care',
        publishedVersion: 1,
        title: '洗澡时间',
        summary: 'summary',
        sceneTag: 'Bath time',
        coachTip: 'tip',
        sortOrder: 1,
        enabled: true,
        draftLockVersion: 2,
        publishedAt: '2026-08-31T00:00:00Z',
        updatedAt: '2026-08-31T00:00:00Z',
        draftUpdatedAt: '2026-08-31T01:00:00Z',
      },
    ]);

    await expect(presetScenesClient.listScenes()).resolves.toEqual([
      expect.objectContaining({ presetSceneId: 'bath_time', draftLockVersion: 2 }),
    ]);
    expect(requestJson).toHaveBeenCalledWith('/api/admin/v1/practice/preset-scenes');

    requestJson.mockResolvedValueOnce({
      presetSceneId: 'bath_time',
      spaceId: 'daily_care',
      publishedVersion: 1,
      title: '洗澡时间',
      summary: 'summary',
      sceneTag: 'Bath time',
      coachTip: 'tip',
      sortOrder: 1,
      generationBrief: 'brief',
      enabled: true,
      createdAt: '2026-08-30T00:00:00Z',
      updatedAt: '2026-08-31T00:00:00Z',
      publishedAt: '2026-08-31T00:00:00Z',
      draft: null,
    });

    await expect(presetScenesClient.getScene('bath_time')).resolves.toEqual(
      expect.objectContaining({ presetSceneId: 'bath_time', generationBrief: 'brief', draft: null }),
    );
    expect(requestJson).toHaveBeenLastCalledWith('/api/admin/v1/practice/preset-scenes/bath_time');
  });

  it('sends draft and publish lockVersion values unchanged', async () => {
    const { presetScenesClient } = await import('../../src/lib/presetScenesClient');
    const write = {
      title: '标题',
      summary: '摘要',
      sceneTag: 'Tag',
      coachTip: '提示',
      sortOrder: 0,
      generationBrief: '生成文案',
      enabled: true,
      lockVersion: 17,
    };
    requestJson.mockResolvedValueOnce({
      ...write,
      presetSceneId: 'bath_time',
      spaceId: 'daily_care',
      createdAt: '2026-08-31T00:00:00Z',
      updatedAt: '2026-08-31T00:00:00Z',
    });
    await presetScenesClient.updateDraft('bath_time', write);
    expect(requestJson).toHaveBeenCalledWith('/api/admin/v1/practice/preset-scenes/bath_time/draft', {
      method: 'PUT',
      body: write,
    });

    requestJson.mockResolvedValueOnce({
      presetSceneId: 'bath_time',
      spaceId: 'daily_care',
      version: 18,
      title: write.title,
      summary: write.summary,
      sceneTag: write.sceneTag,
      coachTip: write.coachTip,
      sortOrder: write.sortOrder,
      generationBrief: write.generationBrief,
      enabled: write.enabled,
      lockVersion: write.lockVersion,
      createdAt: '2026-08-31T00:00:00Z',
      updatedAt: '2026-08-31T00:00:00Z',
      publishedAt: '2026-08-31T00:00:00Z',
    });
    await presetScenesClient.publish('bath_time', { lockVersion: 17 });
    expect(requestJson).toHaveBeenLastCalledWith('/api/admin/v1/practice/preset-scenes/bath_time/publish', {
      method: 'POST',
      body: { lockVersion: 17 },
    });
  });
});
