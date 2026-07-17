import { describe, expect, it } from 'vitest';

import { isTimeoutSpawnError } from '../../../tests/helpers/admin-api';

describe('admin API seed command errors', () => {
  it('identifies ETIMEDOUT as a spawn timeout', () => {
    const error: NodeJS.ErrnoException = new Error('timed out');
    error.code = 'ETIMEDOUT';

    expect(isTimeoutSpawnError(error)).toBe(true);
  });

  it('does not identify another errno as a spawn timeout', () => {
    const error: NodeJS.ErrnoException = new Error('not found');
    error.code = 'ENOENT';

    expect(isTimeoutSpawnError(error)).toBe(false);
  });

  it('does not identify a regular Error as a spawn timeout', () => {
    expect(isTimeoutSpawnError(new Error('spawn failed'))).toBe(false);
  });

  it('does not identify an absent error as a spawn timeout', () => {
    expect(isTimeoutSpawnError(undefined)).toBe(false);
  });
});
