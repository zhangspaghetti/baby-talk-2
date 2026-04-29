import { spawnSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import type { APIRequestContext, APIResponse } from '@playwright/test';

const currentDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(currentDir, '..', '..', '..');

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

export type SeededKnowledgeGraphFixture = {
  contradictionId: string;
  notificationId: string;
};

export async function loginViaAdminApi(
  request: APIRequestContext,
  username: string = superAdminCredentials.username,
  password: string = superAdminCredentials.password,
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

export function seedFailedIngestionJobFixture(label: string): string {
  const jobId = randomUUID();
  runComposeSql(`
    insert into ingestion_jobs (
      id,
      original_filename,
      minio_object_key,
      status,
      total_chunks,
      error_message,
      created_at,
      updated_at
    ) values (
      ${sqlLiteral(jobId)},
      ${sqlLiteral(`forced-${label}.pdf`)},
      ${sqlLiteral(`ingestion/private/${jobId}.pdf`)},
      'FAILED',
      0,
      ${sqlLiteral(`forced failure ${label}`)},
      current_timestamp - interval '5 minutes',
      current_timestamp - interval '1 minute'
    );
  `);
  return jobId;
}

export function seedKnowledgeGraphFixture(label: string): SeededKnowledgeGraphFixture {
  const contradictionId = randomUUID();
  const notificationId = randomUUID();
  const sourceEntityId = randomUUID();
  const targetEntityId = randomUUID();
  const relationshipAId = randomUUID();
  const relationshipBId = randomUUID();

  runComposeSql(`
    insert into kg_entities (id, name, entity_type, description)
    values
      (${sqlLiteral(sourceEntityId)}, ${sqlLiteral(`topic-source-${label}`)}, 'concept', ${sqlLiteral(`desc-source-${label}`)}),
      (${sqlLiteral(targetEntityId)}, ${sqlLiteral(`topic-target-${label}`)}, 'concept', ${sqlLiteral(`desc-target-${label}`)});

    insert into kg_relationships (
      id,
      source_entity_id,
      target_entity_id,
      relation_type,
      source_book,
      context_note
    ) values
      (
        ${sqlLiteral(relationshipAId)},
        ${sqlLiteral(sourceEntityId)},
        ${sqlLiteral(targetEntityId)},
        'contradicts',
        ${sqlLiteral(`source-a-${label}.pdf`)},
        ${sqlLiteral(`context-a-${label}`)}
      ),
      (
        ${sqlLiteral(relationshipBId)},
        ${sqlLiteral(sourceEntityId)},
        ${sqlLiteral(targetEntityId)},
        'contradicts',
        ${sqlLiteral(`source-b-${label}.pdf`)},
        ${sqlLiteral(`context-b-${label}`)}
      );

    insert into kg_contradictions (
      id,
      entity_topic,
      relationship_a_id,
      relationship_b_id,
      source_a_book,
      source_b_book,
      description,
      status,
      agent_review_result,
      admin_notes,
      detected_at,
      reviewed_at,
      resolved_at
    ) values (
      ${sqlLiteral(contradictionId)},
      ${sqlLiteral(`sleep-topic-${label}`)},
      ${sqlLiteral(relationshipAId)},
      ${sqlLiteral(relationshipBId)},
      ${sqlLiteral(`source-a-${label}.pdf`)},
      ${sqlLiteral(`source-b-${label}.pdf`)},
      ${sqlLiteral(`需要人工确认的矛盾 ${label}`)},
      'escalated',
      ${sqlLiteral('{"verdict":"escalated"}')},
      null,
      current_timestamp - interval '6 minutes',
      current_timestamp - interval '5 minutes',
      null
    );

    insert into kg_admin_notifications (
      id,
      contradiction_id,
      notification_type,
      message,
      is_read,
      created_at
    ) values (
      ${sqlLiteral(notificationId)},
      ${sqlLiteral(contradictionId)},
      'contradiction_escalated',
      ${sqlLiteral(`管理员通知 ${label}`)},
      false,
      current_timestamp - interval '4 minutes'
    );
  `);

  return {
    contradictionId,
    notificationId,
  };
}

export function repointIngestionJobToSourceObject(targetJobId: string, sourceJobId: string): void {
  const sourceObjectKey = readComposeScalar(
    `select minio_object_key from ingestion_jobs where id = ${sqlLiteral(sourceJobId)};`,
    `lookup ingestion object for ${sourceJobId}`,
  );

  if (!sourceObjectKey) {
    throw new Error(`[admin-api seed] source ingestion job ${sourceJobId} did not have a minio_object_key.`);
  }

  runComposeSql(`
    update ingestion_jobs
       set minio_object_key = ${sqlLiteral(sourceObjectKey)},
           updated_at = current_timestamp
     where id = ${sqlLiteral(targetJobId)};
  `);
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

  try {
    return JSON.parse(bodyText) as T;
  } catch (error) {
    throw new Error(
      `[admin-api seed] ${label} returned invalid fixture payload: ${error instanceof Error ? error.message : String(error)}. Body: ${bodyText}`,
    );
  }
}

function runComposeSql(sql: string): void {
  runComposePsql(sql, false, 'sql');
}

function readComposeScalar(sql: string, label: string): string {
  return runComposePsql(sql, true, label).trim();
}

function runComposePsql(sql: string, tuplesOnly: boolean, label: string): string {
  const isK8sMode = !!process.env['BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT'];

  let result;
  if (isK8sMode) {
    const args = ['exec', '-n', 'babytalk', 'deploy/babytalk-infra-postgres', '--', 'psql', '-U', 'babytalk', '-d', 'babytalk', '-v', 'ON_ERROR_STOP=1'];
    if (tuplesOnly) {
      args.push('-At');
    }
    args.push('-c', sql);
    result = spawnSync('kubectl', args, {
      encoding: 'utf-8',
      stdio: 'pipe',
    });
  } else {
    const args = ['compose', 'exec', '-T', 'postgres', 'psql', '-U', 'babytalk', '-d', 'babytalk', '-v', 'ON_ERROR_STOP=1'];
    if (tuplesOnly) {
      args.push('-At');
    }
    args.push('-c', sql);
    result = spawnSync('docker', args, {
      cwd: repoRoot,
      encoding: 'utf-8',
      stdio: 'pipe',
    });
  }

  if (result.status !== 0) {
    throw new Error(
      `[admin-api seed] ${label} failed with status ${result.status ?? 'unknown'}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`,
    );
  }

  return result.stdout;
}

function sqlLiteral(value: string | null): string {
  if (value === null) {
    return 'null';
  }
  return `'${value.replace(/'/g, "''")}'`;
}

function uniqueSuffix(): string {
  return `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
}
