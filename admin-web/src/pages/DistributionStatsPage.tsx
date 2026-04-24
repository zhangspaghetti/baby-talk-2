import { useEffect, useMemo, useState, type CSSProperties } from 'react';
import {
  Alert,
  Button,
  Card,
  Empty,
  Progress,
  Space,
  Spin,
  Statistic,
  Table,
  Tag,
  Typography,
  type TableProps,
} from 'antd';
import { useSearchParams } from 'react-router-dom';
import type { AdminIdentity } from '../lib/authClient';
import { ApiError } from '../lib/authClient';
import { warmPaperAdmin } from '../app/theme';
import {
  DISTRIBUTION_STATS_CHANNELS,
  DISTRIBUTION_STATS_RANGES,
  distributionStatsClient,
  type DetailRowView,
  type DistributionStatsChannel,
  type DistributionStatsRange,
  type DistributionStatsView,
  type FunnelPointView,
  type TrendPointView,
} from '../lib/distributionStatsClient';

const DEFAULT_RANGE: DistributionStatsRange = '30d';
const DEFAULT_CHANNEL: DistributionStatsChannel = 'all';

const overviewGridStyle: CSSProperties = {
  display: 'grid',
  gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))',
  gap: 16,
  alignItems: 'start',
};

const sectionGridStyle: CSSProperties = {
  display: 'grid',
  gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))',
  gap: 16,
  alignItems: 'start',
};

type DistributionStatsPageProps = {
  accessToken: string;
  admin: AdminIdentity;
  onUnauthorized: (error: ApiError) => void;
};

type QueryState = {
  rawRange?: string;
  rawChannel?: string;
  range?: DistributionStatsRange;
  channel?: DistributionStatsChannel;
};

type DailyCountPoint = {
  label: string;
  value: number;
};

const RANGE_OPTIONS: Array<{ value: DistributionStatsRange; label: string }> = [
  { value: '7d', label: '7 天' },
  { value: '30d', label: '30 天' },
  { value: '90d', label: '90 天' },
];

const CHANNEL_OPTIONS: Array<{ value: DistributionStatsChannel; label: string }> = [
  { value: 'all', label: '全部渠道' },
  { value: 'stable', label: 'stable' },
  { value: 'beta', label: 'beta' },
];

export function DistributionStatsPage({ accessToken, admin, onUnauthorized }: DistributionStatsPageProps) {
  const [searchParams, setSearchParams] = useSearchParams();
  const query = useMemo(() => readQueryState(searchParams), [searchParams]);
  const [rangeDraft, setRangeDraft] = useState<DistributionStatsRange>(query.range ?? DEFAULT_RANGE);
  const [channelDraft, setChannelDraft] = useState<DistributionStatsChannel>(query.channel ?? DEFAULT_CHANNEL);
  const [stats, setStats] = useState<DistributionStatsView | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<ApiError | null>(null);
  const [reloadNonce, setReloadNonce] = useState(0);

  const needsCanonicalQuery = !searchParams.has('range') || !searchParams.has('channel');
  const searchParamsKey = searchParams.toString();

  useEffect(() => {
    if (!needsCanonicalQuery) {
      return;
    }

    const nextParams = new URLSearchParams(searchParams);
    if (!searchParams.has('range')) {
      nextParams.set('range', DEFAULT_RANGE);
    }
    if (!searchParams.has('channel')) {
      nextParams.set('channel', DEFAULT_CHANNEL);
    }
    setSearchParams(nextParams, { replace: true });
  }, [needsCanonicalQuery, searchParams, searchParamsKey, setSearchParams]);

  useEffect(() => {
    setRangeDraft(query.range ?? DEFAULT_RANGE);
    setChannelDraft(query.channel ?? DEFAULT_CHANNEL);
  }, [query.channel, query.range]);

  useEffect(() => {
    if (needsCanonicalQuery) {
      return;
    }

    let cancelled = false;
    setLoading(true);
    setError(null);

    void distributionStatsClient
      .getStats(accessToken, {
        range: query.rawRange,
        channel: query.rawChannel,
      })
      .then((nextStats) => {
        if (cancelled) {
          return;
        }
        setStats(nextStats);
      })
      .catch((requestError) => {
        const apiError = toApiError(requestError);
        if (cancelled) {
          return;
        }
        if (apiError.status === 401 && apiError.code !== 'admin_account_disabled') {
          onUnauthorized(normalizeStatsUnauthorizedError(apiError));
          return;
        }
        setError(apiError);
      })
      .finally(() => {
        if (!cancelled) {
          setLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [accessToken, needsCanonicalQuery, onUnauthorized, query.rawChannel, query.rawRange, reloadNonce]);

  const contextSummary = searchParams.toString() || `range=${DEFAULT_RANGE}&channel=${DEFAULT_CHANNEL}`;
  const releaseTrendPoints = useMemo(() => aggregateDailyCounts(stats?.releaseTrend ?? []), [stats?.releaseTrend]);
  const shareTrendPoints = useMemo(() => aggregateDailyCounts(stats?.shareTrend ?? []), [stats?.shareTrend]);
  const isEmptyState =
    stats != null &&
    stats.releaseOverview.totalEvents === 0 &&
    stats.shareOverview.totalEvents === 0 &&
    stats.detailRows.length === 0;

  const applyFilters = () => {
    updateQuery(setSearchParams, {
      range: rangeDraft,
      channel: channelDraft,
    });
  };

  const resetFilters = () => {
    setRangeDraft(DEFAULT_RANGE);
    setChannelDraft(DEFAULT_CHANNEL);
    updateQuery(setSearchParams, {
      range: DEFAULT_RANGE,
      channel: DEFAULT_CHANNEL,
    });
  };

  const detailColumns: TableProps<DetailRowView>['columns'] = [
    {
      title: 'surface',
      dataIndex: 'surface',
      key: 'surface',
      render: (value: string) => (
        <Tag color={value === 'release_distribution' ? warmPaperAdmin.palette.info : warmPaperAdmin.palette.accentDark}>
          {value}
        </Tag>
      ),
    },
    {
      title: 'createdAt',
      dataIndex: 'createdAt',
      key: 'createdAt',
      render: (value: string) => formatTimestamp(value),
    },
    {
      title: 'channel',
      dataIndex: 'channel',
      key: 'channel',
      render: (value: string | undefined) => value ?? '—',
    },
    {
      title: 'source',
      dataIndex: 'source',
      key: 'source',
    },
    {
      title: 'entrypoint',
      dataIndex: 'entrypoint',
      key: 'entrypoint',
    },
    {
      title: 'platform',
      dataIndex: 'platform',
      key: 'platform',
    },
    {
      title: 'result',
      dataIndex: 'result',
      key: 'result',
    },
    {
      title: 'failureReason',
      dataIndex: 'failureReason',
      key: 'failureReason',
      render: (value: string | undefined) => value ?? '—',
    },
  ];

  const handoffColumns: TableProps<DistributionStatsView['shareHandoff']['trend'][number]>['columns'] = [
    {
      title: 'day',
      dataIndex: 'eventDay',
      key: 'eventDay',
    },
    {
      title: 'platform',
      dataIndex: 'platform',
      key: 'platform',
    },
    {
      title: 'share fallback',
      dataIndex: 'shareDownloadFallbackCount',
      key: 'shareDownloadFallbackCount',
    },
    {
      title: 'release share_card',
      dataIndex: 'releaseShareCardCount',
      key: 'releaseShareCardCount',
    },
    {
      title: 'delta',
      dataIndex: 'releaseMinusShare',
      key: 'releaseMinusShare',
      render: (value: number) => (
        <Typography.Text type={value < 0 ? 'danger' : undefined}>{value}</Typography.Text>
      ),
    },
  ];

  return (
    <Space direction="vertical" size="large" style={{ width: '100%' }} data-testid="distribution-stats-page">
      <Space direction="vertical" size={4}>
        <Typography.Title level={3} style={{ marginBottom: 0 }}>
          Distribution Stats Workspace
        </Typography.Title>
        <Typography.Paragraph type="secondary" style={{ marginBottom: 0 }}>
          URL query 是当前过滤真相源；浏览器权限继续只信任 live `/api/admin/me`，报表请求保持 page-local single fetch。
        </Typography.Paragraph>
      </Space>

      <Card size="small" title="Current admin / filter context">
        <Space direction="vertical" size={10} style={{ width: '100%' }}>
          <Space wrap>
            <Tag color={warmPaperAdmin.palette.info}>user: {admin.username}</Tag>
            <Tag color={admin.permissions.includes('distribution:read') ? 'success' : 'default'}>
              distribution:read {admin.permissions.includes('distribution:read') ? 'enabled' : 'missing'}
            </Tag>
            <Tag>roles: {admin.roles.join(', ') || 'none'}</Tag>
          </Space>
          <Space wrap>
            <Tag data-testid="range-badge" color={query.range ? 'processing' : query.rawRange ? 'error' : 'default'}>
              range: {query.rawRange ?? '(missing)'}
            </Tag>
            <Tag
              data-testid="channel-badge"
              color={query.channel ? 'processing' : query.rawChannel ? 'error' : 'default'}
            >
              channel: {query.rawChannel ?? '(missing)'}
            </Tag>
            <Tag>window started: {stats ? formatTimestamp(stats.applied.windowStartedAt) : 'pending'}</Tag>
          </Space>
          <Typography.Text code data-testid="stats-context-query">
            {contextSummary}
          </Typography.Text>
        </Space>
      </Card>

      <Card size="small" title="Stats filters">
        <Space direction="vertical" size="middle" style={{ width: '100%' }}>
          <div>
            <Typography.Text type="secondary">range</Typography.Text>
            <Space wrap style={{ marginTop: 8 }}>
              {RANGE_OPTIONS.map((option) => (
                <Button
                  key={option.value}
                  data-testid={`range-option-${option.value}`}
                  type={rangeDraft === option.value ? 'primary' : 'default'}
                  onClick={() => setRangeDraft(option.value)}
                >
                  {option.label}
                </Button>
              ))}
            </Space>
          </div>

          <div>
            <Typography.Text type="secondary">channel</Typography.Text>
            <Space wrap style={{ marginTop: 8 }}>
              {CHANNEL_OPTIONS.map((option) => (
                <Button
                  key={option.value}
                  data-testid={`channel-option-${option.value}`}
                  type={channelDraft === option.value ? 'primary' : 'default'}
                  onClick={() => setChannelDraft(option.value)}
                >
                  {option.label}
                </Button>
              ))}
            </Space>
          </div>

          <Space wrap>
            <Button data-testid="apply-filters" type="primary" onClick={applyFilters}>
              应用过滤
            </Button>
            <Button data-testid="reset-filters" onClick={resetFilters}>
              重置为默认
            </Button>
            <Button data-testid="reload-stats" onClick={() => setReloadNonce((value) => value + 1)}>
              重新读取 stats
            </Button>
          </Space>
        </Space>
      </Card>

      <Alert
        showIcon
        type="info"
        data-testid="release-only-channel-note"
        message="Channel scope note"
        description={stats?.channelScopeNote ?? 'channel 只作用于 release / share_card handoff；share 原始漏斗不带 channel。'}
      />

      {loading && !stats ? (
        <div data-testid="distribution-loading-state" style={{ padding: '24px 0' }}>
          <Spin tip="正在读取 distribution stats…" />
        </div>
      ) : null}

      {loading && stats ? (
        <Alert
          showIcon
          type="info"
          message="正在刷新报表"
          description={`已保留最近一次成功快照：range=${stats.applied.range}, channel=${stats.applied.channel}`}
        />
      ) : null}

      {error ? (
        <div data-testid="distribution-error-state">
          <Alert
            showIcon
            type={error.status === 400 || error.status === 403 || error.status === 401 ? 'warning' : 'error'}
            message="distribution stats 读取失败"
            description={
              <Space direction="vertical" size={8}>
                <span>{error.message}</span>
                <Typography.Text type="secondary">错误码：{error.code}</Typography.Text>
                {stats ? (
                  <Typography.Text type="secondary">
                    仍保留最近一次成功快照：range={stats.applied.range}, channel={stats.applied.channel}
                  </Typography.Text>
                ) : null}
              </Space>
            }
          />
        </div>
      ) : null}

      {isEmptyState ? (
        <div data-testid="distribution-empty-state">
          <Empty description="当前时间窗内还没有 release/share stats 事件。" />
        </div>
      ) : null}

      {stats ? (
        <>
          <div style={overviewGridStyle}>
            <OverviewCard title="Release overview" overview={stats.releaseOverview} accent="info" />
            <OverviewCard title="Share overview" overview={stats.shareOverview} accent="accent" />
          </div>

          <div style={sectionGridStyle}>
            <Card title="Release trend" data-testid="release-trend-card">
              {releaseTrendPoints.length === 0 ? (
                <Empty description="当前过滤条件下没有 release 趋势数据。" />
              ) : (
                <Space direction="vertical" size="middle" style={{ width: '100%' }}>
                  <MiniBarChart dataTestId="release-trend-chart" ariaLabel="release trend chart" points={releaseTrendPoints} />
                  <Typography.Text type="secondary">
                    total points: {stats.releaseTrend.length} · last seen: {formatTimestamp(stats.releaseOverview.lastSeenAt)}
                  </Typography.Text>
                </Space>
              )}
            </Card>

            <Card title="Share funnel" data-testid="share-funnel-card">
              {stats.shareFunnel.length === 0 ? (
                <Empty description="当前过滤条件下没有 share funnel 数据。" />
              ) : (
                <Space direction="vertical" size="middle" style={{ width: '100%' }}>
                  {stats.shareFunnel.map((item) => (
                    <FunnelRow key={item.entrypoint} item={item} />
                  ))}
                  <Typography.Text type="secondary">
                    share trend points: {shareTrendPoints.length} · last seen: {formatTimestamp(stats.shareOverview.lastSeenAt)}
                  </Typography.Text>
                </Space>
              )}
            </Card>
          </div>

          <Card title="Share → release handoff" data-testid="share-handoff-card">
            <Space direction="vertical" size="middle" style={{ width: '100%' }}>
              <div style={overviewGridStyle}>
                <Card size="small">
                  <Statistic title="share download fallback" value={stats.shareHandoff.totalShareDownloadFallbackEvents} />
                  <Typography.Text type="secondary">
                    last seen: {formatTimestamp(stats.shareHandoff.shareLastSeenAt)}
                  </Typography.Text>
                </Card>
                <Card size="small">
                  <Statistic title="release share_card" value={stats.shareHandoff.totalReleaseShareCardEvents} />
                  <Typography.Text type="secondary">
                    last seen: {formatTimestamp(stats.shareHandoff.releaseLastSeenAt)}
                  </Typography.Text>
                </Card>
                <Card size="small">
                  <Statistic title="release minus share" value={stats.shareHandoff.releaseMinusShare} />
                  <Typography.Text type="secondary">
                    combined last seen: {formatTimestamp(stats.shareHandoff.lastSeenAt)}
                  </Typography.Text>
                </Card>
              </div>

              <Table
                size="small"
                rowKey={(row) => `${row.eventDay}-${row.platform}`}
                pagination={false}
                columns={handoffColumns}
                dataSource={stats.shareHandoff.trend}
                locale={{ emptyText: '当前过滤条件下没有 handoff trend。' }}
              />
            </Space>
          </Card>

          <Card title={`Normalized detail rows (${stats.detailRows.length}/${stats.applied.detailLimit})`} data-testid="detail-table-card">
            <Table
              size="small"
              rowKey={(row) => `${row.surface}-${row.createdAt}-${row.source}-${row.entrypoint}-${row.platform}-${row.result}`}
              columns={detailColumns}
              dataSource={stats.detailRows}
              pagination={{ pageSize: 10, showSizeChanger: false }}
              scroll={{ x: 960 }}
              locale={{ emptyText: '当前过滤条件下没有 detail rows。' }}
            />
          </Card>
        </>
      ) : null}
    </Space>
  );
}

function OverviewCard({
  title,
  overview,
  accent,
}: {
  title: string;
  overview: DistributionStatsView['releaseOverview'];
  accent: 'info' | 'accent';
}) {
  return (
    <Card title={title}>
      <div style={overviewGridStyle}>
        <Statistic title="total" value={overview.totalEvents} />
        <Statistic title="success" value={overview.successfulEvents} valueStyle={{ color: '#16a34a' }} />
        <Statistic title="failure" value={overview.failureEvents} valueStyle={{ color: '#dc2626' }} />
        <Card
          size="small"
          style={{
            borderColor:
              accent === 'info' ? warmPaperAdmin.palette.infoSoft : warmPaperAdmin.palette.accentLight,
          }}
        >
          <Typography.Text type="secondary">last seen</Typography.Text>
          <Typography.Paragraph style={{ marginBottom: 0 }}>{formatTimestamp(overview.lastSeenAt)}</Typography.Paragraph>
        </Card>
      </div>
    </Card>
  );
}

function FunnelRow({ item }: { item: FunnelPointView }) {
  return (
    <Card size="small" key={item.entrypoint}>
      <Space direction="vertical" size={8} style={{ width: '100%' }}>
        <Space wrap>
          <Typography.Text strong>{item.entrypoint}</Typography.Text>
          <Tag>total: {item.totalEvents}</Tag>
          <Tag color="success">success: {item.successfulEvents}</Tag>
          <Tag color={item.failureEvents > 0 ? 'error' : 'default'}>failure: {item.failureEvents}</Tag>
          <Tag>last seen: {formatTimestamp(item.lastSeenAt)}</Tag>
        </Space>
        <Progress
          percent={Math.min(Math.max(item.successRatePct, 0), 100)}
          strokeColor={warmPaperAdmin.palette.accent}
        />
      </Space>
    </Card>
  );
}

function MiniBarChart({
  points,
  ariaLabel,
  dataTestId,
}: {
  points: DailyCountPoint[];
  ariaLabel: string;
  dataTestId: string;
}) {
  const maxValue = Math.max(...points.map((point) => point.value), 1);
  const chartHeight = 120;
  const columnWidth = 56;
  const width = Math.max(points.length * columnWidth, 160);

  return (
    <div data-testid={dataTestId}>
      <svg aria-label={ariaLabel} role="img" viewBox={`0 0 ${width} ${chartHeight}`} style={{ width: '100%', height: 180 }}>
        {points.map((point, index) => {
          const barHeight = Math.max((point.value / maxValue) * 72, point.value > 0 ? 6 : 0);
          const x = index * columnWidth + 10;
          const y = 84 - barHeight;
          return (
            <g key={`${point.label}-${point.value}`}>
              <title>{`${point.label}: ${point.value}`}</title>
              <rect
                x={x}
                y={y}
                width={32}
                height={barHeight}
                rx={8}
                fill={warmPaperAdmin.palette.accentDark}
                opacity="0.88"
              />
              <text x={x + 16} y={98} textAnchor="middle" fontSize="11" fill={warmPaperAdmin.palette.textSecondary}>
                {point.label.slice(5)}
              </text>
              <text x={x + 16} y={y - 6} textAnchor="middle" fontSize="11" fill={warmPaperAdmin.palette.textPrimary}>
                {point.value}
              </text>
            </g>
          );
        })}
      </svg>
    </div>
  );
}

function aggregateDailyCounts(points: TrendPointView[]): DailyCountPoint[] {
  const counts = new Map<string, number>();
  for (const point of points) {
    counts.set(point.eventDay, (counts.get(point.eventDay) ?? 0) + point.eventCount);
  }
  return Array.from(counts.entries())
    .sort((left, right) => left[0].localeCompare(right[0]))
    .map(([label, value]) => ({ label, value }));
}

function readQueryState(searchParams: URLSearchParams): QueryState {
  const rawRange = readRawQueryValue(searchParams.get('range'));
  const rawChannel = readRawQueryValue(searchParams.get('channel'));

  return {
    rawRange,
    rawChannel,
    range: normalizeRange(rawRange),
    channel: normalizeChannel(rawChannel),
  };
}

function readRawQueryValue(value: string | null): string | undefined {
  return value === null ? undefined : value;
}

function normalizeRange(value: string | undefined): DistributionStatsRange | undefined {
  if (!value) {
    return undefined;
  }
  return (DISTRIBUTION_STATS_RANGES as readonly string[]).includes(value)
    ? (value as DistributionStatsRange)
    : undefined;
}

function normalizeChannel(value: string | undefined): DistributionStatsChannel | undefined {
  if (!value) {
    return undefined;
  }
  return (DISTRIBUTION_STATS_CHANNELS as readonly string[]).includes(value)
    ? (value as DistributionStatsChannel)
    : undefined;
}

function updateQuery(
  setSearchParams: ReturnType<typeof useSearchParams>[1],
  query: { range: string; channel: string },
) {
  const params = new URLSearchParams();
  params.set('range', query.range);
  params.set('channel', query.channel);
  setSearchParams(params, { replace: false });
}

function formatTimestamp(value: string | undefined): string {
  if (!value) {
    return '—';
  }
  const timestamp = Date.parse(value);
  if (Number.isNaN(timestamp)) {
    return value;
  }
  return new Date(timestamp).toLocaleString();
}

function toApiError(error: unknown): ApiError {
  if (error instanceof ApiError) {
    return error;
  }
  if (error instanceof Error) {
    return new ApiError(0, 'unexpected_error', error.message);
  }
  return new ApiError(0, 'unexpected_error', '发生未预期错误。');
}

function normalizeStatsUnauthorizedError(error: ApiError): ApiError {
  if (
    error.code === 'request_failed' ||
    error.code === 'invalid_admin_access_token' ||
    error.code === 'unexpected_error'
  ) {
    return new ApiError(401, 'admin_session_invalid', '管理员会话已失效，请重新登录。');
  }
  return error;
}

export default DistributionStatsPage;
