import { useEffect, useMemo, useState, type CSSProperties } from 'react';
import {
  Alert,
  Button,
  Card,
  Descriptions,
  Empty,
  Input,
  List,
  Space,
  Spin,
  Statistic,
  Tag,
  Timeline,
  Typography,
} from 'antd';
import { useSearchParams } from 'react-router-dom';
import { warmPaperAdmin } from '../app/theme';
import { useAuth } from '../auth/auth-provider';
import { ApiError } from '../lib/authClient';
import {
  MENTOR_AUDIT_FLAGS,
  mentorAuditClient,
  type MentorAuditDetail,
  type MentorAuditFlag,
  type MentorAuditQueueItem,
} from '../lib/mentorAuditClient';

const queueLimit = 50;

const workspaceGridStyle: CSSProperties = {
  display: 'grid',
  gridTemplateColumns: 'minmax(0, 1.3fr) minmax(320px, 0.9fr)',
  gap: 16,
  alignItems: 'start',
};

type QueryState = {
  installationId?: string;
  rawFlag?: string;
  flag?: MentorAuditFlag;
  selected?: string;
};

export function MentorAuditPage() {
  const { session } = useAuth();
  if (!session) {
    throw new Error('MentorAuditPage requires an active admin session.');
  }

  const admin = session.admin;
  const [searchParams, setSearchParams] = useSearchParams();
  const query = useMemo(() => readQueryState(searchParams), [searchParams]);
  const [installationDraft, setInstallationDraft] = useState(query.installationId ?? '');
  const [flagDraft, setFlagDraft] = useState(query.rawFlag ?? '');
  const [queueItems, setQueueItems] = useState<MentorAuditQueueItem[]>([]);
  const [queueLoading, setQueueLoading] = useState(false);
  const [queueError, setQueueError] = useState<ApiError | null>(null);
  const [queueReloadNonce, setQueueReloadNonce] = useState(0);
  const [detail, setDetail] = useState<MentorAuditDetail | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [detailError, setDetailError] = useState<ApiError | null>(null);
  const [detailReloadNonce, setDetailReloadNonce] = useState(0);

  useEffect(() => {
    setInstallationDraft(query.installationId ?? '');
    setFlagDraft(query.rawFlag ?? '');
  }, [query.installationId, query.rawFlag]);

  useEffect(() => {
    let cancelled = false;
    setQueueLoading(true);
    setQueueError(null);

    void mentorAuditClient
      .listAudits({
        installationId: query.installationId,
        flag: query.flag,
        limit: queueLimit,
      })
      .then((nextItems) => {
        if (cancelled) {
          return;
        }
        setQueueItems(nextItems);
      })
      .catch((error) => {
        const apiError = toApiError(error);
        if (cancelled) {
          return;
        }
        setQueueItems([]);
        setQueueError(apiError);
      })
      .finally(() => {
        if (!cancelled) {
          setQueueLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [query.flag, query.installationId, queueReloadNonce]);

  useEffect(() => {
    if (!query.selected) {
      setDetail(null);
      setDetailError(null);
      setDetailLoading(false);
      return;
    }

    let cancelled = false;
    setDetailLoading(true);
    setDetailError(null);

    void mentorAuditClient
      .getAudit(query.selected)
      .then((nextDetail) => {
        if (cancelled) {
          return;
        }
        setDetail(nextDetail);
      })
      .catch((error) => {
        const apiError = toApiError(error);
        if (cancelled) {
          return;
        }
        setDetail(null);
        setDetailError(apiError);
      })
      .finally(() => {
        if (!cancelled) {
          setDetailLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [detailReloadNonce, query.selected]);

  const contextSummary = searchParams.toString() || '(empty)';
  const hasNormalizedFlag = Boolean(query.rawFlag && !query.flag);

  const applyFilters = () => {
    updateQuery(setSearchParams, {
      installationId: normalizeQueryValue(installationDraft),
      rawFlag: normalizeQueryValue(flagDraft),
      selected: undefined,
    });
  };

  const clearFilters = () => {
    setInstallationDraft('');
    setFlagDraft('');
    updateQuery(setSearchParams, {
      installationId: undefined,
      rawFlag: undefined,
      selected: undefined,
    });
  };

  const openDetail = (correlationId: string) => {
    updateQuery(setSearchParams, {
      ...query,
      selected: correlationId,
    });
  };

  const closeDetail = () => {
    updateQuery(setSearchParams, {
      ...query,
      selected: undefined,
    });
  };

  return (
    <Space direction="vertical" size="large" style={{ width: '100%' }} data-testid="mentor-audit-page">
      <Card size="small" title="Current admin / URL context">
        <Space direction="vertical" size={10} style={{ width: '100%' }}>
          <Space wrap>
            <Tag color={warmPaperAdmin.palette.info}>user: {admin.username}</Tag>
            <Tag color={admin.permissions.includes('mentor:audit') ? 'success' : 'default'}>
              mentor:audit {admin.permissions.includes('mentor:audit') ? 'enabled' : 'missing'}
            </Tag>
            <Tag>roles: {admin.roles.join(', ') || 'none'}</Tag>
            <Tag>access expires: {formatTimestamp(session.accessTokenExpiresAt)}</Tag>
          </Space>
          <Space wrap>
            <Tag color={query.installationId ? 'processing' : 'default'}>
              installationId: {query.installationId ?? 'all'}
            </Tag>
            <Tag color={query.flag ? 'processing' : query.rawFlag ? 'warning' : 'default'}>
              flag: {query.rawFlag ? (query.flag ? query.rawFlag : `${query.rawFlag} → all flagged`) : 'all flagged'}
            </Tag>
            <Tag color={query.selected ? 'warning' : 'default'}>selected: {query.selected ?? 'none'}</Tag>
          </Space>
          <Typography.Text code data-testid="queue-context-query">
            {contextSummary}
          </Typography.Text>
        </Space>
      </Card>

      {hasNormalizedFlag ? (
        <Alert
          showIcon
          type="warning"
          data-testid="queue-query-normalized-state"
          message="未知 flag 已归一化为安全默认值"
          description={`原始 query flag=${query.rawFlag} 仍保留在 URL 里供排查，但请求会按 all flagged 读取 queue。`}
        />
      ) : null}

      <Card size="small" title="Queue filters">
        <Space wrap align="end" size="middle">
          <div style={{ minWidth: 220 }}>
            <Typography.Text type="secondary">installationId</Typography.Text>
            <Input
              aria-label="installationId 过滤"
              data-testid="installation-filter"
              placeholder="例如 install-alpha"
              value={installationDraft}
              onChange={(event) => setInstallationDraft(event.target.value)}
              onPressEnter={applyFilters}
            />
          </div>
          <div style={{ minWidth: 260 }}>
            <Typography.Text type="secondary">flag</Typography.Text>
            <Input
              aria-label="flag 过滤"
              data-testid="flag-filter"
              placeholder="例如 blocked_fallback"
              value={flagDraft}
              onChange={(event) => setFlagDraft(event.target.value)}
              onPressEnter={applyFilters}
            />
          </div>
          <Button type="primary" data-testid="apply-filters" onClick={applyFilters}>
            应用过滤
          </Button>
          <Button data-testid="clear-filters" onClick={clearFilters}>
            清除过滤
          </Button>
          <Button data-testid="reload-queue" onClick={() => setQueueReloadNonce((value) => value + 1)}>
            重新读取 queue
          </Button>
        </Space>
        <Typography.Paragraph type="secondary" style={{ marginTop: 12, marginBottom: 0 }}>
          Allowed flags: {MENTOR_AUDIT_FLAGS.join(', ')}
        </Typography.Paragraph>
      </Card>

      <div style={workspaceGridStyle}>
        <Card title={`Flagged incidents (${queueItems.length})`} data-testid="mentor-audit-queue">
          {queueLoading ? (
            <div style={{ padding: '32px 0' }}>
              <Spin tip="正在读取 mentor audit queue…" />
            </div>
          ) : null}

          {!queueLoading && queueError ? (
            <div data-testid="queue-error-state">
              <Alert
                showIcon
                type="error"
                message="mentor audit queue 读取失败"
                description={
                  <Space direction="vertical" size={8}>
                    <span>{queueError.message}</span>
                    <Typography.Text type="secondary">错误码：{queueError.code}</Typography.Text>
                    <Button onClick={() => setQueueReloadNonce((value) => value + 1)}>重试 queue</Button>
                  </Space>
                }
              />
            </div>
          ) : null}

          {!queueLoading && !queueError && queueItems.length === 0 ? (
            <div data-testid="audit-empty-state">
              <Empty description="当前过滤条件下没有 flagged incidents。" />
            </div>
          ) : null}

          {!queueLoading && !queueError && queueItems.length > 0 ? (
            <List
              dataSource={queueItems}
              renderItem={(item) => {
                const selected = item.correlationId === query.selected;
                return (
                  <List.Item key={item.correlationId} data-testid={`queue-item-${item.correlationId}`}>
                    <Card
                      size="small"
                      style={{ width: '100%', borderColor: selected ? warmPaperAdmin.palette.accentDark : undefined }}
                      title={
                        <Space wrap>
                          <Typography.Text code>{item.correlationId}</Typography.Text>
                          <Tag color={flagColor(item.flagCode)}>{item.flagCode}</Tag>
                          {item.historicalRateLimited ? <Tag color="gold">historical rate-limited</Tag> : null}
                          {item.retryable ? <Tag color="blue">retryable</Tag> : null}
                        </Space>
                      }
                      extra={
                        <Button
                          type={selected ? 'default' : 'primary'}
                          data-testid={`open-audit-${item.correlationId}`}
                          onClick={() => openDetail(item.correlationId)}
                        >
                          {selected ? '已打开' : '查看详情'}
                        </Button>
                      }
                    >
                      <Descriptions column={1} size="small">
                        <Descriptions.Item label="installationId">{item.installationId}</Descriptions.Item>
                        <Descriptions.Item label="latest phase">{item.latestPhase}</Descriptions.Item>
                        <Descriptions.Item label="failure code">{item.failureCode ?? '—'}</Descriptions.Item>
                        <Descriptions.Item label="occurred at">{formatTimestamp(item.occurredAt)}</Descriptions.Item>
                      </Descriptions>
                    </Card>
                  </List.Item>
                );
              }}
            />
          ) : null}
        </Card>

        <AuditDetailPane
          detail={detail}
          detailError={detailError}
          detailLoading={detailLoading}
          selectedCorrelationId={query.selected}
          onClose={closeDetail}
          onRetry={() => setDetailReloadNonce((value) => value + 1)}
        />
      </div>
    </Space>
  );
}

function AuditDetailPane({
  detail,
  detailError,
  detailLoading,
  selectedCorrelationId,
  onClose,
  onRetry,
}: {
  detail: MentorAuditDetail | null;
  detailError: ApiError | null;
  detailLoading: boolean;
  selectedCorrelationId?: string;
  onClose: () => void;
  onRetry: () => void;
}) {
  return (
    <Card
      title={selectedCorrelationId ? `Incident detail · ${selectedCorrelationId}` : 'Incident detail'}
      data-testid="mentor-audit-detail"
      extra={
        <Space>
          {selectedCorrelationId ? <Button onClick={onRetry}>重试 detail</Button> : null}
          {selectedCorrelationId ? (
            <Button data-testid="close-detail" onClick={onClose}>
              关闭详情
            </Button>
          ) : null}
        </Space>
      }
    >
      {!selectedCorrelationId ? (
        <div data-testid="detail-placeholder">
          <Empty description="选择一条 flagged incident 后，这里会显示 detail。" />
        </div>
      ) : null}

      {selectedCorrelationId && detailLoading ? (
        <div style={{ padding: '24px 0' }}>
          <Spin tip="正在读取 incident detail…" />
        </div>
      ) : null}

      {selectedCorrelationId && !detailLoading && detailError ? (
        <div data-testid="detail-error-state">
          <Alert
            showIcon
            type={detailError.status === 404 ? 'warning' : 'error'}
            message={detailError.status === 404 ? 'incident detail 不存在' : 'incident detail 读取失败'}
            description={
              <Space direction="vertical" size={8}>
                <span>{detailError.message}</span>
                <Typography.Text type="secondary">错误码：{detailError.code}</Typography.Text>
              </Space>
            }
          />
        </div>
      ) : null}

      {selectedCorrelationId && !detailLoading && !detailError && detail ? (
        <Space direction="vertical" size="middle" style={{ width: '100%' }}>
          <Alert
            showIcon
            type="info"
            data-testid="incident-evidence-note"
            message="Incident evidence only"
            description="本页是 incident-first 审计面：展示 redacted request / delivered response evidence / audit timeline，不是完整 transcript。"
          />

          <Descriptions column={1} size="small" bordered>
            <Descriptions.Item label="scope">{detail.scope}</Descriptions.Item>
            <Descriptions.Item label="installationId">{detail.installationId}</Descriptions.Item>
            <Descriptions.Item label="flagCode">
              <Tag color={flagColor(detail.flagCode)}>{detail.flagCode}</Tag>
            </Descriptions.Item>
            <Descriptions.Item label="latestPhase">{detail.latestPhase}</Descriptions.Item>
            <Descriptions.Item label="failureCode">{detail.failureCode ?? '—'}</Descriptions.Item>
            <Descriptions.Item label="deliveryState">{detail.deliveryState}</Descriptions.Item>
            <Descriptions.Item label="retryable">{detail.retryable ? 'true' : 'false'}</Descriptions.Item>
            <Descriptions.Item label="historicalRateLimited">
              {detail.historicalRateLimited ? 'true' : 'false'}
            </Descriptions.Item>
            <Descriptions.Item label="occurredAt">{formatTimestamp(detail.occurredAt)}</Descriptions.Item>
          </Descriptions>

          <Card size="small" title="Request evidence">
            <Typography.Paragraph style={{ whiteSpace: 'pre-wrap', marginBottom: 0 }} data-testid="request-summary">
              {detail.requestEvidence.summary ?? '无 redacted request summary。'}
            </Typography.Paragraph>
          </Card>

          <Card size="small" title="Delivered response evidence">
            {detail.deliveredResponse ? (
              <Space direction="vertical" size={8} style={{ width: '100%' }}>
                <Space wrap>
                  <Tag color={detail.deliveredResponse.blockedFallback ? 'gold' : 'green'}>
                    {detail.deliveredResponse.phase}
                  </Tag>
                  <Tag>{detail.deliveredResponse.result}</Tag>
                  <Tag>{detail.deliveredResponse.providerMode}</Tag>
                  {detail.deliveredResponse.retryable ? <Tag color="blue">retryable</Tag> : null}
                </Space>
                <Typography.Paragraph
                  style={{ whiteSpace: 'pre-wrap', marginBottom: 0 }}
                  data-testid="delivered-response-text"
                >
                  {detail.deliveredResponse.responseText}
                </Typography.Paragraph>
                <Typography.Text type="secondary">
                  response summary: {detail.deliveredResponse.responseSummary ?? '—'}
                </Typography.Text>
              </Space>
            ) : (
              <div data-testid="missing-delivered-response-state">
                <Empty description="当前 incident 没有 delivered response evidence。" />
              </div>
            )}
          </Card>

          <Card size="small" title="Current live rate-limit" data-testid="live-rate-limit-card">
            <Space size="large" wrap>
              <Statistic title="Current count" value={detail.liveRateLimit.currentCount} />
              <Statistic title="Limit" value={detail.liveRateLimit.limit} />
              <Statistic title="Remaining" value={detail.liveRateLimit.remaining} />
              <Statistic title="Window (seconds)" value={detail.liveRateLimit.windowSeconds} />
              <Tag color={detail.liveRateLimit.limited ? 'red' : 'green'}>
                {detail.liveRateLimit.limited ? 'currently limited' : 'within limit'}
              </Tag>
            </Space>
          </Card>

          <Card size="small" title={`Audit timeline (${detail.timeline.length})`}>
            <Timeline
              items={detail.timeline.map((item) => ({
                color: item.rateLimited ? 'red' : item.phase === 'blocked_fallback' ? 'orange' : 'blue',
                children: (
                  <Space direction="vertical" size={2}>
                    <Typography.Text strong>
                      {item.eventType} · {item.phase}
                    </Typography.Text>
                    <Typography.Text type="secondary">
                      result={item.result}; retryable={String(item.retryable)}; rateLimited={String(item.rateLimited)}
                    </Typography.Text>
                    {item.failureCode ? (
                      <Typography.Text type="secondary">failureCode={item.failureCode}</Typography.Text>
                    ) : null}
                    {item.reason ? <Typography.Text type="secondary">reason={item.reason}</Typography.Text> : null}
                    {item.requestSummary ? (
                      <Typography.Text type="secondary">request={item.requestSummary}</Typography.Text>
                    ) : null}
                    {item.responseSummary ? (
                      <Typography.Text type="secondary">response={item.responseSummary}</Typography.Text>
                    ) : null}
                    <Typography.Text type="secondary">{formatTimestamp(item.createdAt)}</Typography.Text>
                  </Space>
                ),
              }))}
            />
          </Card>
        </Space>
      ) : null}
    </Card>
  );
}

function flagColor(flagCode: string): string {
  switch (flagCode) {
    case 'blocked_fallback':
      return 'gold';
    case 'rate_limited':
      return 'red';
    case 'provider_timeout':
      return 'orange';
    default:
      return 'geekblue';
  }
}

function readQueryState(searchParams: URLSearchParams): QueryState {
  const rawFlag = normalizeQueryValue(searchParams.get('flag'));

  return {
    installationId: normalizeQueryValue(searchParams.get('installationId')),
    rawFlag,
    flag: normalizeFlag(rawFlag),
    selected: normalizeQueryValue(searchParams.get('selected')),
  };
}

function normalizeFlag(value: string | undefined): MentorAuditFlag | undefined {
  if (!value) {
    return undefined;
  }
  return (MENTOR_AUDIT_FLAGS as readonly string[]).includes(value) ? (value as MentorAuditFlag) : undefined;
}

function normalizeQueryValue(value: string | null | undefined): string | undefined {
  if (!value) {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed ? trimmed : undefined;
}

function updateQuery(
  setSearchParams: ReturnType<typeof useSearchParams>[1],
  query: QueryState,
) {
  const params = new URLSearchParams();
  if (query.installationId) {
    params.set('installationId', query.installationId);
  }
  if (query.rawFlag) {
    params.set('flag', query.rawFlag);
  }
  if (query.selected) {
    params.set('selected', query.selected);
  }
  setSearchParams(params, { replace: false });
}

function formatTimestamp(value: string): string {
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

export default MentorAuditPage;
