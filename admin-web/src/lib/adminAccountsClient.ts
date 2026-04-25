import { ApiError, requestJson } from './authClient';

export const ADMIN_ACCOUNT_STATUSES = ['active', 'disabled'] as const;

export type AdminAccountStatus = (typeof ADMIN_ACCOUNT_STATUSES)[number];

export interface AdminRoleView {
  roleCode: string;
  description: string;
  createdAt: string;
  permissionCodes: string[];
}

export interface AdminAccountView {
  principalId: string;
  username: string;
  displayName: string;
  status: AdminAccountStatus;
  createdAt: string;
  updatedAt: string;
  roleCodes: string[];
}

export interface CreateAdminAccountCommand {
  username: string;
  displayName: string;
  password: string;
  roleCodes: string[];
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

function readStringArray(record: Record<string, unknown>, key: string, message: string): string[] {
  const value = record[key];
  if (!Array.isArray(value) || value.some((entry) => typeof entry !== 'string')) {
    throw new ApiError(502, 'invalid_response_payload', message, { field: key });
  }
  return [...value] as string[];
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

function parseAdminRole(payload: unknown, scope: string): AdminRoleView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', `${scope} 不是对象。`);
  }

  return {
    roleCode: readRequiredString(payload, 'roleCode', `${scope} 缺少 roleCode。`),
    description: readRequiredString(payload, 'description', `${scope} 缺少 description。`),
    createdAt: readRequiredString(payload, 'createdAt', `${scope} 缺少 createdAt。`),
    permissionCodes: readStringArray(payload, 'permissionCodes', `${scope} 缺少 permissionCodes。`),
  };
}

function parseAdminAccount(payload: unknown, scope: string): AdminAccountView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', `${scope} 不是对象。`);
  }

  return {
    principalId: readRequiredString(payload, 'principalId', `${scope} 缺少 principalId。`),
    username: readRequiredString(payload, 'username', `${scope} 缺少 username。`),
    displayName: readRequiredString(payload, 'displayName', `${scope} 缺少 displayName。`),
    status: readEnumValue(payload, 'status', ADMIN_ACCOUNT_STATUSES, `${scope} 缺少合法 status。`),
    createdAt: readRequiredString(payload, 'createdAt', `${scope} 缺少 createdAt。`),
    updatedAt: readRequiredString(payload, 'updatedAt', `${scope} 缺少 updatedAt。`),
    roleCodes: readStringArray(payload, 'roleCodes', `${scope} 缺少 roleCodes。`),
  };
}

function parseAdminRoleList(payload: unknown): AdminRoleView[] {
  if (!Array.isArray(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'roles 响应不是数组。');
  }
  return payload.map((item, index) => parseAdminRole(item, `roles[${index}]`));
}

function parseAdminAccountList(payload: unknown): AdminAccountView[] {
  if (!Array.isArray(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'admins 响应不是数组。');
  }
  return payload.map((item, index) => parseAdminAccount(item, `admins[${index}]`));
}

export const adminAccountsClient = {
  async listRoles() {
    const payload = await requestJson('/api/admin/roles');
    return parseAdminRoleList(payload);
  },

  async listAdmins() {
    const payload = await requestJson('/api/admin/admins');
    return parseAdminAccountList(payload);
  },

  async createAdmin(command: CreateAdminAccountCommand) {
    const payload = await requestJson('/api/admin/admins', {
      method: 'POST',
      body: command,
    });
    return parseAdminAccount(payload, 'createAdmin');
  },

  async disableAdmin(principalId: string) {
    const payload = await requestJson(`/api/admin/admins/${encodeURIComponent(principalId)}/disable`, {
      method: 'PATCH',
    });
    return parseAdminAccount(payload, 'disableAdmin');
  },
};
