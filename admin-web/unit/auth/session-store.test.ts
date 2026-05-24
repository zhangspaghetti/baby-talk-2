import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { AuthSession } from '../../src/auth/auth-api';

const session: AuthSession = {
  admin: {
    principalId: 'admin-1',
    username: 'super_admin',
    displayName: 'Super Admin',
    roles: ['super_admin'],
    permissions: ['rag:read'],
  },
};

describe('session-store', () => {
  beforeEach(() => {
    vi.resetModules();
    window.localStorage.clear();
  });

  it('hydrates session from localStorage', async () => {
    window.localStorage.setItem('babytalk.admin.session', JSON.stringify(session));
    const { getSessionSnapshot } = await import('../../src/auth/session-store');

    expect(getSessionSnapshot().session).toEqual(session);
  });

  it('keeps session in memory but skips localStorage without tokens', async () => {
    const { getSessionSnapshot, persistStoredSession } = await import('../../src/auth/session-store');

    persistStoredSession(session);

    expect(getSessionSnapshot().session).toEqual(session);
    expect(window.localStorage.getItem('babytalk.admin.session')).toBeNull();
  });

  it('clears in-memory session and preserves banner state', async () => {
    const { clearStoredSession, getSessionSnapshot, persistStoredSession } =
      await import('../../src/auth/session-store');

    persistStoredSession(session);
    clearStoredSession({ type: 'warning', message: '重新登录', code: 'admin_session_invalid' });

    expect(getSessionSnapshot()).toEqual({
      session: null,
      banner: { type: 'warning', message: '重新登录', code: 'admin_session_invalid' },
    });
    expect(window.localStorage.getItem('babytalk.admin.session')).toBeNull();
  });

  it('clears malformed stored session and exposes reset banner', async () => {
    window.localStorage.setItem('babytalk.admin.session', '{"accessToken":');

    const { getSessionSnapshot } = await import('../../src/auth/session-store');

    expect(getSessionSnapshot()).toEqual({
      session: null,
      banner: {
        type: 'warning',
        message: '本地管理员会话已损坏，已清理并请重新登录。',
        code: 'stored_session_reset',
      },
    });
    expect(window.localStorage.getItem('babytalk.admin.session')).toBeNull();
  });

  it('notifies subscribers on session changes', async () => {
    const { persistStoredSession, subscribeToSessionStore } = await import('../../src/auth/session-store');
    const listener = vi.fn();
    const unsubscribe = subscribeToSessionStore(listener);

    persistStoredSession(session);
    unsubscribe();
    persistStoredSession(session);

    expect(listener).toHaveBeenCalledTimes(1);
    expect(listener).toHaveBeenCalledWith({ session, banner: null });
  });
});
