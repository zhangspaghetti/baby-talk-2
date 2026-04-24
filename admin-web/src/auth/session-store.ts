import { parseStoredSessionPayload, type AuthSession } from './auth-api';

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

export const SESSION_STORAGE_KEY = 'babytalk.admin.session';

let initialized = false;
let currentSession: AuthSession | null = null;
let currentBanner: AuthBannerState | null = null;
const listeners = new Set<(snapshot: SessionSnapshot) => void>();

function emitSnapshot() {
  const snapshot = getSessionSnapshot();
  for (const listener of listeners) {
    listener(snapshot);
  }
}

function resetCorruptedStorage(message: string, code: string) {
  if (typeof window !== 'undefined') {
    window.localStorage.removeItem(SESSION_STORAGE_KEY);
  }

  currentSession = null;
  currentBanner = {
    type: 'warning',
    message,
    code,
  };
}

function initializeFromStorage() {
  if (initialized) {
    return;
  }

  initialized = true;
  if (typeof window === 'undefined') {
    return;
  }

  const raw = window.localStorage.getItem(SESSION_STORAGE_KEY);
  if (!raw) {
    return;
  }

  try {
    currentSession = parseStoredSessionPayload(JSON.parse(raw) as unknown);
  } catch {
    resetCorruptedStorage('本地管理员会话已损坏，已清理并请重新登录。', 'stored_session_reset');
  }
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

  if (typeof window !== 'undefined') {
    window.localStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(session));
  }

  emitSnapshot();
}

export function clearStoredSession(banner: AuthBannerState | null = null) {
  initializeFromStorage();
  currentSession = null;
  currentBanner = banner;

  if (typeof window !== 'undefined') {
    window.localStorage.removeItem(SESSION_STORAGE_KEY);
  }

  emitSnapshot();
}

export function setSessionBanner(banner: AuthBannerState | null) {
  initializeFromStorage();
  currentBanner = banner;
  emitSnapshot();
}
