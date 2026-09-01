import { describe, expect, it } from 'vitest';
import { ApiError } from '../../src/lib/authClient';
import { readPresetSceneFieldErrors } from '../../src/lib/presetScenesValidation';

describe('preset scene server validation details', () => {
  it('maps ApiError.details.fields into accessible form field errors', () => {
    const error = new ApiError(422, 'practice_publish_validation_failed', '发布校验失败。', {
      fields: {
        generationBrief: 'generationBrief 含控制字符。',
        title: 'title 不得包含手机号样式的数字序列。',
      },
    });

    expect(readPresetSceneFieldErrors(error)).toEqual([
      { name: 'generationBrief', message: 'generationBrief 含控制字符。' },
      { name: 'title', message: 'title 不得包含手机号样式的数字序列。' },
    ]);
  });
});
