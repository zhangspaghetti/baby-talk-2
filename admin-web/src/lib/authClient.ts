import {
  ApiError,
  authApi,
  hasPermission,
  sameIdentity,
  toApiError,
  type AdminIdentity,
  type AuthSession,
  type LogoutResponse,
} from '../auth/auth-api';
import { requestCurrentAdmin, requestJson, type JsonRequestOptions } from '../auth/http-client';
import {
  clearStoredSession,
  loadStoredSession,
  persistStoredSession,
  type AuthBannerState,
  type SessionSnapshot,
} from '../auth/session-store';

export type {
  AdminIdentity,
  AuthBannerState,
  AuthSession,
  JsonRequestOptions,
  LogoutResponse,
  SessionSnapshot,
};

export {
  ApiError,
  clearStoredSession,
  hasPermission,
  loadStoredSession,
  persistStoredSession,
  requestJson,
  sameIdentity,
  toApiError,
};

export const authClient = {
  login: authApi.login,
  me: requestCurrentAdmin,
  logout: authApi.logout,
};
