import { ApiError, requestJson } from './authClient';

const PRESET_SCENES_PATH = '/api/admin/v1/practice/preset-scenes';

export type PresetSceneDraftWrite = {
  title: string;
  summary: string;
  sceneTag: string;
  coachTip: string;
  sortOrder: number;
  generationBrief: string;
  enabled: boolean;
  lockVersion: number;
};

export type PresetScenePublishWrite = {
  lockVersion: number;
};

export interface PresetSceneSummaryView {
  presetSceneId: string;
  spaceId: string;
  publishedVersion: number;
  title: string;
  summary: string;
  sceneTag: string;
  coachTip: string;
  sortOrder: number;
  enabled: boolean;
  draftLockVersion: number | null;
  publishedAt: string;
  updatedAt: string;
  draftUpdatedAt: string | null;
}

export interface PresetSceneDraftView {
  presetSceneId: string;
  spaceId: string;
  title: string;
  summary: string;
  sceneTag: string;
  coachTip: string;
  sortOrder: number;
  generationBrief: string;
  enabled: boolean;
  lockVersion: number;
  createdAt: string;
  updatedAt: string;
}

export interface PresetScenePublishedView {
  presetSceneId: string;
  spaceId: string;
  version: number;
  title: string;
  summary: string;
  sceneTag: string;
  coachTip: string;
  sortOrder: number;
  generationBrief: string;
  enabled: boolean;
  lockVersion: number;
  createdAt: string;
  updatedAt: string;
  publishedAt: string;
}

export interface PresetSceneDetailView {
  presetSceneId: string;
  spaceId: string;
  publishedVersion: number;
  title: string;
  summary: string;
  sceneTag: string;
  coachTip: string;
  sortOrder: number;
  generationBrief: string;
  enabled: boolean;
  createdAt: string;
  updatedAt: string;
  publishedAt: string;
  draft: PresetSceneDraftView | null;
}

// Short aliases keep consumers focused on the domain object while retaining
// the response-oriented names used by the API contract.
export type PresetSceneSummary = PresetSceneSummaryView;
export type PresetSceneDraft = PresetSceneDraftView;
export type PresetScenePublished = PresetScenePublishedView;
export type PresetSceneDetail = PresetSceneDetailView;

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function readRequiredString(record: Record<string, unknown>, key: string, scope: string): string {
  const value = record[key];
  if (typeof value !== 'string' || !value.trim()) {
    throw invalidResponse(`${scope} 缺少合法 ${key}。`, key);
  }
  return value;
}

function readNullableString(record: Record<string, unknown>, key: string, scope: string): string | null {
  const value = record[key];
  if (value == null) {
    return null;
  }
  if (typeof value !== 'string' || !value.trim()) {
    throw invalidResponse(`${scope} 的 ${key} 类型不正确。`, key);
  }
  return value;
}

function readRequiredNumber(record: Record<string, unknown>, key: string, scope: string): number {
  const value = record[key];
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw invalidResponse(`${scope} 缺少合法 ${key}。`, key);
  }
  return value;
}

function readRequiredBoolean(record: Record<string, unknown>, key: string, scope: string): boolean {
  const value = record[key];
  if (typeof value !== 'boolean') {
    throw invalidResponse(`${scope} 缺少合法 ${key}。`, key);
  }
  return value;
}

function readNullableNumber(record: Record<string, unknown>, key: string, scope: string): number | null {
  const value = record[key];
  if (value == null) {
    return null;
  }
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw invalidResponse(`${scope} 的 ${key} 类型不正确。`, key);
  }
  return value;
}

function invalidResponse(message: string, field?: string): ApiError {
  return new ApiError(502, 'invalid_response_payload', message, field ? { field } : undefined);
}

function scenePath(presetSceneId: string): string {
  return `${PRESET_SCENES_PATH}/${encodeURIComponent(presetSceneId)}`;
}

function parseSummary(payload: unknown, scope: string): PresetSceneSummaryView {
  if (!isRecord(payload)) {
    throw invalidResponse(`${scope} 不是对象。`);
  }

  return {
    presetSceneId: readRequiredString(payload, 'presetSceneId', scope),
    spaceId: readRequiredString(payload, 'spaceId', scope),
    publishedVersion: readRequiredNumber(payload, 'publishedVersion', scope),
    title: readRequiredString(payload, 'title', scope),
    summary: readRequiredString(payload, 'summary', scope),
    sceneTag: readRequiredString(payload, 'sceneTag', scope),
    coachTip: readRequiredString(payload, 'coachTip', scope),
    sortOrder: readRequiredNumber(payload, 'sortOrder', scope),
    enabled: readRequiredBoolean(payload, 'enabled', scope),
    draftLockVersion: readNullableNumber(payload, 'draftLockVersion', scope),
    publishedAt: readRequiredString(payload, 'publishedAt', scope),
    updatedAt: readRequiredString(payload, 'updatedAt', scope),
    draftUpdatedAt: readNullableString(payload, 'draftUpdatedAt', scope),
  };
}

function parseDraft(payload: unknown, scope: string): PresetSceneDraftView {
  if (!isRecord(payload)) {
    throw invalidResponse(`${scope} 不是对象。`);
  }

  return {
    presetSceneId: readRequiredString(payload, 'presetSceneId', scope),
    spaceId: readRequiredString(payload, 'spaceId', scope),
    title: readRequiredString(payload, 'title', scope),
    summary: readRequiredString(payload, 'summary', scope),
    sceneTag: readRequiredString(payload, 'sceneTag', scope),
    coachTip: readRequiredString(payload, 'coachTip', scope),
    sortOrder: readRequiredNumber(payload, 'sortOrder', scope),
    generationBrief: readRequiredString(payload, 'generationBrief', scope),
    enabled: readRequiredBoolean(payload, 'enabled', scope),
    lockVersion: readRequiredNumber(payload, 'lockVersion', scope),
    createdAt: readRequiredString(payload, 'createdAt', scope),
    updatedAt: readRequiredString(payload, 'updatedAt', scope),
  };
}

function parsePublished(payload: unknown, scope: string): PresetScenePublishedView {
  if (!isRecord(payload)) {
    throw invalidResponse(`${scope} 不是对象。`);
  }

  return {
    presetSceneId: readRequiredString(payload, 'presetSceneId', scope),
    spaceId: readRequiredString(payload, 'spaceId', scope),
    version: readRequiredNumber(payload, 'version', scope),
    title: readRequiredString(payload, 'title', scope),
    summary: readRequiredString(payload, 'summary', scope),
    sceneTag: readRequiredString(payload, 'sceneTag', scope),
    coachTip: readRequiredString(payload, 'coachTip', scope),
    sortOrder: readRequiredNumber(payload, 'sortOrder', scope),
    generationBrief: readRequiredString(payload, 'generationBrief', scope),
    enabled: readRequiredBoolean(payload, 'enabled', scope),
    lockVersion: readRequiredNumber(payload, 'lockVersion', scope),
    createdAt: readRequiredString(payload, 'createdAt', scope),
    updatedAt: readRequiredString(payload, 'updatedAt', scope),
    publishedAt: readRequiredString(payload, 'publishedAt', scope),
  };
}

function parseDetail(payload: unknown): PresetSceneDetailView {
  if (!isRecord(payload)) {
    throw invalidResponse('preset scene detail 响应不是对象。');
  }

  const draftPayload = payload.draft;
  return {
    presetSceneId: readRequiredString(payload, 'presetSceneId', 'preset scene detail'),
    spaceId: readRequiredString(payload, 'spaceId', 'preset scene detail'),
    publishedVersion: readRequiredNumber(payload, 'publishedVersion', 'preset scene detail'),
    title: readRequiredString(payload, 'title', 'preset scene detail'),
    summary: readRequiredString(payload, 'summary', 'preset scene detail'),
    sceneTag: readRequiredString(payload, 'sceneTag', 'preset scene detail'),
    coachTip: readRequiredString(payload, 'coachTip', 'preset scene detail'),
    sortOrder: readRequiredNumber(payload, 'sortOrder', 'preset scene detail'),
    generationBrief: readRequiredString(payload, 'generationBrief', 'preset scene detail'),
    enabled: readRequiredBoolean(payload, 'enabled', 'preset scene detail'),
    createdAt: readRequiredString(payload, 'createdAt', 'preset scene detail'),
    updatedAt: readRequiredString(payload, 'updatedAt', 'preset scene detail'),
    publishedAt: readRequiredString(payload, 'publishedAt', 'preset scene detail'),
    draft: draftPayload == null ? null : parseDraft(draftPayload, 'preset scene detail draft'),
  };
}

function parseList(payload: unknown): PresetSceneSummaryView[] {
  if (!Array.isArray(payload)) {
    throw invalidResponse('preset scene list 响应不是数组。');
  }
  return payload.map((item, index) => parseSummary(item, `preset scene list[${index}]`));
}

function parseVersions(payload: unknown): PresetScenePublishedView[] {
  if (!Array.isArray(payload)) {
    throw invalidResponse('preset scene versions 响应不是数组。');
  }
  return payload.map((item, index) => parsePublished(item, `preset scene versions[${index}]`));
}

export const presetScenesClient = {
  async listScenes(): Promise<PresetSceneSummaryView[]> {
    return parseList(await requestJson(PRESET_SCENES_PATH));
  },

  async getScene(presetSceneId: string): Promise<PresetSceneDetailView> {
    return parseDetail(await requestJson(scenePath(presetSceneId)));
  },

  async createDraft(presetSceneId: string, write: PresetSceneDraftWrite): Promise<PresetSceneDraftView> {
    return parseDraft(await requestJson(`${scenePath(presetSceneId)}/draft`, { method: 'POST', body: write }), 'create draft');
  },

  async updateDraft(presetSceneId: string, write: PresetSceneDraftWrite): Promise<PresetSceneDraftView> {
    return parseDraft(await requestJson(`${scenePath(presetSceneId)}/draft`, { method: 'PUT', body: write }), 'update draft');
  },

  async publish(presetSceneId: string, write: PresetScenePublishWrite): Promise<PresetScenePublishedView> {
    return parsePublished(
      await requestJson(`${scenePath(presetSceneId)}/publish`, { method: 'POST', body: write }),
      'publish preset scene',
    );
  },

  async rollback(presetSceneId: string, version: number): Promise<PresetScenePublishedView> {
    return parsePublished(
      await requestJson(`${scenePath(presetSceneId)}/rollback/${encodeURIComponent(String(version))}`, { method: 'POST' }),
      'rollback preset scene',
    );
  },

  async versions(presetSceneId: string): Promise<PresetScenePublishedView[]> {
    return parseVersions(await requestJson(`${scenePath(presetSceneId)}/versions`));
  },
};

export const presetSceneClient = presetScenesClient;
