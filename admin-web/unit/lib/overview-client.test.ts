import axios, { AxiosError, AxiosHeaders, type AxiosResponse, type InternalAxiosRequestConfig } from 'axios';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { AuthSession } from '../../src/auth/auth-api';

const admin = {
  principalId: 'admin-1',
  username: 'super_admin',
  displayName: 'Super Admin',
  roles: ['super_admin'],
  permissions: ['rag:read'],
};

const session: AuthSession = {
  admin,
  refreshToken: 'stream-refresh-token',
};

describe('overview stream session refresh', () => {
  const originalFetch = globalThis.fetch;
  const originalAxiosAdapter = axios.defaults.adapter;

  beforeEach(() => {
    vi.resetModules();
    window.localStorage.clear();
  });

  afterEach(() => {
    vi.restoreAllMocks();
    globalThis.fetch = originalFetch;
    axios.defaults.adapter = originalAxiosAdapter;
  });

  it('authorizes the first stream request with the stored access token without refreshing a valid session', async () => {
    const { authApi } = await import('../../src/auth/auth-api');
    const { persistStoredSession } = await import('../../src/auth/session-store');
    const refreshSpy = vi.spyOn(authApi, 'refresh');
    persistStoredSession({
      ...session,
      accessToken: 'stream-access-token',
    });
    globalThis.fetch = vi.fn().mockResolvedValueOnce(streamResponse());
    const { overviewClient } = await import('../../src/lib/overviewClient');

    const subscription = overviewClient.subscribeTransport({
      onTransport: vi.fn(),
    });

    await subscription.closed;

    expect(refreshSpy).not.toHaveBeenCalled();
    expect(globalThis.fetch).toHaveBeenCalledOnce();
    expect(globalThis.fetch).toHaveBeenCalledWith(
      expect.any(String),
      expect.objectContaining({
        headers: expect.objectContaining({
          Accept: 'text/event-stream',
          Authorization: 'Bearer stream-access-token',
        }),
      }),
    );
  });

  it('passes stored refresh token, persists refreshed session, then retries the stream', async () => {
    const { authApi } = await import('../../src/auth/auth-api');
    const { getSessionSnapshot, persistStoredSession } = await import('../../src/auth/session-store');
    const refreshSpy = vi.spyOn(authApi, 'refresh').mockResolvedValue({
      admin,
      accessToken: 'next-stream-access-token',
      refreshToken: 'next-refresh-token',
    });
    persistStoredSession(session);
    globalThis.fetch = vi
      .fn()
      .mockResolvedValueOnce(new Response('', { status: 401 }))
      .mockResolvedValueOnce(streamResponse());
    const { overviewClient } = await import('../../src/lib/overviewClient');

    const subscription = overviewClient.subscribeTransport({
      onTransport: vi.fn(),
    });

    await subscription.closed;

    expect(refreshSpy).toHaveBeenCalledTimes(1);
    expect(refreshSpy).toHaveBeenCalledWith('stream-refresh-token');
    expect(getSessionSnapshot()).toEqual({
      session: { admin, accessToken: 'next-stream-access-token', refreshToken: 'next-refresh-token' },
      banner: null,
    });
    expect(globalThis.fetch).toHaveBeenCalledTimes(2);
    expect(globalThis.fetch).toHaveBeenNthCalledWith(
      2,
      expect.any(String),
      expect.objectContaining({
        headers: expect.objectContaining({
          Authorization: 'Bearer next-stream-access-token',
        }),
      }),
    );
  });

  it('fails closed without a stored refresh token and does not call refresh API', async () => {
    const { authApi } = await import('../../src/auth/auth-api');
    const { getSessionSnapshot } = await import('../../src/auth/session-store');
    const refreshSpy = vi.spyOn(authApi, 'refresh');
    globalThis.fetch = vi.fn().mockResolvedValue(new Response('', { status: 401 }));
    const { overviewClient } = await import('../../src/lib/overviewClient');
    const onError = vi.fn();

    const subscription = overviewClient.subscribeTransport({
      onTransport: vi.fn(),
      onError,
    });

    await subscription.closed;

    expect(refreshSpy).not.toHaveBeenCalled();
    expect(globalThis.fetch).toHaveBeenCalledOnce();
    expect(getSessionSnapshot()).toEqual({
      session: null,
      banner: {
        type: 'warning',
        message: '管理员会话已失效，请重新登录。',
        code: 'admin_session_invalid',
      },
    });
    expect(onError).toHaveBeenCalledTimes(1);
    expect(onError).toHaveBeenCalledWith(expect.objectContaining({ status: 401, code: 'admin_session_invalid' }));
  });

  it('shares one refresh request across concurrent stream retries', async () => {
    const { authApi } = await import('../../src/auth/auth-api');
    const { persistStoredSession } = await import('../../src/auth/session-store');
    const refresh = deferred<AuthSession>();
    const refreshSpy = vi.spyOn(authApi, 'refresh').mockReturnValue(refresh.promise);
    persistStoredSession(session);
    globalThis.fetch = vi
      .fn()
      .mockResolvedValueOnce(new Response('', { status: 401 }))
      .mockResolvedValueOnce(new Response('', { status: 401 }))
      .mockResolvedValueOnce(streamResponse())
      .mockResolvedValueOnce(streamResponse());
    const { overviewClient } = await import('../../src/lib/overviewClient');

    const first = overviewClient.subscribeTransport({ onTransport: vi.fn() });
    const second = overviewClient.subscribeTransport({ onTransport: vi.fn() });
    await vi.waitFor(() => {
      expect(refreshSpy).toHaveBeenCalledTimes(1);
      expect(refreshSpy).toHaveBeenCalledWith('stream-refresh-token');
    });
    refresh.resolve({ admin, refreshToken: 'next-refresh-token' });

    await Promise.all([first.closed, second.closed]);

    expect(globalThis.fetch).toHaveBeenCalledTimes(4);
  });

  it('clears session and reports normalized refresh errors', async () => {
    const { authApi } = await import('../../src/auth/auth-api');
    const { getSessionSnapshot, persistStoredSession } = await import('../../src/auth/session-store');
    vi.spyOn(authApi, 'refresh').mockRejectedValue(new Error('refresh transport failed'));
    persistStoredSession(session);
    globalThis.fetch = vi.fn().mockResolvedValue(new Response('', { status: 401 }));
    const { overviewClient } = await import('../../src/lib/overviewClient');
    const onError = vi.fn();

    const subscription = overviewClient.subscribeTransport({
      onTransport: vi.fn(),
      onError,
    });

    await subscription.closed;

    expect(getSessionSnapshot().session).toBeNull();
    expect(getSessionSnapshot().banner).toEqual(expect.objectContaining({ type: 'error', code: 'unexpected_error' }));
    expect(onError).toHaveBeenCalledTimes(1);
    expect(onError).toHaveBeenCalledWith(
      expect.objectContaining({ code: 'unexpected_error', message: 'refresh transport failed' }),
    );
  });

  it('shares one refresh request between stream and protected Axios retries', async () => {
    const refreshGate = deferred<void>();
    let refreshCalls = 0;
    let meCalls = 0;
    const meAuthorization: string[] = [];
    const streamAuthorization: string[] = [];

    axios.defaults.adapter = async (config) => {
      if (config.url === '/api/admin/auth/refresh') {
        refreshCalls += 1;
        await refreshGate.promise;
        return jsonResponse(config, 200, {
          admin,
          accessToken: 'next-access-token',
          refreshToken: 'next-refresh-token',
        });
      }

      if (config.url === '/api/admin/me') {
        meCalls += 1;
        meAuthorization.push(readHeader(config, 'Authorization'));
        if (meCalls === 1) {
          throw responseError(config, 401, { status: 401, code: 'expired', message: 'expired' });
        }
        return jsonResponse(config, 200, admin);
      }

      throw new Error(`Unexpected request ${config.url ?? ''}`);
    };

    const { persistStoredSession } = await import('../../src/auth/session-store');
    const { overviewClient } = await import('../../src/lib/overviewClient');
    const { requestCurrentAdmin } = await import('../../src/auth/http-client');
    persistStoredSession({ admin, accessToken: 'old-access-token', refreshToken: 'refresh-token' });

    let streamCalls = 0;
    globalThis.fetch = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      streamCalls += 1;
      streamAuthorization.push(new Headers(init?.headers).get('Authorization') ?? '');
      if (streamCalls === 1) {
        return new Response('', { status: 401 });
      }
      return streamResponse();
    });

    const stream = overviewClient.subscribeTransport({ onTransport: vi.fn() });
    const protectedRequest = requestCurrentAdmin();
    await vi.waitFor(() => {
      expect(refreshCalls).toBe(1);
    });
    refreshGate.resolve();

    await expect(protectedRequest).resolves.toEqual(admin);
    await stream.closed;

    expect(refreshCalls).toBe(1);
    expect(meCalls).toBe(2);
    expect(meAuthorization).toEqual(['Bearer old-access-token', 'Bearer next-access-token']);
    expect(streamAuthorization).toEqual(['Bearer old-access-token', 'Bearer next-access-token']);
  });

  it('clears once and broadcasts the same refresh failure to stream and Axios callers', async () => {
    let refreshCalls = 0;
    axios.defaults.adapter = async (config) => {
      if (config.url === '/api/admin/auth/refresh') {
        refreshCalls += 1;
        throw responseError(config, 401, {
          status: 401,
          code: 'refresh_invalid',
          message: 'refresh invalid',
        });
      }
      throw responseError(config, 401, { status: 401, code: 'expired', message: 'expired' });
    };

    const { persistStoredSession, subscribeToSessionStore } = await import('../../src/auth/session-store');
    const { overviewClient } = await import('../../src/lib/overviewClient');
    const { requestCurrentAdmin } = await import('../../src/auth/http-client');
    persistStoredSession({ admin, accessToken: 'old-access-token', refreshToken: 'refresh-token' });
    const snapshots: unknown[] = [];
    const unsubscribe = subscribeToSessionStore((snapshot) => snapshots.push(snapshot));

    globalThis.fetch = vi.fn().mockResolvedValue(new Response('', { status: 401 }));
    const onError = vi.fn();
    const stream = overviewClient.subscribeTransport({ onTransport: vi.fn(), onError });
    const protectedError = await requestCurrentAdmin().catch((error: unknown) => error);
    await stream.closed;
    unsubscribe();

    expect(refreshCalls).toBe(1);
    expect(protectedError).toMatchObject({ status: 401, code: 'refresh_invalid' });
    expect(onError).toHaveBeenCalledOnce();
    expect(onError).toHaveBeenCalledWith(protectedError);
    expect(snapshots).toEqual([
      expect.objectContaining({
        session: null,
        banner: { type: 'warning', code: 'refresh_invalid', message: 'refresh invalid' },
      }),
    ]);
  });
});

function streamResponse(): Response {
  return new Response('', {
    status: 200,
    headers: {
      'content-type': 'text/event-stream',
    },
  });
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((resolvePromise) => {
    resolve = resolvePromise;
  });
  return { promise, resolve };
}

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
