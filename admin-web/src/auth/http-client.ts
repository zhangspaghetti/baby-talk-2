import axios, { type InternalAxiosRequestConfig } from 'axios';
import { authApi, parseAdminIdentity, toApiError, ApiError, type AuthSession } from './auth-api';
import { clearStoredSession, loadStoredSession, persistStoredSession, type AuthBannerState } from './session-store';

export type JsonRequestOptions = {
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  headers?: Record<string, string>;
  body?: unknown;
};

type RetriableRequestConfig = InternalAxiosRequestConfig & {
  _adminRetried?: boolean;
};

const REQUEST_TIMEOUT_MS = 10_000;

const protectedTransport = axios.create({
  timeout: REQUEST_TIMEOUT_MS,
  headers: {
    Accept: 'application/json',
  },
});

let inFlightRefresh: Promise<AuthSession> | null = null;

protectedTransport.interceptors.request.use((config) => {
  const session = loadStoredSession();
  const headers = axios.AxiosHeaders.from(config.headers ?? {});

  headers.set('Accept', 'application/json');
  if (config.data != null && !headers.has('Content-Type') && !(config.data instanceof FormData)) {
    headers.set('Content-Type', 'application/json');
  }
  if (session?.accessToken) {
    headers.set('Authorization', `Bearer ${session.accessToken}`);
  }

  config.headers = headers;
  return config;
});

protectedTransport.interceptors.response.use(
  (response) => response,
  async (error) => {
    const apiError = toApiError(error);
    const config = axios.isAxiosError(error) ? ((error.config as RetriableRequestConfig | undefined) ?? undefined) : undefined;

    if (!config || config._adminRetried || apiError.status !== 401) {
      throw apiError;
    }

    const session = loadStoredSession();
    if (!session) {
      throw apiError;
    }

    const nextSession = await refreshSession();
    const retryHeaders = axios.AxiosHeaders.from(config.headers ?? {});
    retryHeaders.set('Authorization', `Bearer ${nextSession.accessToken}`);
    config.headers = retryHeaders;
    config._adminRetried = true;

    try {
      return await protectedTransport.request(config);
    } catch (retryError) {
      throw toApiError(retryError);
    }
  },
);

async function refreshSession(): Promise<AuthSession> {
  if (inFlightRefresh) {
    return inFlightRefresh;
  }

  const currentSession = loadStoredSession();
  if (!currentSession?.refreshToken) {
    const error = new ApiError(401, 'admin_session_invalid', '管理员会话已失效，请重新登录。');
    clearStoredSession(toSessionResetBanner(error));
    throw error;
  }

  inFlightRefresh = authApi
    .refresh(currentSession.refreshToken)
    .then((nextSession) => {
      persistStoredSession(nextSession);
      return nextSession;
    })
    .catch((error) => {
      const apiError = toApiError(error);
      clearStoredSession(toSessionResetBanner(apiError));
      throw apiError;
    })
    .finally(() => {
      inFlightRefresh = null;
    });

  return inFlightRefresh;
}

function toSessionResetBanner(error: ApiError): AuthBannerState {
  if (error.code === 'invalid_response_payload') {
    return {
      type: 'error',
      message: '管理员身份响应异常，已清理本地会话，请重新登录。',
      code: error.code,
    };
  }

  return {
    type: error.status === 401 ? 'warning' : 'error',
    message: error.message,
    code: error.code,
  };
}

export async function requestJson(path: string, init: JsonRequestOptions = {}): Promise<unknown> {
  try {
    const response = await protectedTransport.request<unknown>({
      url: path,
      method: init.method ?? (init.body == null ? 'GET' : 'POST'),
      headers: init.headers,
      data: init.body,
    });

    if (response.data == null || response.data === '') {
      throw new ApiError(response.status, 'empty_response', '服务端返回了空响应。');
    }

    return response.data;
  } catch (error) {
    throw toApiError(error);
  }
}

export async function requestCurrentAdmin() {
  const payload = await requestJson('/api/admin/me');
  return parseAdminIdentity(payload, { requirePermissions: true });
}
