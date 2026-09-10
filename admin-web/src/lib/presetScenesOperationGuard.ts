export type PresetSceneOperationToken = {
  sequence: number;
  targetSceneId: string;
};

export type PresetSceneOperationRef = {
  current: PresetSceneOperationToken | null;
  nextSequence: number;
};

export function beginPresetSceneOperation(
  ref: PresetSceneOperationRef,
  targetSceneId: string,
): PresetSceneOperationToken {
  const token = {
    sequence: ref.nextSequence + 1,
    targetSceneId,
  };
  ref.nextSequence = token.sequence;
  ref.current = token;
  return token;
}

export function isPresetSceneOperationActive(
  ref: PresetSceneOperationRef,
  token: PresetSceneOperationToken,
  targetSceneId: string = token.targetSceneId,
): boolean {
  return (
    ref.current?.sequence === token.sequence &&
    ref.current.targetSceneId === token.targetSceneId &&
    targetSceneId === token.targetSceneId
  );
}

export function finishPresetSceneOperation(ref: PresetSceneOperationRef, token: PresetSceneOperationToken): void {
  if (isPresetSceneOperationActive(ref, token)) {
    ref.current = null;
  }
}
