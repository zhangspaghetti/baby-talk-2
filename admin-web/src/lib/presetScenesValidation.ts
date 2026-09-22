import type { ApiError } from './authClient';
import type { PresetSceneDraftWrite } from './presetScenesClient';

export type PresetSceneFieldError = {
  name: keyof PresetSceneDraftWrite;
  message: string;
};

const PRESET_SCENE_FIELDS = new Set<keyof PresetSceneDraftWrite>([
  'title',
  'summary',
  'sceneTag',
  'coachTip',
  'sortOrder',
  'generationBrief',
  'enabled',
  'lockVersion',
]);

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

export function readPresetSceneFieldErrors(error: Pick<ApiError, 'details'>): PresetSceneFieldError[] {
  const fields = error.details?.fields;
  if (!isRecord(fields)) {
    return [];
  }

  return Object.entries(fields).flatMap(([name, value]) => {
    if (!PRESET_SCENE_FIELDS.has(name as keyof PresetSceneDraftWrite) || typeof value !== 'string' || !value.trim()) {
      return [];
    }
    return [{ name: name as keyof PresetSceneDraftWrite, message: value }];
  });
}
