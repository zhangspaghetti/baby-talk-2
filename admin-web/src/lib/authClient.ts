export interface AdminIdentity {
  principalId: string;
  username: string;
  displayName: string;
  roles: string[];
  permissions: string[];
}

export interface AuthSession {
  accessToken: string;
  refreshToken: string;
  tokenType: string;
  accessTokenExpiresAt: string;
  refreshTokenExpiresAt: string;
  admin: AdminIdentity;
}

export interface LogoutResponse {
  loggedOut: boolean;
  loggedOutAt: string;
}

interface ErrorPayload {
  status?: number;
  code?: string;
  message?: string;
  details?: Record<string, unknown>;
}

interface ParseIdentityOptions {
  requirePermissions?: boolean;
}

const SESSION_STORAGE_KEY = 'babytalk.admin.session';
const REQUEST_TIMEOUT_MS = 10_000;

export class ApiError extends Error {
  status: number;
  code: string;
  details: Record<string, unknown>;

  constructor(status: number, code: string, message: string, details: Record<string, unknown> = {}) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

function readJson(rawText: string): unknown | null {
  if (!rawText.trim()) {
    return null;
  }

  try {
    return JSON.parse(rawText) as unknown;
  } catch {
    return null;
  }
}

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

function readOptionalString(record: Record<string, unknown>, key: string): string | undefined {
  const value = record[key];
  if (value == null) {
    return undefined;
  }
  if (typeof value !== 'string') {
    throw new ApiError(502, 'invalid_response_payload', `字段 ${key} 的类型不正确。`, { field: key });
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

function parseAdminIdentity(payload: unknown, options: ParseIdentityOptions = {}): AdminIdentity {
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

function parseAuthSession(payload: unknown): AuthSession {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', '服务端返回了无法识别的登录结果。');
  }

  return {
    accessToken: readRequiredString(payload, 'accessToken', '登录结果缺少 accessToken。'),
    refreshToken: readRequiredString(payload, 'refreshToken', '登录结果缺少 refreshToken。'),
    tokenType: readRequiredString(payload, 'tokenType', '登录结果缺少 tokenType。'),
    accessTokenExpiresAt: readRequiredString(payload, 'accessTokenExpiresAt', '登录结果缺少 accessTokenExpiresAt。'),
    refreshTokenExpiresAt: readRequiredString(payload, 'refreshTokenExpiresAt', '登录结果缺少 refreshTokenExpiresAt。'),
    admin: parseAdminIdentity(payload.admin, { requirePermissions: true }),
  };
}

function parseLogoutResponse(payload: unknown): LogoutResponse {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', '服务端返回了无法识别的退出结果。');
  }

  return {
    loggedOut: readRequiredBoolean(payload, 'loggedOut', '退出结果缺少 loggedOut。'),
    loggedOutAt: readRequiredString(payload, 'loggedOutAt', '退出结果缺少 loggedOutAt。'),
  };
}

async function fetchJson(path: string, init: RequestInit = {}): Promise<unknown> {
  const headers = new Headers(init.headers);
  if (init.body && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json');
  }

  const controller = new AbortController();
  const timeoutId = globalThis.setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  let response: Response;
  try {
    response = await fetch(path, {
      ...init,
      headers,
      signal: controller.signal,
    });
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') {
      throw new ApiError(0, 'request_timeout', '请求超时，请重试。');
    }
    throw new ApiError(0, 'network_error', '无法连接 admin-api。请确认 admin-api 已启动。');
  } finally {
    globalThis.clearTimeout(timeoutId);
  }

  const rawText = await response.text();
  const parsed = readJson(rawText);

  if (!response.ok) {
    const payload = isRecord(parsed) ? (parsed as ErrorPayload) : {};
    throw new ApiError(
      payload.status ?? response.status,
      payload.code ?? 'request_failed',
      payload.message ?? `请求失败（HTTP ${response.status}）。`,
      payload.details ?? {},
    );
  }

  if (parsed == null) {
    throw new ApiError(response.status, 'empty_response', '服务端返回了空响应。');
  }

  return parsed;
}

export async function requestJson(path: string, init: RequestInit = {}): Promise<unknown> {
  return fetchJson(path, init);
}

export const authClient = {
  async login(username: string, password: string) {
    const payload = await fetchJson('/api/admin/auth/login', {
      method: 'POST',
      body: JSON.stringify({ username, password }),
    });
    return parseAuthSession(payload);
  },

  async me(accessToken: string) {
    const payload = await fetchJson('/api/admin/me', {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });
    return parseAdminIdentity(payload, { requirePermissions: true });
  },

  async logout(refreshToken: string) {
    const payload = await fetchJson('/api/admin/auth/logout', {
      method: 'POST',
      body: JSON.stringify({ refreshToken }),
    });
    return parseLogoutResponse(payload);
  },
};

export function hasPermission(identity: AdminIdentity | null | undefined, permissionCode: string): boolean {
  return identity?.permissions.includes(permissionCode) ?? false;
}

export function loadStoredSession(): AuthSession | null {
  if (typeof window === 'undefined') {
    return null;
  }

  try {
    const raw = window.localStorage.getItem(SESSION_STORAGE_KEY);
    if (!raw) {
      return null;
    }

    const parsed = JSON.parse(raw) as unknown;
    if (!isRecord(parsed)) {
      return null;
    }

    return {
      accessToken: readRequiredString(parsed, 'accessToken', 'stored session 缺少 accessToken。'),
      refreshToken: readRequiredString(parsed, 'refreshToken', 'stored session 缺少 refreshToken。'),
      tokenType: readRequiredString(parsed, 'tokenType', 'stored session 缺少 tokenType。'),
      accessTokenExpiresAt: readRequiredString(
        parsed,
        'accessTokenExpiresAt',
        'stored session 缺少 accessTokenExpiresAt。',
      ),
      refreshTokenExpiresAt: readRequiredString(
        parsed,
        'refreshTokenExpiresAt',
        'stored session 缺少 refreshTokenExpiresAt。',
      ),
      admin: parseAdminIdentity(parsed.admin, { requirePermissions: false }),
    };
  } catch {
    return null;
  }
}

export function persistStoredSession(session: AuthSession) {
  if (typeof window === 'undefined') {
    return;
  }

  window.localStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(session));
}

export function clearStoredSession() {
  if (typeof window === 'undefined') {
    return;
  }

  window.localStorage.removeItem(SESSION_STORAGE_KEY);
}
