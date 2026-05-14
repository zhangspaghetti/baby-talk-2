import axios from 'axios';
import { ApiError, toApiError } from '../shared/errors/to-api-error';

export interface AdminIdentity {
  principalId: string;
  username: string;
  displayName: string;
  roles: string[];
  permissions: string[];
}

export interface AuthSession {
  admin: AdminIdentity;
}

export interface LogoutResponse {
  loggedOut: boolean;
  loggedOutAt: string;
}

interface ParseIdentityOptions {
  requirePermissions?: boolean;
}

const REQUEST_TIMEOUT_MS = 10_000;

const authTransport = axios.create({
  timeout: REQUEST_TIMEOUT_MS,
  withCredentials: true,
  headers: {
    Accept: 'application/json',
    'Content-Type': 'application/json',
  },
});

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function readRequiredString(record: Record<string, unknown>, key: string, message: string): string {
  const value = record[key];
  if (typeof value !== 'string' || !value.trim()) {
    throw new ApiError(502, 'invalid_response_payload', message, { field: key });
  }
  return value;
}

function readRequiredBoolean(record: Record<string, unknown>, key: string, message: string): boolean {
  const value = record[key];
  if (typeof value !== 'boolean') {
    throw new ApiError(502, 'invalid_response_payload', message, { field: key });
  }
  return value;
}

function readStringArray(
  record: Record<string, unknown>,
  key: string,
  message: string,
  fallbackToEmpty = false,
): string[] {
  const value = record[key];
  if (value == null && fallbackToEmpty) {
    return [];
  }
  if (!Array.isArray(value) || value.some((entry) => typeof entry !== 'string')) {
    throw new ApiError(502, 'invalid_response_payload', message, { field: key });
  }
  return [...value] as string[];
}

export function parseAdminIdentity(payload: unknown, options: ParseIdentityOptions = {}): AdminIdentity {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', '服务端返回了无法识别的管理员身份。');
  }

  return {
    principalId: readRequiredString(payload, 'principalId', '管理员身份缺少 principalId。'),
    username: readRequiredString(payload, 'username', '管理员身份缺少 username。'),
    displayName: readRequiredString(payload, 'displayName', '管理员身份缺少 displayName。'),
    roles: readStringArray(payload, 'roles', '管理员身份缺少合法 roles。'),
    permissions: readStringArray(
      payload,
      'permissions',
      '管理员身份缺少合法 permissions。',
      options.requirePermissions !== true,
    ),
  };
}

export function parseAuthSession(payload: unknown): AuthSession {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', '服务端返回了无法识别的登录结果。');
  }

  return {
    admin: parseAdminIdentity('admin' in payload ? payload.admin : payload, { requirePermissions: true }),
  };
}

export function parseStoredSessionPayload(payload: unknown): AuthSession {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'stored session 不是对象。');
  }

  return {
    admin: parseAdminIdentity(payload.admin, { requirePermissions: false }),
  };
}

export function parseLogoutResponse(payload: unknown): LogoutResponse {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', '服务端返回了无法识别的退出结果。');
  }

  return {
    loggedOut: readRequiredBoolean(payload, 'loggedOut', '退出结果缺少 loggedOut。'),
    loggedOutAt: readRequiredString(payload, 'loggedOutAt', '退出结果缺少 loggedOutAt。'),
  };
}

async function requestAuthPayload(path: string, body?: Record<string, unknown>): Promise<unknown> {
  try {
    const response = await authTransport.request<unknown>({
      url: path,
      method: body ? 'POST' : 'GET',
      data: body,
    });

    if (response.data == null || response.data === '') {
      throw new ApiError(response.status, 'empty_response', '服务端返回了空响应。');
    }

    return response.data;
  } catch (error) {
    throw toApiError(error);
  }
}

export const authApi = {
  async login(username: string, password: string) {
    const payload = await requestAuthPayload('/api/admin/auth/login', { username, password });
    return parseAuthSession(payload);
  },

  async refresh() {
    const payload = await requestAuthPayload('/api/admin/auth/refresh');
    return parseAuthSession(payload);
  },

  async logout() {
    const payload = await requestAuthPayload('/api/admin/auth/logout');
    return parseLogoutResponse(payload);
  },
};

export { ApiError, toApiError };

export function hasPermission(identity: AdminIdentity | null | undefined, permissionCode: string): boolean {
  return identity?.permissions.includes(permissionCode) ?? false;
}

export function sameIdentity(left: AdminIdentity, right: AdminIdentity): boolean {
  return (
    left.principalId === right.principalId &&
    left.username === right.username &&
    left.displayName === right.displayName &&
    sameStringList(left.roles, right.roles) &&
    sameStringList(left.permissions, right.permissions)
  );
}

function sameStringList(left: string[], right: string[]): boolean {
  return left.length === right.length && left.every((value, index) => value === right[index]);
}
