import type { AuthSession } from './auth-api';

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

  emitSnapshot();
}

export function clearStoredSession(banner: AuthBannerState | null = null) {
  initializeFromStorage();
  currentSession = null;
  currentBanner = banner;

  emitSnapshot();
}

export function setSessionBanner(banner: AuthBannerState | null) {
  initializeFromStorage();
  currentBanner = banner;
  emitSnapshot();
}
