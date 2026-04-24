import type { APIRequestContext, APIResponse } from '@playwright/test';

export const adminApiBaseUrl = 'http://127.0.0.1:8081';
export const sessionStorageKey = 'babytalk.admin.session';
export const superAdminCredentials = {
  username: 'super_admin',
  password: 'SuperAdmin123!',
} as const;

export type AdminIdentityFixture = {
  principalId: string;
  username: string;
  displayName: string;
  roles: string[];
  permissions: string[];
};

export type AdminSessionFixture = {
  accessToken: string;
  refreshToken: string;
  tokenType: string;
  accessTokenExpiresAt: string;
  refreshTokenExpiresAt: string;
  admin: AdminIdentityFixture;
};

export type CreatedRoleFixture = {
  roleCode: string;
  description: string;
  permissionCodes: string[];
};

export type CreatedAdminFixture = {
  roleCode: string;
  username: string;
  password: string;
  principalId: string;
  displayName: string;
  permissionCodes: string[];
};

export async function loginViaAdminApi(
  request: APIRequestContext,
  username = superAdminCredentials.username,
  password = superAdminCredentials.password,
): Promise<AdminSessionFixture> {
  const response = await request.post(`${adminApiBaseUrl}/api/admin/auth/login`, {
    headers: {
      'Content-Type': 'application/json',
    },
    data: {
      username,
      password,
    },
  });

  return await expectJson<AdminSessionFixture>(response, 200, `login ${username}`);
}

export async function createRoleWithPermissions(
  request: APIRequestContext,
  permissionCodes: string[],
  description = 'Managed Role',
): Promise<CreatedRoleFixture> {
  const suffix = uniqueSuffix();
  const roleCode = `role_${suffix}`;
  const superAdmin = await loginViaAdminApi(request);

  await expectJson(
    await request.post(`${adminApiBaseUrl}/api/admin/roles`, {
      headers: jsonHeaders(superAdmin.accessToken),
      data: {
        roleCode,
        description: `${description} (${roleCode})`,
        permissionCodes,
      },
    }),
    201,
    `create role ${roleCode}`,
  );

  return {
    roleCode,
    description: `${description} (${roleCode})`,
    permissionCodes: [...permissionCodes],
  };
}

export async function createAdminWithPermissions(
  request: APIRequestContext,
  permissionCodes: string[],
  displayName = 'Limited Admin',
): Promise<CreatedAdminFixture> {
  const role = await createRoleWithPermissions(request, permissionCodes, displayName);
  const suffix = uniqueSuffix();
  const username = `admin_${suffix}`;
  const password = 'Reader123!';
  const superAdmin = await loginViaAdminApi(request);

  const createdAdmin = await expectJson<{
    principalId: string;
    username: string;
    displayName: string;
    roleCodes: string[];
  }>(
    await request.post(`${adminApiBaseUrl}/api/admin/admins`, {
      headers: jsonHeaders(superAdmin.accessToken),
      data: {
        username,
        displayName,
        password,
        roleCodes: [role.roleCode],
      },
    }),
    201,
    `create admin ${username}`,
  );

  return {
    roleCode: role.roleCode,
    username,
    password,
    principalId: createdAdmin.principalId,
    displayName,
    permissionCodes: [...permissionCodes],
  };
}

export async function revokeRefreshToken(request: APIRequestContext, refreshToken: string): Promise<void> {
  await expectJson(
    await request.post(`${adminApiBaseUrl}/api/admin/auth/logout`, {
      headers: {
        'Content-Type': 'application/json',
      },
      data: {
        refreshToken,
      },
    }),
    200,
    'revoke refresh token',
  );
}

function jsonHeaders(accessToken?: string): Record<string, string> {
  return accessToken
    ? {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      }
    : {
        'Content-Type': 'application/json',
      };
}

async function expectJson<T>(response: APIResponse, expectedStatus: number, label: string): Promise<T> {
  const bodyText = await response.text();
  if (response.status() !== expectedStatus) {
    throw new Error(
      `[admin-api seed] ${label} failed: expected HTTP ${expectedStatus}, received ${response.status()}. Body: ${bodyText}`,
    );
  }

  if (!bodyText) {
    throw new Error(`[admin-api seed] ${label} returned an empty body.`);
  }

  return JSON.parse(bodyText) as T;
}

function uniqueSuffix(): string {
  return `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
}
