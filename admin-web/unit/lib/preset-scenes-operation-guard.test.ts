import { describe, expect, it } from 'vitest';
import {
  beginPresetSceneOperation,
  isPresetSceneOperationActive,
  type PresetSceneOperationRef,
} from '../../src/lib/presetScenesOperationGuard';

describe('preset scene operation guard', () => {
  it('rejects delayed scene A responses after scene B becomes active', () => {
    const ref: PresetSceneOperationRef = { current: null, nextSequence: 0 };
    const sceneA = beginPresetSceneOperation(ref, 'scene-a');
    const sceneB = beginPresetSceneOperation(ref, 'scene-b');

    expect(isPresetSceneOperationActive(ref, sceneA)).toBe(false);
    expect(isPresetSceneOperationActive(ref, sceneA, 'scene-a')).toBe(false);
    expect(isPresetSceneOperationActive(ref, sceneB, 'scene-b')).toBe(true);
    expect(isPresetSceneOperationActive(ref, sceneB, 'scene-a')).toBe(false);
  });

  it('allows only latest operation to commit delayed response state', async () => {
    const ref: PresetSceneOperationRef = { current: null, nextSequence: 0 };
    const commits: string[] = [];
    const deferredA = deferred<void>();
    const operationA = beginPresetSceneOperation(ref, 'scene-a');
    const responseA = deferredA.promise.then(() => {
      if (isPresetSceneOperationActive(ref, operationA, 'scene-a')) {
        commits.push('scene-a');
      }
    });

    const operationB = beginPresetSceneOperation(ref, 'scene-b');
    deferredA.resolve();
    await responseA;
    if (isPresetSceneOperationActive(ref, operationB, 'scene-b')) {
      commits.push('scene-b');
    }

    expect(commits).toEqual(['scene-b']);
  });
});

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((resolvePromise) => {
    resolve = resolvePromise;
  });
  return { promise, resolve };
}
