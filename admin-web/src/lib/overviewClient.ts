import {
  ApiError,
  clearStoredSession,
  loadStoredSession,
  persistStoredSession,
  requestJson,
  toApiError,
} from './authClient';
import { authApi } from '../auth/auth-api';

export const OVERVIEW_DOMAIN_KEYS = [
  'knowledge_ingestion',
  'knowledge_kg',
  'mentor_audit',
  'distribution',
] as const;
export const OVERVIEW_FRESHNESS_STATES = [
  'all_clear',
  'updating',
  'fresh',
  'stale',
  'degraded',
  'forbidden',
] as const;
export const OVERVIEW_TRANSPORT_MODES = ['live', 'polling_required'] as const;

export type OverviewDomainKey = (typeof OVERVIEW_DOMAIN_KEYS)[number];
export type OverviewFreshnessState = (typeof OVERVIEW_FRESHNESS_STATES)[number];
export type OverviewTransportMode = (typeof OVERVIEW_TRANSPORT_MODES)[number];

export interface OverviewTransportView {
  eventId: string;
  mode: OverviewTransportMode;
  degradedReason?: string;
  emittedAt: string;
  lastSuccessfulSnapshotAt?: string;
  activeSubscriberCount: number;
  connectionCount: number;
  reconnectCount: number;
  replayed: boolean;
}

export interface OverviewHeartbeatView {
  mode: OverviewTransportMode;
  degradedReason?: string;
  emittedAt: string;
  lastSuccessfulSnapshotAt?: string;
  activeSubscriberCount: number;
}

export interface OverviewFreshnessView {
  state: OverviewFreshnessState;
  sourceUpdatedAt?: string;
  staleAfterSeconds: number;
  degradedReason?: string;
}

export interface OverviewQueueView {
  queueCount?: number;
  attentionCount?: number;
  allClear?: boolean;
}

export interface OverviewNextActionView {
  code: string;
  label: string;
  href?: string;
}

export interface OverviewCountView {
  key: string;
  value: number;
}

export interface OverviewDomainView {
  key: OverviewDomainKey;
  title: string;
  requiredPermission: string;
  visible: boolean;
  freshness: OverviewFreshnessView;
  queue: OverviewQueueView;
  nextAction: OverviewNextActionView;
  counts: OverviewCountView[];
}

export interface OverviewSummaryView {
  generatedAt: string;
  lastSuccessfulSnapshotAt?: string;
  visibleDomainCount: number;
  degradedDomainCount: number;
  transport: OverviewTransportView;
  domains: OverviewDomainView[];
}

export interface OverviewTransportSubscriptionOptions {
  lastEventId?: string;
  onOpen?: () => void;
  onTransport: (transport: OverviewTransportView) => void;
  onHeartbeat?: (heartbeat: OverviewHeartbeatView) => void;
  onClose?: () => void;
  onError?: (error: ApiError) => void;
}

export interface OverviewTransportSubscription {
  close: () => void;
  closed: Promise<void>;
}

type ParsedSseEvent = {
  event: string;
  data: string;
  id?: string;
};

let inFlightStreamRefresh: Promise<void> | null = null;

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

function readOptionalNumber(record: Record<string, unknown>, key: string): number | undefined {
  const value = record[key];
  if (value == null) {
    return undefined;
  }
  if (typeof value !== 'number' || Number.isNaN(value)) {
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

function readOptionalBoolean(record: Record<string, unknown>, key: string): boolean | undefined {
  const value = record[key];
  if (value == null) {
    return undefined;
  }
  if (typeof value !== 'boolean') {
    throw new ApiError(502, 'invalid_response_payload', `字段 ${key} 的类型不正确。`, { field: key });
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

function parseTransport(payload: unknown): OverviewTransportView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'overview transport 不是对象。');
  }

  return {
    eventId: readRequiredString(payload, 'eventId', 'overview transport 缺少 eventId。'),
    mode: readEnumValue(payload, 'mode', OVERVIEW_TRANSPORT_MODES, 'overview transport 缺少合法 mode。'),
    degradedReason: readOptionalString(payload, 'degradedReason'),
    emittedAt: readRequiredString(payload, 'emittedAt', 'overview transport 缺少 emittedAt。'),
    lastSuccessfulSnapshotAt: readOptionalString(payload, 'lastSuccessfulSnapshotAt'),
    activeSubscriberCount: readRequiredNumber(
      payload,
      'activeSubscriberCount',
      'overview transport 缺少 activeSubscriberCount。',
    ),
    connectionCount: readRequiredNumber(payload, 'connectionCount', 'overview transport 缺少 connectionCount。'),
    reconnectCount: readRequiredNumber(payload, 'reconnectCount', 'overview transport 缺少 reconnectCount。'),
    replayed: readRequiredBoolean(payload, 'replayed', 'overview transport 缺少 replayed。'),
  };
}

function parseHeartbeat(payload: unknown): OverviewHeartbeatView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'overview heartbeat 不是对象。');
  }

  return {
    mode: readEnumValue(payload, 'mode', OVERVIEW_TRANSPORT_MODES, 'overview heartbeat 缺少合法 mode。'),
    degradedReason: readOptionalString(payload, 'degradedReason'),
    emittedAt: readRequiredString(payload, 'emittedAt', 'overview heartbeat 缺少 emittedAt。'),
    lastSuccessfulSnapshotAt: readOptionalString(payload, 'lastSuccessfulSnapshotAt'),
    activeSubscriberCount: readRequiredNumber(
      payload,
      'activeSubscriberCount',
      'overview heartbeat 缺少 activeSubscriberCount。',
    ),
  };
}

function parseOverviewCount(payload: unknown, scope: string): OverviewCountView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', `${scope} 不是对象。`);
  }

  return {
    key: readRequiredString(payload, 'key', `${scope} 缺少 key。`),
    value: readRequiredNumber(payload, 'value', `${scope} 缺少 value。`),
  };
}

function parseOverviewFreshness(payload: unknown, scope: string): OverviewFreshnessView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', `${scope} 不是对象。`);
  }

  return {
    state: readEnumValue(payload, 'state', OVERVIEW_FRESHNESS_STATES, `${scope} 缺少合法 state。`),
    sourceUpdatedAt: readOptionalString(payload, 'sourceUpdatedAt'),
    staleAfterSeconds: readRequiredNumber(payload, 'staleAfterSeconds', `${scope} 缺少 staleAfterSeconds。`),
    degradedReason: readOptionalString(payload, 'degradedReason'),
  };
}

function parseOverviewQueue(payload: unknown, scope: string): OverviewQueueView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', `${scope} 不是对象。`);
  }

  return {
    queueCount: readOptionalNumber(payload, 'queueCount'),
    attentionCount: readOptionalNumber(payload, 'attentionCount'),
    allClear: readOptionalBoolean(payload, 'allClear'),
  };
}

function parseOverviewNextAction(payload: unknown, scope: string): OverviewNextActionView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', `${scope} 不是对象。`);
  }

  return {
    code: readRequiredString(payload, 'code', `${scope} 缺少 code。`),
    label: readRequiredString(payload, 'label', `${scope} 缺少 label。`),
    href: readOptionalString(payload, 'href'),
  };
}

function parseOverviewDomain(payload: unknown, scope: string): OverviewDomainView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', `${scope} 不是对象。`);
  }

  const counts = payload.counts;
  if (!Array.isArray(counts)) {
    throw new ApiError(502, 'invalid_response_payload', `${scope} 缺少合法 counts。`, { field: 'counts' });
  }

  return {
    key: readEnumValue(payload, 'key', OVERVIEW_DOMAIN_KEYS, `${scope} 缺少合法 key。`),
    title: readRequiredString(payload, 'title', `${scope} 缺少 title。`),
    requiredPermission: readRequiredString(payload, 'requiredPermission', `${scope} 缺少 requiredPermission。`),
    visible: readRequiredBoolean(payload, 'visible', `${scope} 缺少 visible。`),
    freshness: parseOverviewFreshness(payload.freshness, `${scope}.freshness`),
    queue: parseOverviewQueue(payload.queue, `${scope}.queue`),
    nextAction: parseOverviewNextAction(payload.nextAction, `${scope}.nextAction`),
    counts: counts.map((item, index) => parseOverviewCount(item, `${scope}.counts[${index}]`)),
  };
}

export function parseOverviewSummary(payload: unknown): OverviewSummaryView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'overview summary 响应不是对象。');
  }

  const rawDomains = payload.domains;
  if (!Array.isArray(rawDomains)) {
    throw new ApiError(502, 'invalid_response_payload', 'overview summary 缺少合法 domains。', { field: 'domains' });
  }

  const domains = rawDomains.map((item, index) => parseOverviewDomain(item, `domains[${index}]`));
  const seenKeys = new Set<OverviewDomainKey>();
  for (const domain of domains) {
    if (seenKeys.has(domain.key)) {
      throw new ApiError(502, 'invalid_response_payload', 'overview summary 含重复 domain key。', { key: domain.key });
    }
    seenKeys.add(domain.key);
  }
  for (const domainKey of OVERVIEW_DOMAIN_KEYS) {
    if (!seenKeys.has(domainKey)) {
      throw new ApiError(502, 'invalid_response_payload', 'overview summary 缺少 domain。', { key: domainKey });
    }
  }

  return {
    generatedAt: readRequiredString(payload, 'generatedAt', 'overview summary 缺少 generatedAt。'),
    lastSuccessfulSnapshotAt: readOptionalString(payload, 'lastSuccessfulSnapshotAt'),
    visibleDomainCount: readRequiredNumber(payload, 'visibleDomainCount', 'overview summary 缺少 visibleDomainCount。'),
    degradedDomainCount: readRequiredNumber(payload, 'degradedDomainCount', 'overview summary 缺少 degradedDomainCount。'),
    transport: parseTransport(payload.transport),
    domains,
  };
}

function parseErrorPayload(status: number, bodyText: string): ApiError {
  if (!bodyText.trim()) {
    return new ApiError(status, 'request_failed', `请求失败（HTTP ${status}）。`);
  }

  try {
    const parsed = JSON.parse(bodyText) as unknown;
    if (isRecord(parsed)) {
      return new ApiError(
        typeof parsed.status === 'number' ? parsed.status : status,
        typeof parsed.code === 'string' && parsed.code.trim() ? parsed.code : 'request_failed',
        typeof parsed.message === 'string' && parsed.message.trim()
          ? parsed.message
          : `请求失败（HTTP ${status}）。`,
        isRecord(parsed.details) ? parsed.details : {},
      );
    }
  } catch {
    // Fall through to generic error.
  }

  return new ApiError(status, 'request_failed', `请求失败（HTTP ${status}）。`, {
    body: bodyText,
  });
}

function toStreamNetworkError(error: unknown): ApiError {
  if (error instanceof ApiError) {
    return error;
  }
  if (error instanceof DOMException && error.name === 'AbortError') {
    return new ApiError(0, 'request_aborted', '请求已中止。');
  }
  if (error instanceof TypeError) {
    return new ApiError(0, 'network_error', '无法连接 admin-api。请确认 admin-api 已启动。');
  }
  return toApiError(error);
}

function toSessionResetBanner(error: ApiError) {
  if (error.code === 'invalid_response_payload') {
    return {
      type: 'error' as const,
      message: '管理员身份响应异常，已清理本地会话，请重新登录。',
      code: error.code,
    };
  }

  return {
    type: error.status === 401 ? ('warning' as const) : ('error' as const),
    message: error.message,
    code: error.code,
  };
}

async function refreshStreamSession(): Promise<void> {
  if (inFlightStreamRefresh) {
    return inFlightStreamRefresh;
  }

  const refreshToken = loadStoredSession()?.refreshToken;
  if (!refreshToken) {
    const apiError = new ApiError(401, 'admin_session_invalid', '管理员会话已失效，请重新登录。');
    clearStoredSession(toSessionResetBanner(apiError));
    throw apiError;
  }

  const refreshPromise = authApi
    .refresh(refreshToken)
    .then((nextSession) => {
      persistStoredSession(nextSession);
    })
    .catch((error: unknown) => {
      const apiError = toApiError(error);
      clearStoredSession(toSessionResetBanner(apiError));
      throw apiError;
    })
    .finally(() => {
      inFlightStreamRefresh = null;
    });

  inFlightStreamRefresh = refreshPromise;
  return refreshPromise;
}

async function requestOverviewStreamResponse(input: {
  lastEventId?: string;
  signal: AbortSignal;
  retried?: boolean;
}): Promise<Response> {
  const url = new URL('/api/admin/overview/stream', window.location.origin);
  if (input.lastEventId) {
    url.searchParams.set('sinceEventId', input.lastEventId);
  }

  let response: Response;
  try {
    response = await fetch(url.toString(), {
      method: 'GET',
      headers: {
        Accept: 'text/event-stream',
      },
      credentials: 'include',
      cache: 'no-store',
      signal: input.signal,
    });
  } catch (error) {
    throw toStreamNetworkError(error);
  }

  if (response.status === 401 && input.retried !== true) {
    await refreshStreamSession();
    return requestOverviewStreamResponse({
      ...input,
      retried: true,
    });
  }

  if (!response.ok) {
    throw parseErrorPayload(response.status, await response.text());
  }

  const contentType = response.headers.get('content-type') ?? '';
  if (!contentType.toLowerCase().includes('text/event-stream')) {
    throw new ApiError(502, 'invalid_response_payload', 'overview stream 未返回 event-stream。', {
      contentType,
    });
  }

  if (!response.body) {
    throw new ApiError(502, 'invalid_response_payload', 'overview stream 未提供可读流。');
  }

  return response;
}

async function consumeEventStream(
  stream: ReadableStream<Uint8Array>,
  onEvent: (event: ParsedSseEvent) => void,
): Promise<void> {
  const reader = stream.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let eventName = '';
  let eventId: string | undefined;
  let dataLines: string[] = [];

  const dispatch = () => {
    if (dataLines.length === 0) {
      eventName = '';
      eventId = undefined;
      return;
    }

    onEvent({
      event: eventName || 'message',
      data: dataLines.join('\n'),
      id: eventId,
    });
    eventName = '';
    eventId = undefined;
    dataLines = [];
  };

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        buffer += decoder.decode();
        if (buffer.trim().length > 0) {
          const remainingLines = buffer.split(/\r?\n/);
          for (const remainingLine of remainingLines) {
            const normalizedLine = remainingLine.endsWith('\r') ? remainingLine.slice(0, -1) : remainingLine;
            if (normalizedLine === '') {
              dispatch();
              continue;
            }
            if (normalizedLine.startsWith(':')) {
              continue;
            }
            const colonIndex = normalizedLine.indexOf(':');
            const field = colonIndex === -1 ? normalizedLine : normalizedLine.slice(0, colonIndex);
            const rawValue = colonIndex === -1 ? '' : normalizedLine.slice(colonIndex + 1);
            const normalizedValue = rawValue.startsWith(' ') ? rawValue.slice(1) : rawValue;
            if (field === 'event') {
              eventName = normalizedValue;
            } else if (field === 'data') {
              dataLines.push(normalizedValue);
            } else if (field === 'id') {
              eventId = normalizedValue;
            }
          }
        }
        dispatch();
        return;
      }

      buffer += decoder.decode(value, { stream: true });
      let newlineIndex = buffer.indexOf('\n');
      while (newlineIndex >= 0) {
        const rawLine = buffer.slice(0, newlineIndex);
        buffer = buffer.slice(newlineIndex + 1);
        const line = rawLine.endsWith('\r') ? rawLine.slice(0, -1) : rawLine;

        if (line === '') {
          dispatch();
        } else if (!line.startsWith(':')) {
          const colonIndex = line.indexOf(':');
          const field = colonIndex === -1 ? line : line.slice(0, colonIndex);
          const rawValue = colonIndex === -1 ? '' : line.slice(colonIndex + 1);
          const normalizedValue = rawValue.startsWith(' ') ? rawValue.slice(1) : rawValue;
          if (field === 'event') {
            eventName = normalizedValue;
          } else if (field === 'data') {
            dataLines.push(normalizedValue);
          } else if (field === 'id') {
            eventId = normalizedValue;
          }
        }

        newlineIndex = buffer.indexOf('\n');
      }
    }
  } finally {
    reader.releaseLock();
  }
}

function parseStreamEvent(event: ParsedSseEvent): OverviewTransportView | OverviewHeartbeatView {
  let payload: unknown;
  try {
    payload = JSON.parse(event.data) as unknown;
  } catch {
    throw new ApiError(502, 'invalid_response_payload', `overview ${event.event} 不是合法 JSON。`);
  }

  if (event.event === 'transport') {
    return parseTransport(payload);
  }
  if (event.event === 'heartbeat') {
    return parseHeartbeat(payload);
  }
  throw new ApiError(502, 'invalid_response_payload', `overview stream 返回了未知事件类型：${event.event}`);
}

function mergeTransportWithHeartbeat(
  current: OverviewTransportView | null,
  heartbeat: OverviewHeartbeatView,
): OverviewTransportView | null {
  if (!current) {
    return null;
  }

  return {
    ...current,
    mode: heartbeat.mode,
    degradedReason: heartbeat.degradedReason,
    emittedAt: heartbeat.emittedAt,
    lastSuccessfulSnapshotAt: heartbeat.lastSuccessfulSnapshotAt,
    activeSubscriberCount: heartbeat.activeSubscriberCount,
  };
}

export const overviewClient = {
  async getSummary() {
    const payload = await requestJson('/api/admin/overview/summary');
    return parseOverviewSummary(payload);
  },

  subscribeTransport(options: OverviewTransportSubscriptionOptions): OverviewTransportSubscription {
    const controller = new AbortController();
    const closed = (async () => {
      try {
        const response = await requestOverviewStreamResponse({
          lastEventId: options.lastEventId,
          signal: controller.signal,
        });
        options.onOpen?.();
        let latestTransport: OverviewTransportView | null = null;
        await consumeEventStream(response.body!, (event) => {
          const parsedEvent = parseStreamEvent(event);
          if (event.event === 'transport') {
            latestTransport = parsedEvent as OverviewTransportView;
            options.onTransport(latestTransport);
            return;
          }

          const heartbeat = parsedEvent as OverviewHeartbeatView;
          const mergedTransport = mergeTransportWithHeartbeat(latestTransport, heartbeat);
          if (mergedTransport) {
            latestTransport = mergedTransport;
          }
          options.onHeartbeat?.(heartbeat);
        });

        if (!controller.signal.aborted) {
          options.onClose?.();
        }
      } catch (error) {
        if (controller.signal.aborted) {
          return;
        }
        options.onError?.(toStreamNetworkError(error));
      }
    })();

    return {
      close: () => controller.abort(),
      closed,
    };
  },
};
