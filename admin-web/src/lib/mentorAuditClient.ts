import { ApiError, requestJson } from './authClient';

export const MENTOR_AUDIT_FLAGS = [
  'blocked_fallback',
  'rate_limited',
  'provider_timeout',
  'provider_malformed_response',
  'provider_unavailable',
  'invalid_session',
  'consent_revoked',
  'account_deleted',
  'session_installation_mismatch',
  'other_incident',
] as const;

export type MentorAuditFlag = (typeof MENTOR_AUDIT_FLAGS)[number];

export interface MentorAuditQuery {
  installationId?: string;
  flag?: string;
  limit?: number;
}

export interface MentorAuditQueueItem {
  correlationId: string;
  installationId: string;
  flagCode: string;
  latestPhase: string;
  failureCode?: string;
  retryable: boolean;
  historicalRateLimited: boolean;
  occurredAt: string;
}

export interface MentorAuditDetail {
  scope: string;
  correlationId: string;
  installationId: string;
  flagCode: string;
  latestPhase: string;
  failureCode?: string;
  retryable: boolean;
  historicalRateLimited: boolean;
  occurredAt: string;
  requestEvidence: {
    summary?: string;
  };
  deliveryState: string;
  deliveredResponse?: {
    result: string;
    phase: string;
    responseSummary?: string;
    responseText: string;
    blockedFallback: boolean;
    providerMode: string;
    retryable: boolean;
    createdAt: string;
  };
  timeline: Array<{
    auditId: number;
    eventType: string;
    phase: string;
    result: string;
    requestSummary?: string;
    responseSummary?: string;
    reason?: string;
    failureCode?: string;
    retryable: boolean;
    rateLimited: boolean;
    createdAt: string;
  }>;
  liveRateLimit: {
    limited: boolean;
    currentCount: number;
    limit: number;
    remaining: number;
    windowSeconds: number;
  };
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

function readRequiredNumber(record: Record<string, unknown>, key: string, message: string): number {
  const value = record[key];
  if (typeof value !== 'number' || Number.isNaN(value)) {
    throw new ApiError(502, 'invalid_response_payload', message, { field: key });
  }
  return value;
}

function parseQueueItem(payload: unknown): MentorAuditQueueItem {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'mentor audit queue item 不是对象。');
  }

  return {
    correlationId: readRequiredString(payload, 'correlationId', 'mentor audit queue item 缺少 correlationId。'),
    installationId: readRequiredString(payload, 'installationId', 'mentor audit queue item 缺少 installationId。'),
    flagCode: readRequiredString(payload, 'flagCode', 'mentor audit queue item 缺少 flagCode。'),
    latestPhase: readRequiredString(payload, 'latestPhase', 'mentor audit queue item 缺少 latestPhase。'),
    failureCode: readOptionalString(payload, 'failureCode'),
    retryable: readRequiredBoolean(payload, 'retryable', 'mentor audit queue item 缺少 retryable。'),
    historicalRateLimited: readRequiredBoolean(
      payload,
      'historicalRateLimited',
      'mentor audit queue item 缺少 historicalRateLimited。',
    ),
    occurredAt: readRequiredString(payload, 'occurredAt', 'mentor audit queue item 缺少 occurredAt。'),
  };
}

function parseQueue(payload: unknown): MentorAuditQueueItem[] {
  if (!Array.isArray(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'mentor audit queue 响应不是数组。');
  }

  return payload.map((item) => parseQueueItem(item));
}

function parseDetail(payload: unknown): MentorAuditDetail {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'mentor audit detail 响应不是对象。');
  }

  const requestEvidencePayload = payload.requestEvidence;
  if (!isRecord(requestEvidencePayload)) {
    throw new ApiError(502, 'invalid_response_payload', 'mentor audit detail 缺少 requestEvidence。');
  }

  const timelinePayload = payload.timeline;
  if (!Array.isArray(timelinePayload)) {
    throw new ApiError(502, 'invalid_response_payload', 'mentor audit detail 缺少 timeline。');
  }

  const liveRateLimitPayload = payload.liveRateLimit;
  if (!isRecord(liveRateLimitPayload)) {
    throw new ApiError(502, 'invalid_response_payload', 'mentor audit detail 缺少 liveRateLimit。');
  }

  let deliveredResponse: MentorAuditDetail['deliveredResponse'];
  if (payload.deliveredResponse != null) {
    if (!isRecord(payload.deliveredResponse)) {
      throw new ApiError(502, 'invalid_response_payload', 'mentor audit detail 的 deliveredResponse 格式不正确。');
    }

    deliveredResponse = {
      result: readRequiredString(payload.deliveredResponse, 'result', 'deliveredResponse 缺少 result。'),
      phase: readRequiredString(payload.deliveredResponse, 'phase', 'deliveredResponse 缺少 phase。'),
      responseSummary: readOptionalString(payload.deliveredResponse, 'responseSummary'),
      responseText: readRequiredString(payload.deliveredResponse, 'responseText', 'deliveredResponse 缺少 responseText。'),
      blockedFallback: readRequiredBoolean(
        payload.deliveredResponse,
        'blockedFallback',
        'deliveredResponse 缺少 blockedFallback。',
      ),
      providerMode: readRequiredString(payload.deliveredResponse, 'providerMode', 'deliveredResponse 缺少 providerMode。'),
      retryable: readRequiredBoolean(payload.deliveredResponse, 'retryable', 'deliveredResponse 缺少 retryable。'),
      createdAt: readRequiredString(payload.deliveredResponse, 'createdAt', 'deliveredResponse 缺少 createdAt。'),
    };
  }

  return {
    scope: readRequiredString(payload, 'scope', 'mentor audit detail 缺少 scope。'),
    correlationId: readRequiredString(payload, 'correlationId', 'mentor audit detail 缺少 correlationId。'),
    installationId: readRequiredString(payload, 'installationId', 'mentor audit detail 缺少 installationId。'),
    flagCode: readRequiredString(payload, 'flagCode', 'mentor audit detail 缺少 flagCode。'),
    latestPhase: readRequiredString(payload, 'latestPhase', 'mentor audit detail 缺少 latestPhase。'),
    failureCode: readOptionalString(payload, 'failureCode'),
    retryable: readRequiredBoolean(payload, 'retryable', 'mentor audit detail 缺少 retryable。'),
    historicalRateLimited: readRequiredBoolean(
      payload,
      'historicalRateLimited',
      'mentor audit detail 缺少 historicalRateLimited。',
    ),
    occurredAt: readRequiredString(payload, 'occurredAt', 'mentor audit detail 缺少 occurredAt。'),
    requestEvidence: {
      summary: readOptionalString(requestEvidencePayload, 'summary'),
    },
    deliveryState: readRequiredString(payload, 'deliveryState', 'mentor audit detail 缺少 deliveryState。'),
    deliveredResponse,
    timeline: timelinePayload.map((entry) => {
      if (!isRecord(entry)) {
        throw new ApiError(502, 'invalid_response_payload', 'mentor audit timeline item 格式不正确。');
      }
      return {
        auditId: readRequiredNumber(entry, 'auditId', 'mentor audit timeline item 缺少 auditId。'),
        eventType: readRequiredString(entry, 'eventType', 'mentor audit timeline item 缺少 eventType。'),
        phase: readRequiredString(entry, 'phase', 'mentor audit timeline item 缺少 phase。'),
        result: readRequiredString(entry, 'result', 'mentor audit timeline item 缺少 result。'),
        requestSummary: readOptionalString(entry, 'requestSummary'),
        responseSummary: readOptionalString(entry, 'responseSummary'),
        reason: readOptionalString(entry, 'reason'),
        failureCode: readOptionalString(entry, 'failureCode'),
        retryable: readRequiredBoolean(entry, 'retryable', 'mentor audit timeline item 缺少 retryable。'),
        rateLimited: readRequiredBoolean(entry, 'rateLimited', 'mentor audit timeline item 缺少 rateLimited。'),
        createdAt: readRequiredString(entry, 'createdAt', 'mentor audit timeline item 缺少 createdAt。'),
      };
    }),
    liveRateLimit: {
      limited: readRequiredBoolean(liveRateLimitPayload, 'limited', 'liveRateLimit 缺少 limited。'),
      currentCount: readRequiredNumber(liveRateLimitPayload, 'currentCount', 'liveRateLimit 缺少 currentCount。'),
      limit: readRequiredNumber(liveRateLimitPayload, 'limit', 'liveRateLimit 缺少 limit。'),
      remaining: readRequiredNumber(liveRateLimitPayload, 'remaining', 'liveRateLimit 缺少 remaining。'),
      windowSeconds: readRequiredNumber(
        liveRateLimitPayload,
        'windowSeconds',
        'liveRateLimit 缺少 windowSeconds。',
      ),
    },
  };
}

function buildQueryString(query: MentorAuditQuery): string {
  const params = new URLSearchParams();
  if (query.installationId) {
    params.set('installationId', query.installationId);
  }
  if (query.flag) {
    params.set('flag', query.flag);
  }
  if (query.limit) {
    params.set('limit', String(query.limit));
  }
  const rendered = params.toString();
  return rendered ? `?${rendered}` : '';
}

export const mentorAuditClient = {
  async listAudits(query: MentorAuditQuery = {}) {
    const payload = await requestJson(`/api/admin/mentor/audits${buildQueryString(query)}`);
    return parseQueue(payload);
  },

  async getAudit(correlationId: string) {
    const encodedCorrelationId = encodeURIComponent(correlationId);
    const payload = await requestJson(`/api/admin/mentor/audits/${encodedCorrelationId}`);
    return parseDetail(payload);
  },
};
