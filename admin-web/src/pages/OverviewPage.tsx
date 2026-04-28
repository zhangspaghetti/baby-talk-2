import { Alert, Button, Card, Collapse, Empty, Space, Spin, Tag, Typography } from 'antd';
import { useCallback, useEffect, useMemo, useRef, useState, type CSSProperties } from 'react';
import { Link } from 'react-router-dom';
import { warmPaperAdmin } from '../app/theme';
import { useAuth } from '../auth/auth-provider';
import { ApiError, toApiError } from '../lib/authClient';
import {
  overviewClient,
  type OverviewDomainView,
  type OverviewHeartbeatView,
  type OverviewSummaryView,
  type OverviewTransportSubscription,
  type OverviewTransportView,
} from '../lib/overviewClient';

const POLL_INTERVAL_MS = 5_000;
const MAX_POLL_FAILURES = 3;

type ClientTransportState = 'streaming' | 'polling';
type SummaryLoadPhase = 'loading' | 'ready' | 'refreshing';
type RecoveryNotice = {
  at: string;
  reason?: string;
};

export default function OverviewPage() {
  const { session } = useAuth();
  if (!session) {
    throw new Error('OverviewPage requires an active admin session.');
  }

  const [summary, setSummary] = useState<OverviewSummaryView | null>(null);
  const [transport, setTransport] = useState<OverviewTransportView | null>(null);
  const [loadPhase, setLoadPhase] = useState<SummaryLoadPhase>('loading');
  const [summaryError, setSummaryError] = useState<ApiError | null>(null);
  const [manualSummaryErrorPinned, setManualSummaryErrorPinned] = useState(false);
  const [pollingError, setPollingError] = useState<ApiError | null>(null);
  const [streamError, setStreamError] = useState<ApiError | null>(null);
  const [clientTransportState, setClientTransportState] = useState<ClientTransportState>('streaming');
  const [clientTransportReason, setClientTransportReason] = useState<string | undefined>();
  const [lastFallbackReason, setLastFallbackReason] = useState<string | undefined>();
  const [lastHeartbeatAt, setLastHeartbeatAt] = useState<string | undefined>();
  const [lastEventId, setLastEventId] = useState<string | undefined>();
  const [pollFailureCount, setPollFailureCount] = useState(0);
  const [pollingPaused, setPollingPaused] = useState(false);
  const [recoveryNotice, setRecoveryNotice] = useState<RecoveryNotice | null>(null);

  const summaryRef = useRef<OverviewSummaryView | null>(null);
  const transportRef = useRef<OverviewTransportView | null>(null);
  const streamSubscriptionRef = useRef<OverviewTransportSubscription | null>(null);
  const lastEventIdRef = useRef<string | undefined>();
  const clientTransportStateRef = useRef<ClientTransportState>('streaming');
  const manualSummaryErrorPinnedRef = useRef(false);
  const activeStreamIdRef = useRef(0);
  const previousOverallModeRef = useRef<'live' | 'polling'>('live');

  useEffect(() => {
    summaryRef.current = summary;
  }, [summary]);

  useEffect(() => {
    transportRef.current = transport;
  }, [transport]);

  useEffect(() => {
    lastEventIdRef.current = lastEventId;
  }, [lastEventId]);

  useEffect(() => {
    clientTransportStateRef.current = clientTransportState;
  }, [clientTransportState]);

  useEffect(() => {
    manualSummaryErrorPinnedRef.current = manualSummaryErrorPinned;
  }, [manualSummaryErrorPinned]);

  const applySummary = useCallback(
    (nextSummary: OverviewSummaryView, options?: { preserveSummaryError?: boolean }) => {
      summaryRef.current = nextSummary;
      transportRef.current = nextSummary.transport;
      lastEventIdRef.current = nextSummary.transport.eventId;

      setSummary(nextSummary);
      setTransport(nextSummary.transport);
      setLastEventId(nextSummary.transport.eventId);
      if (!options?.preserveSummaryError) {
        setSummaryError(null);
        setManualSummaryErrorPinned(false);
      }
      setPollingError(null);
      setPollFailureCount(0);
    },
    [],
  );

  const loadSummary = useCallback(
    async (mode: 'initial' | 'manual' | 'poll') => {
      if (mode === 'initial') {
        setLoadPhase('loading');
      } else if (mode === 'manual') {
        setLoadPhase('refreshing');
      }

      try {
        const nextSummary = await overviewClient.getSummary();
        applySummary(nextSummary, {
          preserveSummaryError: mode === 'poll' && manualSummaryErrorPinnedRef.current,
        });
        return {
          ok: true as const,
          summary: nextSummary,
        };
      } catch (error) {
        const apiError = toApiError(error);
        if (mode === 'poll') {
          setPollingError(apiError);
        } else {
          setSummaryError(apiError);
          setManualSummaryErrorPinned(mode === 'manual');
        }
        return {
          ok: false as const,
          error: apiError,
        };
      } finally {
        if (mode !== 'poll') {
          setLoadPhase('ready');
        }
      }
    },
    [applySummary],
  );

  const enterClientPollingFallback = useCallback(
    (reason: string, error: ApiError) => {
      activeStreamIdRef.current += 1;
      streamSubscriptionRef.current?.close();
      streamSubscriptionRef.current = null;
      setClientTransportState('polling');
      setClientTransportReason(reason);
      setLastFallbackReason(reason);
      setStreamError(error);
      setPollingPaused(false);
      setPollFailureCount(0);
      void loadSummary('poll');
    },
    [loadSummary],
  );

  const startTransportStream = useCallback(() => {
    streamSubscriptionRef.current?.close();

    const streamId = activeStreamIdRef.current + 1;
    activeStreamIdRef.current = streamId;

    setClientTransportState('streaming');
    setClientTransportReason(undefined);
    setStreamError(null);

    streamSubscriptionRef.current = overviewClient.subscribeTransport({
      lastEventId: lastEventIdRef.current,
      onTransport: (nextTransport) => {
        if (activeStreamIdRef.current != streamId) {
          return;
        }
        const previousTransport = transportRef.current;
        const wasClientPolling = clientTransportStateRef.current === 'polling';

        transportRef.current = nextTransport;
        lastEventIdRef.current = nextTransport.eventId;

        setTransport(nextTransport);
        setLastEventId(nextTransport.eventId);
        setStreamError(null);
        setClientTransportState('streaming');
        setClientTransportReason(undefined);
        if (nextTransport.mode === 'polling_required') {
          setLastFallbackReason(nextTransport.degradedReason ?? 'repository_timeout');
          void loadSummary('poll');
        } else if (wasClientPolling || previousTransport?.mode === 'polling_required' || nextTransport.replayed) {
          void loadSummary('poll');
        }
      },
      onHeartbeat: (heartbeat) => {
        if (activeStreamIdRef.current != streamId) {
          return;
        }
        setLastHeartbeatAt(heartbeat.emittedAt);
        setTransport((current) => mergeTransportWithHeartbeat(current, heartbeat));
      },
      onClose: () => {
        if (activeStreamIdRef.current != streamId) {
          return;
        }
        enterClientPollingFallback(
          'stream_disconnected',
          new ApiError(0, 'stream_disconnected', 'Overview realtime 已断开，当前改用 polling。'),
        );
      },
      onError: (error) => {
        if (activeStreamIdRef.current != streamId) {
          return;
        }
        enterClientPollingFallback(error.code, error);
      },
    });
  }, [enterClientPollingFallback, loadSummary]);

  useEffect(() => {
    const handleOffline = () => {
      if (summaryRef.current == null || clientTransportStateRef.current === 'polling') {
        return;
      }

      enterClientPollingFallback(
        'network_error',
        new ApiError(0, 'network_error', '浏览器网络已离线，Overview 当前改用 polling。'),
      );
    };

    window.addEventListener('offline', handleOffline);
    return () => {
      window.removeEventListener('offline', handleOffline);
    };
  }, [enterClientPollingFallback]);

  useEffect(() => {
    let cancelled = false;

    setSummary(null);
    setTransport(null);
    setLoadPhase('loading');
    setSummaryError(null);
    setManualSummaryErrorPinned(false);
    setPollingError(null);
    setStreamError(null);
    setClientTransportState('streaming');
    setClientTransportReason(undefined);
    setLastFallbackReason(undefined);
    setLastHeartbeatAt(undefined);
    setLastEventId(undefined);
    setPollFailureCount(0);
    setPollingPaused(false);
    setRecoveryNotice(null);
    previousOverallModeRef.current = 'live';

    streamSubscriptionRef.current?.close();
    streamSubscriptionRef.current = null;
    summaryRef.current = null;
    transportRef.current = null;
    lastEventIdRef.current = undefined;
    clientTransportStateRef.current = 'streaming';
    manualSummaryErrorPinnedRef.current = false;
    activeStreamIdRef.current = 0;

    void loadSummary('initial').then((result) => {
      if (cancelled || !result.ok) {
        return;
      }
      startTransportStream();
    });

    return () => {
      cancelled = true;
      streamSubscriptionRef.current?.close();
      streamSubscriptionRef.current = null;
    };
  }, [loadSummary, session.accessToken, startTransportStream]);

  const effectiveTransport = transport ?? summary?.transport ?? null;
  const overallMode: 'live' | 'polling' =
    clientTransportState === 'polling' || effectiveTransport?.mode === 'polling_required' ? 'polling' : 'live';

  useEffect(() => {
    const previousMode = previousOverallModeRef.current;
    if (overallMode === 'polling') {
      setRecoveryNotice(null);
      if (clientTransportReason) {
        setLastFallbackReason(clientTransportReason);
      } else if (effectiveTransport?.degradedReason) {
        setLastFallbackReason(effectiveTransport.degradedReason);
      }
    } else if (previousMode === 'polling') {
      setRecoveryNotice({
        at: new Date().toISOString(),
        reason: lastFallbackReason,
      });
    }
    previousOverallModeRef.current = overallMode;
  }, [clientTransportReason, effectiveTransport?.degradedReason, lastFallbackReason, overallMode]);

  const shouldPoll = summary != null && overallMode === 'polling';

  useEffect(() => {
    if (!shouldPoll || pollingPaused) {
      return;
    }

    const timer = window.setTimeout(() => {
      void loadSummary('poll').then((result) => {
        if (result.ok) {
          setPollFailureCount(0);
          setPollingError(null);
          return;
        }

        setPollFailureCount((value) => {
          const nextValue = value + 1;
          if (nextValue >= MAX_POLL_FAILURES) {
            setPollingPaused(true);
          }
          return nextValue;
        });
      });
    }, POLL_INTERVAL_MS);

    return () => {
      window.clearTimeout(timer);
    };
  }, [loadSummary, pollingPaused, shouldPoll, summary?.generatedAt]);

  const visibleDomains = useMemo(() => summary?.domains.filter((domain) => domain.visible) ?? [], [summary]);
  const hiddenDomainCount = summary ? Math.max(summary.domains.length - visibleDomains.length, 0) : 0;
  const controlStripMode = recoveryNotice ? 'recovered' : overallMode;
  const controlStripTone = recoveryNotice
    ? warmPaperAdmin.palette.info
    : overallMode === 'live'
      ? warmPaperAdmin.palette.success
      : warmPaperAdmin.palette.warning;
  const summaryStatusLabel = readSummaryStatusLabel(loadPhase, summaryError);

  const handleManualRefresh = async () => {
    await loadSummary('manual');
  };

  const handleResumePolling = () => {
    setPollingPaused(false);
    setPollFailureCount(0);
    setPollingError(null);
    void loadSummary('poll');
  };

  const handleResumeRealtime = () => {
    setRecoveryNotice(null);
    startTransportStream();
  };

  return (
    <Space direction="vertical" size="large" style={{ width: '100%' }} data-testid="overview-page">
      <Card size="small" title="Overview control plane" data-testid="overview-control-strip">
        <Space direction="vertical" size={12} style={{ width: '100%' }}>
          <Space wrap>
            <Tag color={controlStripTone} data-testid="overview-transport-mode">
              transport: {controlStripMode}
            </Tag>
            <Tag color={clientTransportState === 'polling' ? warmPaperAdmin.palette.warning : warmPaperAdmin.palette.success} data-testid="overview-transport-source">
              source: {clientTransportState === 'polling' ? 'polling fallback' : 'streaming'}
            </Tag>
            <Tag color={effectiveTransport?.mode === 'polling_required' ? warmPaperAdmin.palette.warning : warmPaperAdmin.palette.info} data-testid="overview-server-transport-mode">
              backend: {effectiveTransport?.mode ?? 'unknown'}
            </Tag>
            <Tag data-testid="overview-visible-domain-count">visible domains: {summary?.visibleDomainCount ?? 0}</Tag>
            <Tag data-testid="overview-degraded-domain-count">degraded domains: {summary?.degradedDomainCount ?? 0}</Tag>
            <Tag data-testid="overview-last-good-snapshot">
              last good snapshot: {formatTimestamp(summary?.lastSuccessfulSnapshotAt ?? effectiveTransport?.lastSuccessfulSnapshotAt)}
            </Tag>
          </Space>

          <Typography.Paragraph type="secondary" style={{ marginBottom: 0 }}>
            {readControlStripCopy({
              overallMode,
              recoveryNotice,
              clientTransportState,
              clientTransportReason,
              transportReason: effectiveTransport?.degradedReason,
              lastSuccessfulSnapshotAt: summary?.lastSuccessfulSnapshotAt ?? effectiveTransport?.lastSuccessfulSnapshotAt,
            })}
          </Typography.Paragraph>

          <Space wrap>
            <Button data-testid="overview-refresh-button" loading={loadPhase === 'refreshing'} onClick={() => void handleManualRefresh()}>
              重新读取 summary
            </Button>
            {clientTransportState === 'polling' ? (
              <Button type="primary" data-testid="overview-resume-live" onClick={handleResumeRealtime}>
                恢复 realtime
              </Button>
            ) : null}
            {pollingPaused ? (
              <Button type="primary" data-testid="overview-resume-polling" onClick={handleResumePolling}>
                恢复 polling
              </Button>
            ) : null}
          </Space>
        </Space>
      </Card>

      {clientTransportState === 'polling' ? (
        <Alert
          showIcon
          type="warning"
          data-testid="overview-polling-alert"
          message="realtime 已断开，Overview 当前改用 polling"
          description={`最近一次 stream 失败原因：${readFailureReasonLabel(clientTransportReason)}。最后成功快照仍保留在页面上。`}
        />
      ) : null}

      {effectiveTransport?.mode === 'polling_required' ? (
        <Alert
          showIcon
          type="warning"
          data-testid="overview-backend-polling-alert"
          message="后端已把 transport 标成 polling_required"
          description={`degradedReason=${effectiveTransport.degradedReason ?? 'unknown'}；页面会继续保留最后成功快照，并按 polling 观察恢复。`}
        />
      ) : null}

      {recoveryNotice ? (
        <Alert
          showIcon
          type="success"
          data-testid="overview-recovery-alert"
          message="Overview realtime 已恢复"
          description={`恢复时间：${formatTimestamp(recoveryNotice.at)}；上一次 fallback 原因：${readFailureReasonLabel(recoveryNotice.reason)}。`}
        />
      ) : null}

      {summaryError ? (
        <Alert
          showIcon
          type={summary == null ? 'error' : 'warning'}
          data-testid="overview-summary-error"
          message="overview summary 读取失败"
          description={`${summaryError.message}（${summaryError.code}）`}
        />
      ) : null}

      {pollingError ? (
        <Alert
          showIcon
          type="warning"
          data-testid="overview-polling-error"
          message="polling 未成功更新快照"
          description={`${pollingError.message}（${pollingError.code}）；当前继续显示最后成功快照。`}
        />
      ) : null}

      <Collapse
        defaultActiveKey={[]}
        destroyInactivePanel={false}
        data-testid="overview-inline-diagnostics"
        items={[
          {
            key: 'inline-diagnostics',
            label: 'Inline diagnostics',
            children: (
              <Space direction="vertical" size={10} style={{ width: '100%' }}>
                <Typography.Text type="secondary">
                  Overview 只显示多域 freshness / queue / next action；不会回显 transcript、share token、raw mentor payload 或 public admin-api URL。
                </Typography.Text>
                <Space wrap>
                  <Tag color={summaryError ? warmPaperAdmin.palette.warning : warmPaperAdmin.palette.success} data-testid="overview-diagnostic-summary">
                    summary: {summaryError ? summaryError.code : summaryStatusLabel}
                  </Tag>
                  <Tag color={streamError ? warmPaperAdmin.palette.warning : warmPaperAdmin.palette.success} data-testid="overview-diagnostic-stream">
                    stream: {streamError ? streamError.code : clientTransportState}
                  </Tag>
                  <Tag color={pollingPaused ? warmPaperAdmin.palette.warning : warmPaperAdmin.palette.info} data-testid="overview-diagnostic-polling">
                    polling: {shouldPoll ? (pollingPaused ? 'paused' : `${pollFailureCount}/${MAX_POLL_FAILURES}`) : 'idle'}
                  </Tag>
                  <Tag data-testid="overview-diagnostic-event-id">lastEventId: {lastEventId ?? 'none'}</Tag>
                  <Tag data-testid="overview-diagnostic-heartbeat">lastHeartbeat: {formatTimestamp(lastHeartbeatAt)}</Tag>
                  <Tag data-testid="overview-diagnostic-connections">
                    connections: {effectiveTransport?.connectionCount ?? 0} / reconnects: {effectiveTransport?.reconnectCount ?? 0}
                  </Tag>
                  <Tag data-testid="overview-diagnostic-generated-at">generatedAt: {formatTimestamp(summary?.generatedAt)}</Tag>
                </Space>
              </Space>
            ),
          },
        ]}
      />

      {loadPhase === 'loading' && summary == null ? (
        <Card>
          <div style={{ padding: '40px 0' }} data-testid="overview-loading">
            <Spin tip="正在读取 Overview summary…" />
          </div>
        </Card>
      ) : null}

      {loadPhase !== 'loading' && summary != null && hiddenDomainCount > 0 ? (
        <Alert
          showIcon
          type="info"
          data-testid="overview-hidden-domain-note"
          message="部分 domain 因权限未暴露"
          description={`当前 Overview 只渲染 ${visibleDomains.length} 个 visible domain；其余 ${hiddenDomainCount} 个 domain 保持 fail-closed。`}
        />
      ) : null}

      {loadPhase !== 'loading' && summary != null && visibleDomains.length === 0 ? (
        <Card data-testid="overview-empty-state">
          <Empty description="当前账号没有任何可见 domain；Overview 会保持 fail-closed。" />
        </Card>
      ) : null}

      {loadPhase !== 'loading' && summary != null && visibleDomains.length > 0 ? (
        <div style={overviewGridStyle} data-testid="overview-domain-grid">
          {visibleDomains.map((domain) => renderDomainCard(domain))}
        </div>
      ) : null}
    </Space>
  );
}

function renderDomainCard(domain: OverviewDomainView) {
  return (
    <Card
      key={domain.key}
      size="small"
      title={
        <Space wrap>
          <Typography.Text>{domain.title}</Typography.Text>
          <Tag color={readFreshnessTone(domain.freshness.state)} data-testid={`overview-domain-state-${domain.key}`}>
            {domain.freshness.state}
          </Tag>
        </Space>
      }
      extra={<Tag>{domain.requiredPermission}</Tag>}
      data-testid={`overview-domain-card-${domain.key}`}
    >
      <Space direction="vertical" size={10} style={{ width: '100%' }}>
        <Typography.Paragraph type="secondary" style={{ marginBottom: 0 }}>
          {readDomainNarrative(domain)}
        </Typography.Paragraph>

        <Space wrap>
          <Tag data-testid={`overview-domain-queue-${domain.key}`}>queue: {formatOptionalNumber(domain.queue.queueCount)}</Tag>
          <Tag data-testid={`overview-domain-attention-${domain.key}`}>
            attention: {formatOptionalNumber(domain.queue.attentionCount)}
          </Tag>
          <Tag data-testid={`overview-domain-all-clear-${domain.key}`}>
            allClear: {formatOptionalBoolean(domain.queue.allClear)}
          </Tag>
          <Tag data-testid={`overview-domain-updated-at-${domain.key}`}>
            updatedAt: {formatTimestamp(domain.freshness.sourceUpdatedAt)}
          </Tag>
        </Space>

        <Space wrap>
          {domain.counts.map((count) => (
            <Tag key={count.key} data-testid={`overview-domain-count-${domain.key}-${count.key}`}>
              {count.key}: {count.value}
            </Tag>
          ))}
        </Space>

        <Space direction="vertical" size={6} style={{ width: '100%' }}>
          <Typography.Text type="secondary">next action: {domain.nextAction.label}</Typography.Text>
          {domain.nextAction.href ? (
            <Link to={domain.nextAction.href} data-testid={`overview-domain-next-action-${domain.key}`}>
              <Button size="small" type="primary">
                打开 {domain.title}
              </Button>
            </Link>
          ) : null}
        </Space>
      </Space>
    </Card>
  );
}

function mergeTransportWithHeartbeat(
  current: OverviewTransportView | null,
  heartbeat: OverviewHeartbeatView,
): OverviewTransportView | null {
  if (!current) {
    return current;
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

function readSummaryStatusLabel(loadPhase: SummaryLoadPhase, summaryError: ApiError | null): string {
  if (summaryError) {
    return summaryError.code;
  }
  if (loadPhase === 'loading') {
    return 'loading';
  }
  if (loadPhase === 'refreshing') {
    return 'refreshing';
  }
  return 'ready';
}

function readControlStripCopy(input: {
  overallMode: 'live' | 'polling';
  recoveryNotice: RecoveryNotice | null;
  clientTransportState: ClientTransportState;
  clientTransportReason?: string;
  transportReason?: string;
  lastSuccessfulSnapshotAt?: string;
}): string {
  if (input.recoveryNotice) {
    return `realtime 已恢复；当前重新回到 stream 驱动，最近一次 fallback 原因是 ${readFailureReasonLabel(input.recoveryNotice.reason)}。最后成功快照时间：${formatTimestamp(input.lastSuccessfulSnapshotAt)}。`;
  }
  if (input.overallMode === 'polling') {
    if (input.clientTransportState === 'polling') {
      return `stream 连接已断开，当前保留最后成功快照，并用 polling 继续读取 summary。失败原因：${readFailureReasonLabel(input.clientTransportReason)}。`;
    }
    return `后端 transport 已进入 polling_required；页面会保留最后成功快照，用 bounded polling 等待恢复，而不是继续假装 live。`;
  }
  return 'Overview 现在直接消费 `/api/admin/overview/**`，显示多域 freshness、transport 状态和可执行 next action，不再保留 placeholder。';
}

function readDomainNarrative(domain: OverviewDomainView): string {
  if (domain.freshness.state === 'degraded') {
    return `该 domain 当前保留最后成功快照；degradedReason=${domain.freshness.degradedReason ?? 'unknown'}。`;
  }
  if (domain.freshness.state === 'all_clear') {
    return '当前没有待处理积压，但该 domain 仍保持真实 freshness / next-action contract。';
  }
  if (domain.freshness.state === 'stale') {
    return '该 domain 已超过 freshness 窗口，需要 operator 重新确认当前工作面是否仍然准确。';
  }
  if (domain.freshness.state === 'updating') {
    return '该 domain 仍有进行中的工作流，Overview 会把它标成 updating，而不是假装 all clear。';
  }
  return `当前 next action 是 “${domain.nextAction.label}”，Overview 只暴露 operator-safe 跳转。`;
}

function readFailureReasonLabel(reason?: string): string {
  if (!reason) {
    return 'unknown';
  }

  switch (reason) {
    case 'stream_disconnected':
      return 'stream_disconnected';
    case 'network_error':
      return 'network_error';
    case 'request_timeout':
      return 'request_timeout';
    case 'invalid_response_payload':
      return 'invalid_response_payload';
    case 'poll_budget_exhausted':
      return 'poll_budget_exhausted';
    default:
      return reason;
  }
}

function readFreshnessTone(state: OverviewDomainView['freshness']['state']): string {
  switch (state) {
    case 'all_clear':
    case 'fresh':
      return warmPaperAdmin.palette.success;
    case 'updating':
      return warmPaperAdmin.palette.info;
    case 'stale':
    case 'degraded':
      return warmPaperAdmin.palette.warning;
    case 'forbidden':
      return 'default';
    default:
      return 'default';
  }
}

function formatTimestamp(value?: string): string {
  if (!value) {
    return '—';
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return value;
  }

  return parsed.toLocaleString('zh-CN', {
    hour12: false,
  });
}

function formatOptionalNumber(value?: number): string {
  return value == null ? '—' : String(value);
}

function formatOptionalBoolean(value?: boolean): string {
  if (value == null) {
    return '—';
  }
  return value ? 'true' : 'false';
}

const overviewGridStyle: CSSProperties = {
  display: 'grid',
  gap: 16,
  gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
  alignItems: 'start',
};
