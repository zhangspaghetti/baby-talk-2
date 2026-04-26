import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { authApi, sameIdentity, type AdminIdentity, type AuthSession } from './auth-api';
import {
  clearStoredSession,
  getSessionSnapshot,
  persistStoredSession,
  setSessionBanner,
  subscribeToSessionStore,
  type AuthBannerState,
  type SessionSnapshot,
} from './session-store';

type AuthContextValue = {
  session: AuthSession | null;
  banner: AuthBannerState | null;
  login: (username: string, password: string) => Promise<AuthSession>;
  logout: () => Promise<void>;
  syncIdentity: (admin: AdminIdentity) => void;
  resetSession: (banner?: AuthBannerState | null) => void;
  clearBanner: () => void;
};

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [snapshot, setSnapshot] = useState<SessionSnapshot>(() => getSessionSnapshot());

  useEffect(() => subscribeToSessionStore(setSnapshot), []);

  const login = useCallback(async (username: string, password: string) => {
    const session = await authApi.login(username, password);
    persistStoredSession(session);
    return session;
  }, []);

  const logout = useCallback(async () => {
    const currentSession = getSessionSnapshot().session;

    try {
      if (currentSession?.refreshToken) {
        await authApi.logout(currentSession.refreshToken);
      }
    } finally {
      clearStoredSession({
        type: 'success',
        message: '已退出管理员账号。',
      });
    }
  }, []);

  const syncIdentity = useCallback((admin: AdminIdentity) => {
    const currentSession = getSessionSnapshot().session;
    if (!currentSession) {
      return;
    }
    if (sameIdentity(currentSession.admin, admin)) {
      return;
    }
    persistStoredSession({
      ...currentSession,
      admin,
    });
  }, []);

  const resetSession = useCallback((banner?: AuthBannerState | null) => {
    clearStoredSession(banner ?? null);
  }, []);

  const clearBanner = useCallback(() => {
    setSessionBanner(null);
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      session: snapshot.session,
      banner: snapshot.banner,
      login,
      logout,
      syncIdentity,
      resetSession,
      clearBanner,
    }),
    [clearBanner, login, logout, resetSession, snapshot.banner, snapshot.session, syncIdentity],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth 必须在 AuthProvider 内使用。');
  }
  return context;
}
