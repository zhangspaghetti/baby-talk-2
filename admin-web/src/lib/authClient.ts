export interface AdminIdentity {
  principalId: string;
  username: string;
  displayName: string;
  roles: string[];
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

const SESSION_STORAGE_KEY = 'babytalk.admin.session';

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

function readJson<T>(rawText: string): T | null {
  if (!rawText.trim()) {
    return null;
  }

  try {
    return JSON.parse(rawText) as T;
  } catch {
    return null;
  }
}

async function requestJson<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers);
  if (init.body && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json');
  }

  let response: Response;
  try {
    response = await fetch(path, {
      ...init,
      headers,
    });
  } catch (error) {
    throw new ApiError(0, 'network_error', '无法连接 admin-api。请确认 admin-api 已启动。');
  }

  const rawText = await response.text();
  const parsed = readJson<T | ErrorPayload>(rawText);

  if (!response.ok) {
    const payload = (parsed ?? {}) as ErrorPayload;
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

  return parsed as T;
}

export const authClient = {
  login(username: string, password: string) {
    return requestJson<AuthSession>('/api/admin/auth/login', {
      method: 'POST',
      body: JSON.stringify({ username, password }),
    });
  },

  me(accessToken: string) {
    return requestJson<AdminIdentity>('/api/admin/me', {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });
  },

  logout(refreshToken: string) {
    return requestJson<LogoutResponse>('/api/admin/auth/logout', {
      method: 'POST',
      body: JSON.stringify({ refreshToken }),
    });
  },
};

export function loadStoredSession(): AuthSession | null {
  if (typeof window === 'undefined') {
    return null;
  }

  try {
    const raw = window.localStorage.getItem(SESSION_STORAGE_KEY);
    if (!raw) {
      return null;
    }

    const parsed = JSON.parse(raw) as Partial<AuthSession>;
    if (!parsed.accessToken || !parsed.refreshToken || !parsed.admin) {
      return null;
    }

    return parsed as AuthSession;
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
