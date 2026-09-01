import axios, { type InternalAxiosRequestConfig } from 'axios';
import { ApiError, parseAdminIdentity, toApiError } from './auth-api';
import { refreshAdminSessionOnce } from './admin-session-refresh';
import { loadStoredSession } from './session-store';

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

protectedTransport.interceptors.request.use((config) => {
  const headers = axios.AxiosHeaders.from(config.headers ?? {});
  const accessToken = loadStoredSession()?.accessToken;

  headers.set('Accept', 'application/json');
  if (accessToken) {
    headers.set('Authorization', `Bearer ${accessToken}`);
  } else {
    headers.delete('Authorization');
  }
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

    await refreshAdminSessionOnce();
    config._adminRetried = true;

    try {
      return await protectedTransport.request(config);
    } catch (retryError) {
      throw toApiError(retryError);
    }
  },
);

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
