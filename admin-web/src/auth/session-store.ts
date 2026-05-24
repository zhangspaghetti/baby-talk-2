import type { AuthSession } from './auth-api';
import { parseStoredSessionPayload } from './auth-api';

export type AuthBannerTone = 'success' | 'info' | 'warning' | 'error';

export type AuthBannerState = {
  type: AuthBannerTone;
  message: string;
  code?: string;
};

export type SessionSnapshot = {
  session: AuthSession | null;
  banner: AuthBannerState | null;
};

let initialized = false;
let currentSession: AuthSession | null = null;
let currentBanner: AuthBannerState | null = null;
const listeners = new Set<(snapshot: SessionSnapshot) => void>();
const SESSION_STORAGE_KEY = 'babytalk.admin.session';

function getLocalStorage(): Storage | null {
  if (typeof window === 'undefined') {
    return null;
  }

  try {
    return window.localStorage;
  } catch {
    return null;
  }
}

function emitSnapshot() {
  const snapshot = getSessionSnapshot();
  for (const listener of listeners) {
    listener(snapshot);
  }
}

function initializeFromStorage() {
  if (initialized) {
    return;
  }

  initialized = true;

  const storage = getLocalStorage();
  if (!storage) {
    return;
  }

  const payload = storage.getItem(SESSION_STORAGE_KEY);
  if (!payload) {
    return;
  }

  try {
    currentSession = parseStoredSessionPayload(JSON.parse(payload));
  } catch {
    storage.removeItem(SESSION_STORAGE_KEY);
    currentSession = null;
    currentBanner = {
      type: 'warning',
      message: '本地管理员会话已损坏，已清理并请重新登录。',
      code: 'stored_session_reset',
    };
  }
}

function writeSessionToStorage(session: AuthSession | null) {
  const storage = getLocalStorage();
  if (!storage) {
    return;
  }

  const hasPersistableToken = Boolean(session?.accessToken || session?.refreshToken);
  if (session && hasPersistableToken) {
    storage.setItem(SESSION_STORAGE_KEY, JSON.stringify(session));
    return;
  }

  storage.removeItem(SESSION_STORAGE_KEY);
}

export function getSessionSnapshot(): SessionSnapshot {
  initializeFromStorage();
  return {
    session: currentSession,
    banner: currentBanner,
  };
}

export function subscribeToSessionStore(listener: (snapshot: SessionSnapshot) => void): () => void {
  initializeFromStorage();
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

export function loadStoredSession(): AuthSession | null {
  return getSessionSnapshot().session;
}

export function persistStoredSession(session: AuthSession) {
  initializeFromStorage();
  currentSession = session;
  currentBanner = null;
  writeSessionToStorage(session);

  emitSnapshot();
}

export function clearStoredSession(banner: AuthBannerState | null = null) {
  initializeFromStorage();
  currentSession = null;
  currentBanner = banner;
  writeSessionToStorage(null);

  emitSnapshot();
}

export function setSessionBanner(banner: AuthBannerState | null) {
  initializeFromStorage();
  currentBanner = banner;
  emitSnapshot();
}
