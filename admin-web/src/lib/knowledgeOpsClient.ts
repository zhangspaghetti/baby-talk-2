import { ApiError, requestJson } from './authClient';

export const KNOWLEDGE_OPS_VIEWS = ['ingestion', 'kg-review'] as const;
export const KNOWLEDGE_INGESTION_STATUSES = ['PENDING', 'PROCESSING', 'COMPLETED', 'FAILED'] as const;
export const KNOWLEDGE_INGESTION_FILTERS = ['all', ...KNOWLEDGE_INGESTION_STATUSES] as const;
export const KNOWLEDGE_CONTRADICTION_STATUSES = ['detected', 'reviewing', 'escalated', 'resolved', 'dismissed'] as const;
export const KNOWLEDGE_CONTRADICTION_FILTERS = ['all', ...KNOWLEDGE_CONTRADICTION_STATUSES] as const;

export type KnowledgeOpsView = (typeof KNOWLEDGE_OPS_VIEWS)[number];
export type KnowledgeIngestionStatus = (typeof KNOWLEDGE_INGESTION_STATUSES)[number];
export type KnowledgeIngestionFilter = (typeof KNOWLEDGE_INGESTION_FILTERS)[number];
export type KnowledgeContradictionStatus = (typeof KNOWLEDGE_CONTRADICTION_STATUSES)[number];
export type KnowledgeContradictionFilter = (typeof KNOWLEDGE_CONTRADICTION_FILTERS)[number];

export interface KnowledgeOpsListQuery {
  status?: string;
  limit?: number;
}

export interface KnowledgeIngestionJobView {
  id: string;
  originalFilename: string;
  status: KnowledgeIngestionStatus;
  totalChunks: number;
  errorMessage?: string;
  createdAt: string;
  updatedAt: string;
  retryable: boolean;
}

export interface KnowledgeIngestionJobMutationView {
  jobId: string;
  originalFilename: string;
  status: KnowledgeIngestionStatus;
  updatedAt: string;
  errorMessage?: string;
  canRetry: boolean;
}

export interface KnowledgeContradictionQueueItemView {
  id: string;
  entityTopic: string;
  sourceABook: string;
  sourceBBook: string;
  description: string;
  status: KnowledgeContradictionStatus;
  adminNotes?: string;
  detectedAt: string;
  reviewedAt?: string;
  resolvedAt?: string;
  notificationCount: number;
  unreadNotificationCount: number;
}

export interface KnowledgeContradictionDetailView {
  id: string;
  entityTopic: string;
  sourceABook: string;
  sourceBBook: string;
  description: string;
  status: KnowledgeContradictionStatus;
  agentReviewResult?: string;
  adminNotes?: string;
  detectedAt: string;
  reviewedAt?: string;
  resolvedAt?: string;
  notificationCount: number;
  unreadNotificationCount: number;
}

export interface KnowledgeNotificationView {
  id: string;
  contradictionId: string;
  notificationType: string;
  message: string;
  isRead: boolean;
  createdAt: string;
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

function parseIngestionJob(payload: unknown, scope: string): KnowledgeIngestionJobView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', `${scope} 不是对象。`);
  }

  return {
    id: readRequiredString(payload, 'id', `${scope} 缺少 id。`),
    originalFilename: readRequiredString(payload, 'originalFilename', `${scope} 缺少 originalFilename。`),
    status: readEnumValue(payload, 'status', KNOWLEDGE_INGESTION_STATUSES, `${scope} 缺少合法 status。`),
    totalChunks: readRequiredNumber(payload, 'totalChunks', `${scope} 缺少 totalChunks。`),
    errorMessage: readOptionalString(payload, 'errorMessage'),
    createdAt: readRequiredString(payload, 'createdAt', `${scope} 缺少 createdAt。`),
    updatedAt: readRequiredString(payload, 'updatedAt', `${scope} 缺少 updatedAt。`),
    retryable: readRequiredBoolean(payload, 'retryable', `${scope} 缺少 retryable。`),
  };
}

function parseIngestionMutation(payload: unknown): KnowledgeIngestionJobMutationView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'ingestion mutation 响应不是对象。');
  }

  return {
    jobId: readRequiredString(payload, 'jobId', 'ingestion mutation 响应缺少 jobId。'),
    originalFilename: readRequiredString(payload, 'originalFilename', 'ingestion mutation 响应缺少 originalFilename。'),
    status: readEnumValue(payload, 'status', KNOWLEDGE_INGESTION_STATUSES, 'ingestion mutation 响应缺少合法 status。'),
    updatedAt: readRequiredString(payload, 'updatedAt', 'ingestion mutation 响应缺少 updatedAt。'),
    errorMessage: readOptionalString(payload, 'errorMessage'),
    canRetry: readRequiredBoolean(payload, 'canRetry', 'ingestion mutation 响应缺少 canRetry。'),
  };
}

function parseContradictionQueueItem(payload: unknown, scope: string): KnowledgeContradictionQueueItemView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', `${scope} 不是对象。`);
  }

  return {
    id: readRequiredString(payload, 'id', `${scope} 缺少 id。`),
    entityTopic: readRequiredString(payload, 'entityTopic', `${scope} 缺少 entityTopic。`),
    sourceABook: readRequiredString(payload, 'sourceABook', `${scope} 缺少 sourceABook。`),
    sourceBBook: readRequiredString(payload, 'sourceBBook', `${scope} 缺少 sourceBBook。`),
    description: readRequiredString(payload, 'description', `${scope} 缺少 description。`),
    status: readEnumValue(payload, 'status', KNOWLEDGE_CONTRADICTION_STATUSES, `${scope} 缺少合法 status。`),
    adminNotes: readOptionalString(payload, 'adminNotes'),
    detectedAt: readRequiredString(payload, 'detectedAt', `${scope} 缺少 detectedAt。`),
    reviewedAt: readOptionalString(payload, 'reviewedAt'),
    resolvedAt: readOptionalString(payload, 'resolvedAt'),
    notificationCount: readRequiredNumber(payload, 'notificationCount', `${scope} 缺少 notificationCount。`),
    unreadNotificationCount: readRequiredNumber(
      payload,
      'unreadNotificationCount',
      `${scope} 缺少 unreadNotificationCount。`,
    ),
  };
}

function parseContradictionDetail(payload: unknown): KnowledgeContradictionDetailView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'knowledge contradiction detail 响应不是对象。');
  }

  return {
    id: readRequiredString(payload, 'id', 'knowledge contradiction detail 缺少 id。'),
    entityTopic: readRequiredString(payload, 'entityTopic', 'knowledge contradiction detail 缺少 entityTopic。'),
    sourceABook: readRequiredString(payload, 'sourceABook', 'knowledge contradiction detail 缺少 sourceABook。'),
    sourceBBook: readRequiredString(payload, 'sourceBBook', 'knowledge contradiction detail 缺少 sourceBBook。'),
    description: readRequiredString(payload, 'description', 'knowledge contradiction detail 缺少 description。'),
    status: readEnumValue(
      payload,
      'status',
      KNOWLEDGE_CONTRADICTION_STATUSES,
      'knowledge contradiction detail 缺少合法 status。',
    ),
    agentReviewResult: readOptionalString(payload, 'agentReviewResult'),
    adminNotes: readOptionalString(payload, 'adminNotes'),
    detectedAt: readRequiredString(payload, 'detectedAt', 'knowledge contradiction detail 缺少 detectedAt。'),
    reviewedAt: readOptionalString(payload, 'reviewedAt'),
    resolvedAt: readOptionalString(payload, 'resolvedAt'),
    notificationCount: readRequiredNumber(payload, 'notificationCount', 'knowledge contradiction detail 缺少 notificationCount。'),
    unreadNotificationCount: readRequiredNumber(
      payload,
      'unreadNotificationCount',
      'knowledge contradiction detail 缺少 unreadNotificationCount。',
    ),
  };
}

function parseNotification(payload: unknown, scope: string): KnowledgeNotificationView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', `${scope} 不是对象。`);
  }

  return {
    id: readRequiredString(payload, 'id', `${scope} 缺少 id。`),
    contradictionId: readRequiredString(payload, 'contradictionId', `${scope} 缺少 contradictionId。`),
    notificationType: readRequiredString(payload, 'notificationType', `${scope} 缺少 notificationType。`),
    message: readRequiredString(payload, 'message', `${scope} 缺少 message。`),
    isRead: readRequiredBoolean(payload, 'isRead', `${scope} 缺少 isRead。`),
    createdAt: readRequiredString(payload, 'createdAt', `${scope} 缺少 createdAt。`),
  };
}

function parseList<T>(payload: unknown, parseItem: (item: unknown, index: number) => T, scope: string): T[] {
  if (!Array.isArray(payload)) {
    throw new ApiError(502, 'invalid_response_payload', `${scope} 响应不是数组。`);
  }
  return payload.map((item, index) => parseItem(item, index));
}

function buildListQueryString(query: KnowledgeOpsListQuery = {}): string {
  const params = new URLSearchParams();
  if (query.status) {
    params.set('status', query.status);
  }
  if (query.limit != null) {
    params.set('limit', String(query.limit));
  }
  const rendered = params.toString();
  return rendered ? `?${rendered}` : '';
}

export const knowledgeOpsClient = {
  async listIngestionJobs(query: KnowledgeOpsListQuery = {}) {
    const payload = await requestJson(`/api/admin/knowledge/ingestion/jobs${buildListQueryString(query)}`);
    return parseList(payload, (item, index) => parseIngestionJob(item, `ingestionJobs[${index}]`), 'ingestion jobs');
  },

  async getIngestionJob(jobId: string) {
    const payload = await requestJson(`/api/admin/knowledge/ingestion/jobs/${encodeURIComponent(jobId)}`);
    return parseIngestionJob(payload, 'ingestionJob');
  },

  async uploadIngestion(file: File, bookTitle?: string) {
    const body = new FormData();
    body.set('file', file);
    const normalizedBookTitle = bookTitle?.trim();
    if (normalizedBookTitle) {
      body.set('bookTitle', normalizedBookTitle);
    }
    const payload = await requestJson('/api/admin/knowledge/ingestion/upload', {
      method: 'POST',
      body,
    });
    return parseIngestionMutation(payload);
  },

  async retryIngestionJob(jobId: string) {
    const payload = await requestJson(`/api/admin/knowledge/ingestion/jobs/${encodeURIComponent(jobId)}/retry`, {
      method: 'POST',
    });
    return parseIngestionMutation(payload);
  },

  async listContradictions(query: KnowledgeOpsListQuery = {}) {
    const payload = await requestJson(`/api/admin/knowledge/kg/contradictions${buildListQueryString(query)}`);
    return parseList(
      payload,
      (item, index) => parseContradictionQueueItem(item, `contradictions[${index}]`),
      'knowledge contradictions',
    );
  },

  async getContradiction(contradictionId: string) {
    const payload = await requestJson(`/api/admin/knowledge/kg/contradictions/${encodeURIComponent(contradictionId)}`);
    return parseContradictionDetail(payload);
  },

  async listNotifications(contradictionId: string, query: Pick<KnowledgeOpsListQuery, 'limit'> = {}) {
    const payload = await requestJson(
      `/api/admin/knowledge/kg/contradictions/${encodeURIComponent(contradictionId)}/notifications${buildListQueryString(query)}`,
    );
    return parseList(
      payload,
      (item, index) => parseNotification(item, `notifications[${index}]`),
      'knowledge notifications',
    );
  },

  async resolveContradiction(contradictionId: string, adminNotes?: string) {
    const payload = await requestJson(`/api/admin/knowledge/kg/contradictions/${encodeURIComponent(contradictionId)}/resolve`, {
      method: 'PATCH',
      body: adminNotes?.trim() ? { adminNotes: adminNotes.trim() } : {},
    });
    return parseContradictionDetail(payload);
  },

  async markNotificationRead(notificationId: string) {
    const payload = await requestJson(`/api/admin/knowledge/kg/notifications/${encodeURIComponent(notificationId)}/read`, {
      method: 'PATCH',
    });
    return parseNotification(payload, 'notification');
  },
};
