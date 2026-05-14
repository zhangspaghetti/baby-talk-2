import axios, { type InternalAxiosRequestConfig } from 'axios';
import { authApi, parseAdminIdentity, toApiError, ApiError } from './auth-api';
import { clearStoredSession, persistStoredSession, type AuthBannerState } from './session-store';

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
  withCredentials: true,
  headers: {
    Accept: 'application/json',
  },
});

let inFlightRefresh: Promise<void> | null = null;

protectedTransport.interceptors.request.use((config) => {
  const headers = axios.AxiosHeaders.from(config.headers ?? {});

  headers.set('Accept', 'application/json');
  if (config.data != null && !headers.has('Content-Type') && !(config.data instanceof FormData)) {
    headers.set('Content-Type', 'application/json');
  }

  config.headers = headers;
  return config;
});

protectedTransport.interceptors.response.use(
  (response) => response,
  async (error) => {
    const apiError = toApiError(error);
    const config = axios.isAxiosError(error)
      ? ((error.config as RetriableRequestConfig | undefined) ?? undefined)
      : undefined;

    if (!config || config._adminRetried || apiError.status !== 401) {
      throw apiError;
    }

    await refreshSession();
    config._adminRetried = true;

    try {
      return await protectedTransport.request(config);
    } catch (retryError) {
      throw toApiError(retryError);
    }
  },
);

async function refreshSession(): Promise<void> {
  if (inFlightRefresh) {
    return inFlightRefresh;
  }

  inFlightRefresh = authApi
    .refresh()
    .then((nextSession) => {
      persistStoredSession(nextSession);
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
