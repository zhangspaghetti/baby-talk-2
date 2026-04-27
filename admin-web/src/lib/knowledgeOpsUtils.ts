import type { CSSProperties } from 'react';
import { ApiError } from './authClient';
import {
  KNOWLEDGE_CONTRADICTION_FILTERS,
  KNOWLEDGE_INGESTION_FILTERS,
  KNOWLEDGE_OPS_VIEWS,
  PALACE_BRIDGE_EDGE_STATUSES,
  PALACE_RAG_SUBVIEWS,
  type KnowledgeContradictionDetailView,
  type KnowledgeContradictionFilter,
  type KnowledgeContradictionStatus,
  type KnowledgeIngestionFilter,
  type KnowledgeIngestionJobMutationView,
  type KnowledgeIngestionStatus,
  type KnowledgeNotificationView,
  type KnowledgeOpsView,
  type PalaceBridgeEdgeStatus,
  type PalaceBridgeEdgeView,
  type PalaceRagSubview,
} from './knowledgeOpsClient';

export const DEFAULT_QUEUE_LIMIT = 20;
export const DEFAULT_NOTIFICATION_LIMIT = 20;
export const DEFAULT_VIEW: KnowledgeOpsView = 'ingestion';
export const DEFAULT_STATUS = 'all';
export const DEFAULT_PALACE_RAG_SUBVIEW: PalaceRagSubview = 'bridge-review';
export const DEFAULT_BRIDGE_REVIEW_STATUS: PalaceBridgeEdgeStatus = PALACE_BRIDGE_EDGE_STATUSES[0];
export const QUERY_PARAM_KEYS = ['view', 'status', 'selected'] as const;
export const MAX_INGESTION_POLL_ATTEMPTS = 8;

export type QueryState = {
  rawView?: string;
  rawStatus?: string;
  selected?: string;
  view: KnowledgeOpsView;
  viewWasNormalized: boolean;
  statusWasNormalized: boolean;
  ingestionStatus: KnowledgeIngestionFilter;
  kgStatus: KnowledgeContradictionFilter;
  palaceRagSubview: PalaceRagSubview;
};

export type KnowledgeQueryPatch = Partial<Record<(typeof QUERY_PARAM_KEYS)[number], string | undefined>>;

export type IngestionActionState =
  | { phase: 'idle' }
  | { phase: 'pending'; kind: 'upload' | 'retry'; target: string }
  | { phase: 'success'; kind: 'upload' | 'retry'; response: KnowledgeIngestionJobMutationView }
  | { phase: 'error'; kind: 'upload' | 'retry'; error: ApiError };

export type KgActionState =
  | { phase: 'idle' }
  | { phase: 'pending'; kind: 'resolve' | 'mark-read'; target: string }
  | { phase: 'success'; kind: 'resolve'; detail: KnowledgeContradictionDetailView }
  | { phase: 'success'; kind: 'mark-read'; notification: KnowledgeNotificationView }
  | { phase: 'error'; kind: 'resolve' | 'mark-read'; error: ApiError; target: string };

export type PalaceRagActionState =
  | { phase: 'idle' }
  | { phase: 'pending'; edgeId: string }
  | { phase: 'success'; edge: PalaceBridgeEdgeView }
  | { phase: 'error'; error: ApiError; edgeId: string };

export function readQueryState(searchParams: URLSearchParams, accessibleViews: KnowledgeOpsView[]): QueryState {
  const rawView = normalizeQueryValue(searchParams.get('view'));
  const rawStatus = normalizeQueryValue(searchParams.get('status'));
  const selected = normalizeQueryValue(searchParams.get('selected'));
  const accessibleFallback = accessibleViews[0] ?? DEFAULT_VIEW;
  const normalizedView = normalizeView(rawView, accessibleViews) ?? accessibleFallback;
  const normalizedIngestionStatus = normalizeIngestionFilter(rawStatus) ?? 'all';
  const normalizedKgStatus = normalizeKgFilter(rawStatus) ?? 'all';
  const normalizedPalaceSubview = normalizePalaceRagSubview(rawStatus) ?? DEFAULT_PALACE_RAG_SUBVIEW;

  return {
    rawView,
    rawStatus,
    selected,
    view: normalizedView,
    viewWasNormalized: Boolean(rawView && rawView !== normalizedView),
    statusWasNormalized: Boolean(
      rawStatus &&
        ((normalizedView === 'ingestion' && normalizeIngestionFilter(rawStatus) == null) ||
          (normalizedView === 'kg-review' && normalizeKgFilter(rawStatus) == null) ||
          (normalizedView === 'palace-rag' && normalizePalaceRagSubview(rawStatus) == null)),
    ),
    ingestionStatus: normalizedIngestionStatus,
    kgStatus: normalizedKgStatus,
    palaceRagSubview: normalizedPalaceSubview,
  };
}

export function patchKnowledgeQuery(
  currentSearchParams: URLSearchParams,
  setSearchParams: (nextParams: URLSearchParams, navigateOptions?: { replace?: boolean }) => void,
  patch: KnowledgeQueryPatch,
) {
  const nextParams = new URLSearchParams(currentSearchParams);
  for (const key of QUERY_PARAM_KEYS) {
    if (!(key in patch)) {
      continue;
    }
    const nextValue = patch[key];
    if (nextValue === undefined) {
      nextParams.delete(key);
    } else {
      nextParams.set(key, nextValue);
    }
  }
  setSearchParams(nextParams, { replace: false });
}

export function normalizeView(value: string | undefined, accessibleViews: KnowledgeOpsView[]): KnowledgeOpsView | undefined {
  if (!value || !includesTupleValue(KNOWLEDGE_OPS_VIEWS, value)) {
    return undefined;
  }
  return accessibleViews.includes(value) ? value : undefined;
}

export function normalizeIngestionFilter(value: string | undefined): KnowledgeIngestionFilter | undefined {
  if (!value || !includesTupleValue(KNOWLEDGE_INGESTION_FILTERS, value)) {
    return undefined;
  }
  return value;
}

export function normalizeKgFilter(value: string | undefined): KnowledgeContradictionFilter | undefined {
  if (!value || !includesTupleValue(KNOWLEDGE_CONTRADICTION_FILTERS, value)) {
    return undefined;
  }
  return value;
}

export function normalizePalaceRagSubview(value: string | undefined): PalaceRagSubview | undefined {
  if (!value || !includesTupleValue(PALACE_RAG_SUBVIEWS, value)) {
    return undefined;
  }
  return value;
}

export function normalizeQueryValue(value: string | null | undefined): string | undefined {
  if (!value) {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed ? trimmed : undefined;
}

export function isTimeoutLike(error: ApiError): boolean {
  return error.code === 'request_timeout' || error.code === 'network_error';
}

export function isNonTerminalIngestionStatus(status: string | undefined): boolean {
  return status === 'PENDING' || status === 'PROCESSING';
}

export function readIngestionFreshnessTag(input: { stale: boolean; active: boolean; attempt: number }) {
  if (input.stale) {
    return { color: 'warning' as const, label: 'stale' };
  }
  if (input.active) {
    return { color: 'processing' as const, label: `polling ${input.attempt}` };
  }
  return { color: 'success' as const, label: 'stable' };
}

export function readStatusBadge(query: QueryState): string {
  const normalizedStatus = readCanonicalStatus(query);
  if (!query.rawStatus) {
    return normalizedStatus;
  }
  return query.statusWasNormalized ? `${query.rawStatus} → ${normalizedStatus}` : query.rawStatus;
}

export function defaultStatusForView(view: KnowledgeOpsView): string {
  if (view === 'palace-rag') {
    return DEFAULT_PALACE_RAG_SUBVIEW;
  }
  return DEFAULT_STATUS;
}

export function readCanonicalStatus(query: QueryState): string {
  if (query.view === 'ingestion') {
    return query.ingestionStatus;
  }
  if (query.view === 'kg-review') {
    return query.kgStatus;
  }
  return query.palaceRagSubview;
}

export function includesTupleValue<const T extends readonly string[]>(allowed: T, value: string): value is T[number] {
  return (allowed as readonly string[]).includes(value);
}

export function formatTimestamp(value: string | undefined): string {
  if (!value) {
    return '—';
  }
  const timestamp = Date.parse(value);
  if (Number.isNaN(timestamp)) {
    return value;
  }
  return new Date(timestamp).toLocaleString();
}

export function ingestionStatusColor(status: KnowledgeIngestionStatus): string {
  switch (status) {
    case 'COMPLETED':
      return 'success';
    case 'FAILED':
      return 'error';
    case 'PROCESSING':
      return 'processing';
    default:
      return 'default';
  }
}

export function palaceBridgeStatusColor(status: PalaceBridgeEdgeStatus): string {
  switch (status) {
    case 'approved':
      return 'success';
    case 'rejected':
      return 'error';
    default:
      return 'processing';
  }
}

export function formatConfidence(value: number): string {
  return `${Math.round(value * 100)}%`;
}

export function countTraceCandidates(value: string): number | null {
  try {
    const payload = JSON.parse(value);
    return Array.isArray(payload) ? payload.length : null;
  } catch {
    return null;
  }
}

export function contradictionStatusColor(status: KnowledgeContradictionStatus): string {
  switch (status) {
    case 'resolved':
      return 'success';
    case 'escalated':
      return 'error';
    case 'reviewing':
      return 'processing';
    case 'dismissed':
      return 'default';
    default:
      return 'warning';
  }
}

export function notificationTypeColor(value: string): string {
  if (value === 'contradiction_escalated') {
    return 'red';
  }
  return 'blue';
}

export function readStringDetail(error: ApiError, key: string): string | undefined {
  const value = error.details[key];
  return typeof value === 'string' && value.trim() ? value : undefined;
}

export const fileInputStyle: CSSProperties = {
  width: '100%',
  maxWidth: 360,
};
