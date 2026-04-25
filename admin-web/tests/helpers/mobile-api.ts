import type { APIRequestContext, APIResponse } from '@playwright/test';

export const appApiBaseUrl = 'http://127.0.0.1:8080';
export const mobileAppVersionHeaders = {
  'X-App-Version': '1.2.0',
} as const;

export type MobileSessionFixture = {
  accountId: string;
  sessionId: string;
  accessToken: string;
  refreshToken: string;
  installationId: string;
};

export type ProvisionedConsumerFixture = {
  accountId: string;
  phoneNumber: string;
  installationId: string;
  secondInstallationId: string;
  mobileAccessToken: string;
};

export async function provisionConsumerWithHistory(
  request: APIRequestContext,
): Promise<ProvisionedConsumerFixture> {
  const phoneNumber = `138${uniqueDigits(8)}`;
  const installationId = `install-alpha-${uniqueSuffix()}`;
  const secondInstallationId = `install-beta-${uniqueSuffix()}`;

  const firstChallengeId = await createMobileChallenge(request, phoneNumber);
  const firstSession = await verifyMobileChallenge(request, firstChallengeId, installationId);
  await acceptMobileConsent(request, firstSession.accessToken);

  const secondChallengeId = await createMobileChallenge(request, phoneNumber);
  const secondSession = await verifyMobileChallenge(request, secondChallengeId, secondInstallationId);
  await acceptMobileConsent(request, secondSession.accessToken);

  return {
    accountId: firstSession.accountId,
    phoneNumber,
    installationId,
    secondInstallationId,
    mobileAccessToken: firstSession.accessToken,
  };
}

export async function createMobileChallenge(request: APIRequestContext, phoneNumber: string): Promise<string> {
  const payload = await expectJson<{ challengeId?: unknown }>(
    await request.post(`${appApiBaseUrl}/api/v1/auth/challenges`, {
      headers: mobileJsonHeaders(),
      data: {
        phoneNumber,
      },
    }),
    201,
    `create challenge for ${phoneNumber}`,
  );

  const challengeId = requireNonEmptyString(payload.challengeId, 'challengeId', 'create challenge');
  return challengeId;
}

export async function verifyMobileChallenge(
  request: APIRequestContext,
  challengeId: string,
  installationId: string,
): Promise<MobileSessionFixture> {
  const payload = await expectJson<{
    accountId?: unknown;
    sessionId?: unknown;
    accessToken?: unknown;
    refreshToken?: unknown;
  }>(
    await request.post(`${appApiBaseUrl}/api/v1/auth/verify`, {
      headers: mobileJsonHeaders(),
      data: {
        challengeId,
        verificationCode: '246810',
        installationId,
      },
    }),
    200,
    `verify challenge ${challengeId}`,
  );

  return {
    accountId: requireNonEmptyString(payload.accountId, 'accountId', 'verify challenge'),
    sessionId: requireNonEmptyString(payload.sessionId, 'sessionId', 'verify challenge'),
    accessToken: requireNonEmptyString(payload.accessToken, 'accessToken', 'verify challenge'),
    refreshToken: requireNonEmptyString(payload.refreshToken, 'refreshToken', 'verify challenge'),
    installationId,
  };
}

export async function acceptMobileConsent(
  request: APIRequestContext,
  accessToken: string,
  consentVersion = 'pipl-v1',
): Promise<void> {
  await expectJson(
    await request.post(`${appApiBaseUrl}/api/v1/consent/accept`, {
      headers: mobileJsonHeaders(accessToken),
      data: {
        consentVersion,
      },
    }),
    200,
    `accept consent ${consentVersion}`,
  );
}

export async function bootstrapWithAccessToken(
  request: APIRequestContext,
  installationId: string,
  accessToken: string,
): Promise<APIResponse> {
  return await request.get(`${appApiBaseUrl}/api/v1/bootstrap?installationId=${encodeURIComponent(installationId)}`, {
    headers: {
      ...mobileAppVersionHeaders,
      Authorization: `Bearer ${accessToken}`,
    },
  });
}

function mobileJsonHeaders(accessToken?: string): Record<string, string> {
  return accessToken
    ? {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        ...mobileAppVersionHeaders,
      }
    : {
        'Content-Type': 'application/json',
        ...mobileAppVersionHeaders,
      };
}

function requireNonEmptyString(value: unknown, field: string, label: string): string {
  if (typeof value !== 'string' || !value.trim()) {
    throw new Error(`[mobile-api helper] ${label} returned invalid fixture payload: missing ${field}.`);
  }
  return value;
}

async function expectJson<T>(response: APIResponse, expectedStatus: number, label: string): Promise<T> {
  const bodyText = await response.text();
  if (response.status() !== expectedStatus) {
    throw new Error(
      `[mobile-api helper] ${label} failed: expected HTTP ${expectedStatus}, received ${response.status()}. Body: ${bodyText}`,
    );
  }

  if (!bodyText) {
    throw new Error(`[mobile-api helper] ${label} returned an empty body.`);
  }

  try {
    return JSON.parse(bodyText) as T;
  } catch (error) {
    throw new Error(
      `[mobile-api helper] ${label} returned invalid fixture payload: ${error instanceof Error ? error.message : String(error)}. Body: ${bodyText}`,
    );
  }
}

function uniqueSuffix(): string {
  return `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
}

function uniqueDigits(length: number): string {
  return Array.from({ length }, () => Math.floor(Math.random() * 10)).join('');
}
