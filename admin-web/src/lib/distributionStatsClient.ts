import { ApiError, requestJson } from './authClient';

export const DISTRIBUTION_STATS_RANGES = ['7d', '30d', '90d'] as const;
export const DISTRIBUTION_STATS_CHANNELS = ['all', 'stable', 'beta'] as const;

export type DistributionStatsRange = (typeof DISTRIBUTION_STATS_RANGES)[number];
export type DistributionStatsChannel = (typeof DISTRIBUTION_STATS_CHANNELS)[number];

export interface DistributionStatsQuery {
  range?: string;
  channel?: string;
}

export interface DistributionStatsView {
  applied: AppliedFiltersView;
  channelScopeNote: string;
  releaseOverview: SectionOverviewView;
  releaseTrend: TrendPointView[];
  shareOverview: SectionOverviewView;
  shareTrend: TrendPointView[];
  shareFunnel: FunnelPointView[];
  shareHandoff: ShareHandoffView;
  detailRows: DetailRowView[];
}

export interface AppliedFiltersView {
  range: DistributionStatsRange;
  channel: DistributionStatsChannel;
  detailLimit: number;
  windowStartedAt: string;
}

export interface SectionOverviewView {
  totalEvents: number;
  successfulEvents: number;
  failureEvents: number;
  lastSeenAt?: string;
}

export interface TrendPointView {
  eventDay: string;
  entrypoint: string;
  result: string;
  eventCount: number;
}

export interface FunnelPointView {
  entrypoint: string;
  totalEvents: number;
  successfulEvents: number;
  failureEvents: number;
  successRatePct: number;
  lastSeenAt?: string;
}

export interface ShareHandoffView {
  totalShareDownloadFallbackEvents: number;
  totalReleaseShareCardEvents: number;
  releaseMinusShare: number;
  lastSeenAt?: string;
  shareLastSeenAt?: string;
  releaseLastSeenAt?: string;
  trend: HandoffTrendPointView[];
}

export interface HandoffTrendPointView {
  eventDay: string;
  platform: string;
  shareDownloadFallbackCount: number;
  releaseShareCardCount: number;
  releaseMinusShare: number;
}

export interface DetailRowView {
  surface: string;
  createdAt: string;
  channel?: string;
  source: string;
  entrypoint: string;
  platform: string;
  result: string;
  failureReason?: string;
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

function readRequiredNumber(record: Record<string, unknown>, key: string, message: string): number {
  const value = record[key];
  if (typeof value !== 'number' || Number.isNaN(value)) {
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

function parseSectionOverview(payload: unknown, sectionName: string): SectionOverviewView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', `${sectionName} 不是对象。`);
  }

  return {
    totalEvents: readRequiredNumber(payload, 'totalEvents', `${sectionName} 缺少 totalEvents。`),
    successfulEvents: readRequiredNumber(payload, 'successfulEvents', `${sectionName} 缺少 successfulEvents。`),
    failureEvents: readRequiredNumber(payload, 'failureEvents', `${sectionName} 缺少 failureEvents。`),
    lastSeenAt: readOptionalString(payload, 'lastSeenAt'),
  };
}

function parseTrendPoint(payload: unknown, sectionName: string): TrendPointView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', `${sectionName} item 不是对象。`);
  }

  return {
    eventDay: readRequiredString(payload, 'eventDay', `${sectionName} item 缺少 eventDay。`),
    entrypoint: readRequiredString(payload, 'entrypoint', `${sectionName} item 缺少 entrypoint。`),
    result: readRequiredString(payload, 'result', `${sectionName} item 缺少 result。`),
    eventCount: readRequiredNumber(payload, 'eventCount', `${sectionName} item 缺少 eventCount。`),
  };
}

function parseFunnelPoint(payload: unknown): FunnelPointView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'shareFunnel item 不是对象。');
  }

  return {
    entrypoint: readRequiredString(payload, 'entrypoint', 'shareFunnel item 缺少 entrypoint。'),
    totalEvents: readRequiredNumber(payload, 'totalEvents', 'shareFunnel item 缺少 totalEvents。'),
    successfulEvents: readRequiredNumber(payload, 'successfulEvents', 'shareFunnel item 缺少 successfulEvents。'),
    failureEvents: readRequiredNumber(payload, 'failureEvents', 'shareFunnel item 缺少 failureEvents。'),
    successRatePct: readRequiredNumber(payload, 'successRatePct', 'shareFunnel item 缺少 successRatePct。'),
    lastSeenAt: readOptionalString(payload, 'lastSeenAt'),
  };
}

function parseHandoffTrendPoint(payload: unknown): HandoffTrendPointView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'shareHandoff trend item 不是对象。');
  }

  return {
    eventDay: readRequiredString(payload, 'eventDay', 'shareHandoff trend item 缺少 eventDay。'),
    platform: readRequiredString(payload, 'platform', 'shareHandoff trend item 缺少 platform。'),
    shareDownloadFallbackCount: readRequiredNumber(
      payload,
      'shareDownloadFallbackCount',
      'shareHandoff trend item 缺少 shareDownloadFallbackCount。',
    ),
    releaseShareCardCount: readRequiredNumber(
      payload,
      'releaseShareCardCount',
      'shareHandoff trend item 缺少 releaseShareCardCount。',
    ),
    releaseMinusShare: readRequiredNumber(
      payload,
      'releaseMinusShare',
      'shareHandoff trend item 缺少 releaseMinusShare。',
    ),
  };
}

function parseShareHandoff(payload: unknown): ShareHandoffView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'shareHandoff 不是对象。');
  }

  const trendPayload = payload.trend;
  if (!Array.isArray(trendPayload)) {
    throw new ApiError(502, 'invalid_response_payload', 'shareHandoff 缺少 trend。');
  }

  return {
    totalShareDownloadFallbackEvents: readRequiredNumber(
      payload,
      'totalShareDownloadFallbackEvents',
      'shareHandoff 缺少 totalShareDownloadFallbackEvents。',
    ),
    totalReleaseShareCardEvents: readRequiredNumber(
      payload,
      'totalReleaseShareCardEvents',
      'shareHandoff 缺少 totalReleaseShareCardEvents。',
    ),
    releaseMinusShare: readRequiredNumber(payload, 'releaseMinusShare', 'shareHandoff 缺少 releaseMinusShare。'),
    lastSeenAt: readOptionalString(payload, 'lastSeenAt'),
    shareLastSeenAt: readOptionalString(payload, 'shareLastSeenAt'),
    releaseLastSeenAt: readOptionalString(payload, 'releaseLastSeenAt'),
    trend: trendPayload.map((item) => parseHandoffTrendPoint(item)),
  };
}

function parseDetailRow(payload: unknown): DetailRowView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'detailRows item 不是对象。');
  }

  return {
    surface: readRequiredString(payload, 'surface', 'detailRows item 缺少 surface。'),
    createdAt: readRequiredString(payload, 'createdAt', 'detailRows item 缺少 createdAt。'),
    channel: readOptionalString(payload, 'channel'),
    source: readRequiredString(payload, 'source', 'detailRows item 缺少 source。'),
    entrypoint: readRequiredString(payload, 'entrypoint', 'detailRows item 缺少 entrypoint。'),
    platform: readRequiredString(payload, 'platform', 'detailRows item 缺少 platform。'),
    result: readRequiredString(payload, 'result', 'detailRows item 缺少 result。'),
    failureReason: readOptionalString(payload, 'failureReason'),
  };
}

function parseDistributionStats(payload: unknown): DistributionStatsView {
  if (!isRecord(payload)) {
    throw new ApiError(502, 'invalid_response_payload', 'distribution stats 响应不是对象。');
  }

  const appliedPayload = payload.applied;
  if (!isRecord(appliedPayload)) {
    throw new ApiError(502, 'invalid_response_payload', 'distribution stats 缺少 applied。');
  }

  const releaseTrendPayload = payload.releaseTrend;
  const shareTrendPayload = payload.shareTrend;
  const shareFunnelPayload = payload.shareFunnel;
  const detailRowsPayload = payload.detailRows;

  if (!Array.isArray(releaseTrendPayload)) {
    throw new ApiError(502, 'invalid_response_payload', 'distribution stats 缺少 releaseTrend。');
  }
  if (!Array.isArray(shareTrendPayload)) {
    throw new ApiError(502, 'invalid_response_payload', 'distribution stats 缺少 shareTrend。');
  }
  if (!Array.isArray(shareFunnelPayload)) {
    throw new ApiError(502, 'invalid_response_payload', 'distribution stats 缺少 shareFunnel。');
  }
  if (!Array.isArray(detailRowsPayload)) {
    throw new ApiError(502, 'invalid_response_payload', 'distribution stats 缺少 detailRows。');
  }

  return {
    applied: {
      range: readEnumValue(appliedPayload, 'range', DISTRIBUTION_STATS_RANGES, 'applied 缺少合法 range。'),
      channel: readEnumValue(
        appliedPayload,
        'channel',
        DISTRIBUTION_STATS_CHANNELS,
        'applied 缺少合法 channel。',
      ),
      detailLimit: readRequiredNumber(appliedPayload, 'detailLimit', 'applied 缺少 detailLimit。'),
      windowStartedAt: readRequiredString(appliedPayload, 'windowStartedAt', 'applied 缺少 windowStartedAt。'),
    },
    channelScopeNote: readRequiredString(payload, 'channelScopeNote', 'distribution stats 缺少 channelScopeNote。'),
    releaseOverview: parseSectionOverview(payload.releaseOverview, 'releaseOverview'),
    releaseTrend: releaseTrendPayload.map((item) => parseTrendPoint(item, 'releaseTrend')),
    shareOverview: parseSectionOverview(payload.shareOverview, 'shareOverview'),
    shareTrend: shareTrendPayload.map((item) => parseTrendPoint(item, 'shareTrend')),
    shareFunnel: shareFunnelPayload.map((item) => parseFunnelPoint(item)),
    shareHandoff: parseShareHandoff(payload.shareHandoff),
    detailRows: detailRowsPayload.map((item) => parseDetailRow(item)),
  };
}

function buildQueryString(query: DistributionStatsQuery): string {
  const params = new URLSearchParams();
  if (query.range !== undefined) {
    params.set('range', query.range);
  }
  if (query.channel !== undefined) {
    params.set('channel', query.channel);
  }
  const rendered = params.toString();
  return rendered ? `?${rendered}` : '';
}

export const distributionStatsClient = {
  async getStats(accessToken: string, query: DistributionStatsQuery = {}) {
    const payload = await requestJson(`/api/admin/distribution/stats${buildQueryString(query)}`, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });
    return parseDistributionStats(payload);
  },
};
