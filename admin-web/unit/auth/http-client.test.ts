import axios, { AxiosError, AxiosHeaders, type AxiosResponse, type InternalAxiosRequestConfig } from 'axios';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const adminPayload = {
  principalId: 'admin-1',
  username: 'super_admin',
  displayName: 'Super Admin',
  roles: ['super_admin'],
  permissions: ['rag:read'],
};

describe('http-client cookie refresh flow', () => {
  const originalAdapter = axios.defaults.adapter;

  beforeEach(() => {
    vi.resetModules();
  });

  afterEach(() => {
    axios.defaults.adapter = originalAdapter;
  });

  it('sends protected requests without Authorization headers', async () => {
    const seenHeaders: string[] = [];
    axios.defaults.adapter = async (config) => {
      seenHeaders.push(readHeader(config, 'Authorization'));
      return jsonResponse(config, 200, adminPayload);
    };

    const { requestCurrentAdmin } = await import('../../src/auth/http-client');

    await expect(requestCurrentAdmin()).resolves.toEqual(adminPayload);
    expect(seenHeaders).toEqual(['']);
  });

  it('refreshes once on concurrent 401 responses and replays both requests', async () => {
    let refreshCalls = 0;
    let meCalls = 0;
    axios.defaults.adapter = async (config) => {
      if (config.url === '/api/admin/auth/refresh') {
        refreshCalls += 1;
        return jsonResponse(config, 200, { admin: adminPayload });
      }

      if (config.url === '/api/admin/me') {
        meCalls += 1;
        if (meCalls <= 2) {
          throw responseError(config, 401, { status: 401, code: 'expired', message: 'expired' });
        }
        return jsonResponse(config, 200, adminPayload);
      }

      throw new Error(`Unexpected request ${config.url ?? ''}`);
    };

    const { requestCurrentAdmin } = await import('../../src/auth/http-client');
    const { persistStoredSession } = await import('../../src/auth/session-store');

    persistStoredSession({ admin: adminPayload, refreshToken: 'refresh-token' });

    await expect(Promise.all([requestCurrentAdmin(), requestCurrentAdmin()])).resolves.toEqual([
      adminPayload,
      adminPayload,
    ]);
    expect(refreshCalls).toBe(1);
    expect(meCalls).toBe(4);
  });

  it('clears the in-memory session when refresh fails', async () => {
    axios.defaults.adapter = async (config) => {
      if (config.url === '/api/admin/auth/refresh') {
        throw responseError(config, 401, { status: 401, code: 'refresh_invalid', message: 'refresh invalid' });
      }
      throw responseError(config, 401, { status: 401, code: 'expired', message: 'expired' });
    };

    const { requestCurrentAdmin } = await import('../../src/auth/http-client');
    const { getSessionSnapshot, persistStoredSession } = await import('../../src/auth/session-store');

    persistStoredSession({ admin: adminPayload, refreshToken: 'refresh-token' });
    await expect(requestCurrentAdmin()).rejects.toMatchObject({ status: 401, code: 'refresh_invalid' });
    expect(getSessionSnapshot()).toMatchObject({
      session: null,
      banner: { type: 'warning', code: 'refresh_invalid' },
    });
  });
});

function readHeader(config: InternalAxiosRequestConfig, key: string): string {
  const headers = AxiosHeaders.from(config.headers ?? {});
  return headers.get(key)?.toString() ?? '';
}

function jsonResponse(config: InternalAxiosRequestConfig, status: number, data: unknown): AxiosResponse {
  return {
    data,
    status,
    statusText: String(status),
    headers: {},
    config,
  };
}

function responseError(config: InternalAxiosRequestConfig, status: number, data: unknown): AxiosError {
  return new AxiosError('Request failed', undefined, config, undefined, jsonResponse(config, status, data));
}
