import axios from 'axios';
import { describe, expect, it } from 'vitest';
import { ApiError, toApiError } from '../../../src/shared/errors/to-api-error';

describe('toApiError', () => {
  it('returns existing ApiError instances unchanged', () => {
    const apiError = new ApiError(401, 'admin_session_invalid', '管理员会话已失效。');

    expect(toApiError(apiError)).toBe(apiError);
  });

  it('normalizes axios response errors', () => {
    const axiosError = new axios.AxiosError('Request failed', undefined, undefined, undefined, {
      data: { status: 403, code: 'forbidden', message: '无权限。' },
      status: 403,
      statusText: 'Forbidden',
      headers: {},
      config: { headers: new axios.AxiosHeaders() },
    });

    expect(toApiError(axiosError)).toMatchObject({ status: 403, code: 'forbidden', message: '无权限。' });
  });

  it('normalizes network errors without responses', () => {
    const axiosError = new axios.AxiosError('Network Error');

    expect(toApiError(axiosError)).toMatchObject({ status: 0, code: 'network_error' });
  });

  it('normalizes timeout and native errors', () => {
    expect(toApiError(new axios.AxiosError('timeout', 'ECONNABORTED'))).toMatchObject({ code: 'request_timeout' });
    expect(toApiError(new Error('boom'))).toMatchObject({ status: 0, code: 'unexpected_error', message: 'boom' });
    expect(toApiError('bad')).toMatchObject({ status: 0, code: 'unexpected_error', message: '发生未预期错误。' });
  });
});
