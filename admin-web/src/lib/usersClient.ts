import { ApiError, requestJson } from './authClient';

export const USER_LIST_STATUSES = ['all', 'active', 'deleted'] as const;
export const USER_ACCOUNT_STATUSES = ['active', 'deleted'] as const;
export const USER_CONSENT_STATUSES = ['signed_out', 'accepted', 'revoked', 'deleted'] as const;
export const USER_SESSION_STATUSES = ['active', 'revoked', 'deleted'] as const;
export const USER_AUDIT_ACTIONS = ['accept', 'revoke', 'delete'] as const;
export const USER_AUDIT_RESULTS = ['applied', 'duplicate'] as const;

export type UserListStatus = (typeof USER_LIST_STATUSES)[number];
export type UserAccountStatus = (typeof USER_ACCOUNT_STATUSES)[number];
export type UserConsentStatus = (typeof USER_CONSENT_STATUSES)[number];
export type UserSessionStatus = (typeof USER_SESSION_STATUSES)[number];
export type UserAuditAction = (typeof USER_AUDIT_ACTIONS)[number];
export type UserAuditResult = (typeof USER_AUDIT_RESULTS)[number];

export interface UsersListQuery {
  page?: string;
  pageSize?: string;
  status?: string;
  query?: string;
}

export interface UserSummaryView {
  accountId: string;
  phoneNumber: string;
  status: UserAccountStatus;
  latestConsentStatus: UserConsentStatus;
  createdAt: string;
  deletedAt?: string;
}

export interface UsersListView {
  items: UserSummaryView[];
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
  filters: {
    status: UserListStatus;
    query?: string;
  };
}

export interface UserSessionView {
  sessionId: string;
  installationId: string;
  status: UserSessionStatus;
  createdAt: string;
  revokedAt?: string;
}

export interface UserConsentAuditView {
  auditId: number;
  sessionId?: string;
  installationId?: string;
  action: UserAuditAction;
  result: UserAuditResult;
  reason?: string;
  createdAt: string;
}

export interface UserDetailView {
  account: UserSummaryView;
  recentSessions: UserSessionView[];
  recentConsentAudit: UserConsentAuditView[];
}

export interface DisableUserView {
  accountId: string;
  status: UserAccountStatus;
  applied: boolean;
  result: UserAuditResult;
  updatedAt: string;
  revokedSessionCount: number;
  deletedEventCount: number;
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

function readRequiredNumber(record: Record<string, unknown>, key: string, message: string): number {
  const value = record[key];
  if (typeof value !== 'number' || Number.isNaN(value)) {
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

function readEnumValue<T extends readonly string[]>(
  record: Record<string, unknown>,
  key: string,
  allowed: T,
  message: string,
): T[number] {
  const value = readRequiredString(record, key, message);
  if ((allowed as readonly string[]).includes(value)) {
    return value as T[number];
  }
  throw new ApiError(502, 'invalid_response_payload', message, { field: key, value });
}

function parseUserSummary(payload: unknown, scope: string): UserSummaryView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', `${scope} 不是对象。`);
  }

  return {
    accountId: readRequiredString(payload, 'accountId', `${scope} 缺少 accountId。`),
    phoneNumber: readRequiredString(payload, 'phoneNumber', `${scope} 缺少 phoneNumber。`),
    status: readEnumValue(payload, 'status', USER_ACCOUNT_STATUSES, `${scope} 缺少合法 status。`),
    latestConsentStatus: readEnumValue(
      payload,
      'latestConsentStatus',
      USER_CONSENT_STATUSES,
      `${scope} 缺少合法 latestConsentStatus。`,
    ),
    createdAt: readRequiredString(payload, 'createdAt', `${scope} 缺少 createdAt。`),
    deletedAt: readOptionalString(payload, 'deletedAt'),
  };
}

function parseUserSession(payload: unknown): UserSessionView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'recentSessions item 不是对象。');
  }

  return {
    sessionId: readRequiredString(payload, 'sessionId', 'recentSessions item 缺少 sessionId。'),
    installationId: readRequiredString(payload, 'installationId', 'recentSessions item 缺少 installationId。'),
    status: readEnumValue(payload, 'status', USER_SESSION_STATUSES, 'recentSessions item 缺少合法 status。'),
    createdAt: readRequiredString(payload, 'createdAt', 'recentSessions item 缺少 createdAt。'),
    revokedAt: readOptionalString(payload, 'revokedAt'),
  };
}

function parseConsentAudit(payload: unknown): UserConsentAuditView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'recentConsentAudit item 不是对象。');
  }

  return {
    auditId: readRequiredNumber(payload, 'auditId', 'recentConsentAudit item 缺少 auditId。'),
    sessionId: readOptionalString(payload, 'sessionId'),
    installationId: readOptionalString(payload, 'installationId'),
    action: readEnumValue(payload, 'action', USER_AUDIT_ACTIONS, 'recentConsentAudit item 缺少合法 action。'),
    result: readEnumValue(payload, 'result', USER_AUDIT_RESULTS, 'recentConsentAudit item 缺少合法 result。'),
    reason: readOptionalString(payload, 'reason'),
    createdAt: readRequiredString(payload, 'createdAt', 'recentConsentAudit item 缺少 createdAt。'),
  };
}

function parseUsersList(payload: unknown): UsersListView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'users list 响应不是对象。');
  }

  const itemsPayload = payload.items;
  const filtersPayload = payload.filters;
  if (!Array.isArray(itemsPayload)) {
    throw new ApiError(502, 'invalid_response_payload', 'users list 缺少 items。');
  }
  if (!isRecord(filtersPayload)) {
    throw new ApiError(502, 'invalid_response_payload', 'users list 缺少 filters。');
  }

  return {
    items: itemsPayload.map((item, index) => parseUserSummary(item, `items[${index}]`)),
    page: readRequiredNumber(payload, 'page', 'users list 缺少 page。'),
    pageSize: readRequiredNumber(payload, 'pageSize', 'users list 缺少 pageSize。'),
    total: readRequiredNumber(payload, 'total', 'users list 缺少 total。'),
    totalPages: readRequiredNumber(payload, 'totalPages', 'users list 缺少 totalPages。'),
    filters: {
      status: readEnumValue(filtersPayload, 'status', USER_LIST_STATUSES, 'filters 缺少合法 status。'),
      query: readOptionalString(filtersPayload, 'query'),
    },
  };
}

function parseUserDetail(payload: unknown): UserDetailView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'user detail 响应不是对象。');
  }

  const recentSessionsPayload = payload.recentSessions;
  const recentConsentAuditPayload = payload.recentConsentAudit;

  if (!Array.isArray(recentSessionsPayload)) {
    throw new ApiError(502, 'invalid_response_payload', 'user detail 缺少 recentSessions。');
  }
  if (!Array.isArray(recentConsentAuditPayload)) {
    throw new ApiError(502, 'invalid_response_payload', 'user detail 缺少 recentConsentAudit。');
  }

  return {
    account: parseUserSummary(payload.account, 'account'),
    recentSessions: recentSessionsPayload.map((item) => parseUserSession(item)),
    recentConsentAudit: recentConsentAuditPayload.map((item) => parseConsentAudit(item)),
  };
}

function parseDisableUser(payload: unknown): DisableUserView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'disable user 响应不是对象。');
  }

  return {
    accountId: readRequiredString(payload, 'accountId', 'disable user 响应缺少 accountId。'),
    status: readEnumValue(payload, 'status', USER_ACCOUNT_STATUSES, 'disable user 响应缺少合法 status。'),
    applied: readRequiredBoolean(payload, 'applied', 'disable user 响应缺少 applied。'),
    result: readEnumValue(payload, 'result', USER_AUDIT_RESULTS, 'disable user 响应缺少合法 result。'),
    updatedAt: readRequiredString(payload, 'updatedAt', 'disable user 响应缺少 updatedAt。'),
    revokedSessionCount: readRequiredNumber(
      payload,
      'revokedSessionCount',
      'disable user 响应缺少 revokedSessionCount。',
    ),
    deletedEventCount: readRequiredNumber(
      payload,
      'deletedEventCount',
      'disable user 响应缺少 deletedEventCount。',
    ),
  };
}

function buildQueryString(query: UsersListQuery): string {
  const params = new URLSearchParams();
  if (query.page !== undefined) {
    params.set('page', query.page);
  }
  if (query.pageSize !== undefined) {
    params.set('pageSize', query.pageSize);
  }
  if (query.status !== undefined) {
    params.set('status', query.status);
  }
  if (query.query !== undefined) {
    params.set('query', query.query);
  }
  const rendered = params.toString();
  return rendered ? `?${rendered}` : '';
}

export const usersClient = {
  async listUsers(query: UsersListQuery) {
    const payload = await requestJson(`/api/admin/users${buildQueryString(query)}`);
    return parseUsersList(payload);
  },

  async getUser(accountId: string) {
    const payload = await requestJson(`/api/admin/users/${encodeURIComponent(accountId)}`);
    return parseUserDetail(payload);
  },

  async disableUser(accountId: string, reason: string) {
    const payload = await requestJson(`/api/admin/users/${encodeURIComponent(accountId)}/disable`, {
      method: 'PATCH',
      body: { reason },
    });
    return parseDisableUser(payload);
  },
};
