import { Alert, Button, Card, Descriptions, Empty, List, Space, Spin, Tag, Typography } from 'antd';
import { useCallback, useEffect, useState } from 'react';
import { warmPaperAdmin } from '../../app/theme';
import { ApiError, toApiError } from '../../lib/authClient';
import {
  knowledgeOpsClient,
  type PalaceBridgeEdgeView,
  type PalaceProjectionStatusView,
  type PalaceQueryTraceSampleView,
  type PalaceRagSubview,
} from '../../lib/knowledgeOpsClient';
import {
  DEFAULT_BRIDGE_REVIEW_STATUS,
  DEFAULT_QUEUE_LIMIT,
  type KnowledgeQueryPatch,
  type PalaceRagActionState,
  type QueryState,
  countTraceCandidates,
  formatConfidence,
  formatTimestamp,
  palaceBridgeStatusColor,
} from '../../lib/knowledgeOpsUtils';
import { DetailContainer } from './DetailContainer';
import { QueuePageShell } from './QueuePageShell';

const PALACE_TRACE_LIMIT = 20;

const PALACE_RAG_VIEW_OPTIONS: Array<{ value: PalaceRagSubview; label: string }> = [
  { value: 'bridge-review', label: 'Bridge review' },
  { value: 'trace-samples', label: 'Trace samples' },
  { value: 'projection', label: 'Projection' },
];

export interface PalaceRagSurfaceProps {
  query: QueryState;
  onPatchQuery: (patch: KnowledgeQueryPatch) => void;
  canRead: boolean;
  canWrite: boolean;
  needsCanonicalQuery: boolean;
}

export function PalaceRagSurface({
  query,
  onPatchQuery,
  canRead,
  canWrite,
  needsCanonicalQuery,
}: PalaceRagSurfaceProps) {
  const [palaceReloadNonce, setPalaceReloadNonce] = useState(0);
  const [bridgeEdges, setBridgeEdges] = useState<PalaceBridgeEdgeView[]>([]);
  const [bridgeLoading, setBridgeLoading] = useState(false);
  const [bridgeError, setBridgeError] = useState<ApiError | null>(null);
  const [bridgeDetail, setBridgeDetail] = useState<PalaceBridgeEdgeView | null>(null);
  const [bridgeDetailLoading, setBridgeDetailLoading] = useState(false);
  const [bridgeDetailError, setBridgeDetailError] = useState<ApiError | null>(null);
  const [projectionStatus, setProjectionStatus] = useState<PalaceProjectionStatusView | null>(null);
  const [projectionLoading, setProjectionLoading] = useState(false);
  const [projectionError, setProjectionError] = useState<ApiError | null>(null);
  const [traceItems, setTraceItems] = useState<PalaceQueryTraceSampleView[]>([]);
  const [tracesLoading, setTracesLoading] = useState(false);
  const [tracesError, setTracesError] = useState<ApiError | null>(null);
  const [palaceRagAction, setPalaceRagAction] = useState<PalaceRagActionState>({ phase: 'idle' });

  const fetchBridgeEdges = useCallback(async () => {
    setBridgeLoading(true);
    setBridgeError(null);
    try {
      const nextEdges = await knowledgeOpsClient.listBridgeEdges({
        status: DEFAULT_BRIDGE_REVIEW_STATUS,
        limit: DEFAULT_QUEUE_LIMIT,
      });
      setBridgeEdges(nextEdges);
      return nextEdges;
    } catch (error) {
      const apiError = toApiError(error);
      setBridgeEdges([]);
      setBridgeError(apiError);
      return null;
    } finally {
      setBridgeLoading(false);
    }
  }, []);

  const fetchBridgeDetail = useCallback(async (edgeId: string) => {
    setBridgeDetailLoading(true);
    setBridgeDetailError(null);
    try {
      const nextEdge = await knowledgeOpsClient.getBridgeEdge(edgeId);
      setBridgeDetail(nextEdge);
      return nextEdge;
    } catch (error) {
      const apiError = toApiError(error);
      setBridgeDetail(null);
      setBridgeDetailError(apiError);
      return null;
    } finally {
      setBridgeDetailLoading(false);
    }
  }, []);

  const fetchProjectionStatus = useCallback(async () => {
    setProjectionLoading(true);
    setProjectionError(null);
    try {
      const nextStatus = await knowledgeOpsClient.getProjectionStatus();
      setProjectionStatus(nextStatus);
      return nextStatus;
    } catch (error) {
      const apiError = toApiError(error);
      setProjectionStatus(null);
      setProjectionError(apiError);
      return null;
    } finally {
      setProjectionLoading(false);
    }
  }, []);

  const fetchTraceSamples = useCallback(async () => {
    setTracesLoading(true);
    setTracesError(null);
    try {
      const nextItems = await knowledgeOpsClient.listTraceSamples({ limit: PALACE_TRACE_LIMIT });
      setTraceItems(nextItems);
      return nextItems;
    } catch (error) {
      const apiError = toApiError(error);
      setTraceItems([]);
      setTracesError(apiError);
      return null;
    } finally {
      setTracesLoading(false);
    }
  }, []);

  const refreshPalaceRagSurface = useCallback(async () => {
    const selectedId = query.selected;
    await Promise.all([
      fetchBridgeEdges(),
      fetchProjectionStatus(),
      query.palaceRagSubview === 'trace-samples' ? fetchTraceSamples() : Promise.resolve(null),
      selectedId ? fetchBridgeDetail(selectedId) : Promise.resolve(null),
    ]);
  }, [fetchBridgeDetail, fetchBridgeEdges, fetchProjectionStatus, fetchTraceSamples, query.palaceRagSubview, query.selected]);

  useEffect(() => {
    if (needsCanonicalQuery || query.view !== 'palace-rag') {
      return;
    }
    void refreshPalaceRagSurface();
  }, [needsCanonicalQuery, palaceReloadNonce, query.palaceRagSubview, query.selected, query.view, refreshPalaceRagSurface]);

  const selectedBridgeEdgeId = query.view === 'palace-rag' ? query.selected : undefined;
  const selectedBridgeEdgeNotInList =
    selectedBridgeEdgeId !== undefined &&
    !bridgeLoading &&
    bridgeError == null &&
    !bridgeEdges.some((edge) => edge.id === selectedBridgeEdgeId);

  const handleBridgeReview = useCallback(
    async (decision: 'approve' | 'reject') => {
      const edgeId = bridgeDetail?.id ?? selectedBridgeEdgeId;
      if (!edgeId) {
        setPalaceRagAction({
          phase: 'error',
          edgeId: 'missing',
          error: new ApiError(400, 'invalid_palace_bridge_edge_id', '当前没有可操作的 bridge edge。'),
        });
        return;
      }

      setPalaceRagAction({ phase: 'pending', edgeId });
      try {
        const nextEdge =
          decision === 'approve'
            ? await knowledgeOpsClient.approveBridgeEdge(edgeId)
            : await knowledgeOpsClient.rejectBridgeEdge(edgeId);
        setBridgeDetail(nextEdge);
        setBridgeDetailError(null);
        setPalaceRagAction({ phase: 'success', edge: nextEdge });
        setPalaceReloadNonce((value) => value + 1);
      } catch (error) {
        setPalaceRagAction({ phase: 'error', edgeId, error: toApiError(error) });
      }
    },
    [bridgeDetail?.id, selectedBridgeEdgeId],
  );

  if (!canRead || query.view !== 'palace-rag') {
    return null;
  }

  const traceTagColor = tracesError ? 'warning' : tracesLoading ? 'processing' : query.palaceRagSubview === 'trace-samples' ? 'success' : 'default';
  const traceTagLabel = tracesError
    ? tracesError.code
    : tracesLoading
      ? 'loading'
      : query.palaceRagSubview === 'trace-samples'
        ? 'ready'
        : 'idle';

  return (
    <>
      <Card size="small" title="Palace diagnostics">
        <Space direction="vertical" size={8} style={{ width: '100%' }}>
          <Typography.Text type="secondary">
            bridge queue / detail、projection、trace samples 的读取状态都留在 surface 内；失败时继续保留当前 URL 上下文，便于 operator 原地排查。
          </Typography.Text>
          <Space wrap>
            <Tag color={bridgeError ? 'warning' : bridgeLoading ? 'processing' : 'success'}>
              queue: {bridgeError ? bridgeError.code : bridgeLoading ? 'loading' : 'ready'}
            </Tag>
            <Tag color={bridgeDetailError ? 'warning' : bridgeDetailLoading ? 'processing' : 'success'}>
              detail: {bridgeDetailError ? bridgeDetailError.code : bridgeDetailLoading ? 'loading' : 'ready'}
            </Tag>
            <Tag color={projectionError ? 'warning' : projectionLoading ? 'processing' : 'success'}>
              projection: {projectionError ? projectionError.code : projectionLoading ? 'loading' : 'ready'}
            </Tag>
            <Tag color={traceTagColor}>traces: {traceTagLabel}</Tag>
          </Space>
        </Space>
      </Card>

      <Card size="small" title="Palace RAG controls">
        <Space direction="vertical" size="middle" style={{ width: '100%' }}>
          <div>
            <Typography.Text type="secondary">sub-view</Typography.Text>
            <Space wrap style={{ marginTop: 8 }}>
              {PALACE_RAG_VIEW_OPTIONS.map((option) => (
                <Button
                  key={option.value}
                  data-testid={`knowledge-palace-subview-${option.value}`}
                  type={query.palaceRagSubview === option.value ? 'primary' : 'default'}
                  onClick={() =>
                    onPatchQuery({
                      status: option.value,
                    })
                  }
                >
                  {option.label}
                </Button>
              ))}
            </Space>
          </div>

          <Space wrap>
            <Button data-testid="knowledge-palace-reload" onClick={() => setPalaceReloadNonce((value) => value + 1)}>
              重新读取 Palace surface
            </Button>
          </Space>

          <PalaceRagActionFeedback state={palaceRagAction} />
        </Space>
      </Card>

      {query.palaceRagSubview === 'bridge-review' ? (
        <QueuePageShell
          queue={
            <Card title={`Bridge review queue (${bridgeEdges.length})`} data-testid="knowledge-palace-bridge-list">
              {bridgeError ? (
                <Alert
                  showIcon
                  type={bridgeError.status >= 500 || bridgeError.status === 0 ? 'error' : 'warning'}
                  data-testid="knowledge-palace-bridge-list-error"
                  style={{ marginBottom: 16 }}
                  message="bridge review queue 读取失败"
                  description={
                    <Space direction="vertical" size={8}>
                      <span>{bridgeError.message}</span>
                      <Typography.Text type="secondary">错误码：{bridgeError.code}</Typography.Text>
                    </Space>
                  }
                />
              ) : null}

              {selectedBridgeEdgeNotInList && !bridgeError ? (
                <Alert
                  showIcon
                  type="warning"
                  data-testid="knowledge-palace-selected-missing"
                  style={{ marginBottom: 16 }}
                  message="当前选中的 bridge edge 不在 proposed queue 里"
                  description="可能是因为刚刚 approve / reject 后状态已变化。详情面仍会保留当前 selected edge。"
                />
              ) : null}

              {bridgeLoading ? (
                <div style={{ padding: '24px 0' }}>
                  <Spin tip="正在读取 bridge review queue…" />
                </div>
              ) : null}

              {!bridgeLoading && bridgeEdges.length === 0 && !bridgeError ? (
                <div data-testid="knowledge-palace-bridge-empty">
                  <Empty description="当前没有待审核的 bridge edges。" />
                </div>
              ) : null}

              {!bridgeLoading && bridgeEdges.length > 0 ? (
                <List
                  dataSource={bridgeEdges}
                  renderItem={(edge) => {
                    const selected = edge.id === selectedBridgeEdgeId;
                    return (
                      <List.Item key={edge.id} data-testid={`knowledge-palace-bridge-row-${edge.id}`}>
                        <Card
                          size="small"
                          style={{
                            width: '100%',
                            borderColor: selected ? warmPaperAdmin.palette.accentDark : undefined,
                          }}
                          title={
                            <Space wrap>
                              <Typography.Text code>{edge.id}</Typography.Text>
                              <Tag color={palaceBridgeStatusColor(edge.status)}>{edge.status}</Tag>
                              <Tag color="processing">confidence {formatConfidence(edge.confidence)}</Tag>
                            </Space>
                          }
                          extra={
                            <Button
                              type={selected ? 'default' : 'primary'}
                              data-testid={`knowledge-open-palace-bridge-${edge.id}`}
                              onClick={() =>
                                onPatchQuery({
                                  selected: edge.id,
                                })
                              }
                            >
                              {selected ? '已打开' : '查看详情'}
                            </Button>
                          }
                        >
                          <Descriptions column={1} size="small">
                            <Descriptions.Item label="room A">{edge.roomAWing} / {edge.roomAName}</Descriptions.Item>
                            <Descriptions.Item label="room B">{edge.roomBWing} / {edge.roomBName}</Descriptions.Item>
                            <Descriptions.Item label="createdAt">{formatTimestamp(edge.createdAt)}</Descriptions.Item>
                          </Descriptions>
                        </Card>
                      </List.Item>
                    );
                  }}
                />
              ) : null}
            </Card>
          }
          detail={
            <DetailContainer
              title={selectedBridgeEdgeId ? `Bridge detail · ${selectedBridgeEdgeId}` : 'Bridge detail'}
              extra={
                <Space>
                  {selectedBridgeEdgeId ? (
                    <Button data-testid="knowledge-close-palace-bridge-detail" onClick={() => onPatchQuery({ selected: undefined })}>
                      关闭详情
                    </Button>
                  ) : null}
                  {selectedBridgeEdgeId ? (
                    <Button data-testid="knowledge-reload-palace-bridge-detail" onClick={() => setPalaceReloadNonce((value) => value + 1)}>
                      重试 detail
                    </Button>
                  ) : null}
                </Space>
              }
              testId="knowledge-palace-bridge-detail"
            >
              {!selectedBridgeEdgeId ? (
                <div data-testid="knowledge-palace-bridge-placeholder">
                  <Empty description="从 bridge review queue 里选择一条 edge 后，这里会显示 bridge 详情与 approve / reject 操作。" />
                </div>
              ) : null}

              {selectedBridgeEdgeId && bridgeDetailLoading ? (
                <div data-testid="knowledge-palace-bridge-detail-loading" style={{ padding: '24px 0' }}>
                  <Spin tip="正在读取 bridge detail…" />
                </div>
              ) : null}

              {selectedBridgeEdgeId && !bridgeDetailLoading && bridgeDetailError ? (
                <Alert
                  showIcon
                  type={bridgeDetailError.status === 404 ? 'warning' : 'error'}
                  data-testid="knowledge-palace-bridge-detail-error"
                  message={bridgeDetailError.status === 404 ? 'bridge detail 不存在' : 'bridge detail 读取失败'}
                  description={
                    <Space direction="vertical" size={8}>
                      <span>{bridgeDetailError.message}</span>
                      <Typography.Text type="secondary">错误码：{bridgeDetailError.code}</Typography.Text>
                    </Space>
                  }
                />
              ) : null}

              {bridgeDetail && !bridgeDetailLoading && !bridgeDetailError ? (
                <Space direction="vertical" size="middle" style={{ width: '100%' }}>
                  <Descriptions column={1} bordered size="small">
                    <Descriptions.Item label="edgeId">
                      <Typography.Text code>{bridgeDetail.id}</Typography.Text>
                    </Descriptions.Item>
                    <Descriptions.Item label="status">
                      <Tag data-testid="knowledge-palace-bridge-status" color={palaceBridgeStatusColor(bridgeDetail.status)}>
                        {bridgeDetail.status}
                      </Tag>
                    </Descriptions.Item>
                    <Descriptions.Item label="confidence">{formatConfidence(bridgeDetail.confidence)}</Descriptions.Item>
                    <Descriptions.Item label="room A">{bridgeDetail.roomAWing} / {bridgeDetail.roomAName}</Descriptions.Item>
                    <Descriptions.Item label="room B">{bridgeDetail.roomBWing} / {bridgeDetail.roomBName}</Descriptions.Item>
                    <Descriptions.Item label="sourceBookA">{bridgeDetail.sourceBookA}</Descriptions.Item>
                    <Descriptions.Item label="sourceBookB">{bridgeDetail.sourceBookB}</Descriptions.Item>
                    <Descriptions.Item label="createdAt">{formatTimestamp(bridgeDetail.createdAt)}</Descriptions.Item>
                    <Descriptions.Item label="reviewedBy">{bridgeDetail.reviewedBy ?? '—'}</Descriptions.Item>
                    <Descriptions.Item label="reviewedAt">{formatTimestamp(bridgeDetail.reviewedAt)}</Descriptions.Item>
                  </Descriptions>

                  <Card size="small" title="Bridge decision">
                    <Space direction="vertical" size="middle" style={{ width: '100%' }}>
                      <Typography.Text type="secondary">
                        仅 `proposed` edge 可执行 approve / reject；操作后 queue 会刷新，但当前 selected context 会保留。
                      </Typography.Text>
                      <Space wrap>
                        <Button
                          type="primary"
                          data-testid="knowledge-palace-approve-bridge"
                          disabled={!canWrite || bridgeDetail.status !== 'proposed'}
                          loading={palaceRagAction.phase === 'pending' && palaceRagAction.edgeId === bridgeDetail.id}
                          onClick={() => void handleBridgeReview('approve')}
                        >
                          Approve edge
                        </Button>
                        <Button
                          danger
                          data-testid="knowledge-palace-reject-bridge"
                          disabled={!canWrite || bridgeDetail.status !== 'proposed'}
                          loading={palaceRagAction.phase === 'pending' && palaceRagAction.edgeId === bridgeDetail.id}
                          onClick={() => void handleBridgeReview('reject')}
                        >
                          Reject edge
                        </Button>
                      </Space>
                    </Space>
                  </Card>
                </Space>
              ) : null}
            </DetailContainer>
          }
        />
      ) : null}

      {query.palaceRagSubview === 'trace-samples' ? (
        <Card title={`Trace samples (${traceItems.length})`} data-testid="knowledge-palace-trace-list">
          {tracesError ? (
            <Alert
              showIcon
              type={tracesError.status >= 500 || tracesError.status === 0 ? 'error' : 'warning'}
              data-testid="knowledge-palace-trace-error"
              style={{ marginBottom: 16 }}
              message="trace samples 读取失败"
              description={
                <Space direction="vertical" size={8}>
                  <span>{tracesError.message}</span>
                  <Typography.Text type="secondary">错误码：{tracesError.code}</Typography.Text>
                </Space>
              }
            />
          ) : null}

          {tracesLoading ? (
            <div style={{ padding: '24px 0' }}>
              <Spin tip="正在读取 trace samples…" />
            </div>
          ) : null}

          {!tracesLoading && traceItems.length === 0 && !tracesError ? (
            <Empty description="当前没有可供抽样的 QueryTrace 记录。" />
          ) : null}

          {!tracesLoading && traceItems.length > 0 ? (
            <List
              dataSource={traceItems}
              renderItem={(trace) => {
                const candidateCount = countTraceCandidates(trace.candidatesJson);
                return (
                  <List.Item key={trace.id} data-testid={`knowledge-palace-trace-row-${trace.id}`}>
                    <Card size="small" style={{ width: '100%' }}>
                      <Space direction="vertical" size={8} style={{ width: '100%' }}>
                        <Space wrap>
                          <Typography.Text code>{trace.id}</Typography.Text>
                          <Tag color="processing">{trace.temporalRuleApplied ?? 'skipped'}</Tag>
                          <Tag>queriedAt: {formatTimestamp(trace.queriedAt)}</Tag>
                          <Tag>projection: {trace.projectionVersionUsed ?? '—'}</Tag>
                          <Tag>candidates: {candidateCount ?? 'unparseable'}</Tag>
                        </Space>
                        <Typography.Text type="secondary">entry_rooms</Typography.Text>
                        <Typography.Paragraph style={{ marginBottom: 0, whiteSpace: 'pre-wrap' }}>
                          {trace.entryRooms}
                        </Typography.Paragraph>
                        <Typography.Text type="secondary">candidates_json</Typography.Text>
                        <Typography.Paragraph style={{ marginBottom: 0, whiteSpace: 'pre-wrap' }}>
                          {trace.candidatesJson}
                        </Typography.Paragraph>
                        <Typography.Text type="secondary">
                          bridge_edges_crossed: {trace.bridgeEdgesCrossed ?? '—'}
                        </Typography.Text>
                      </Space>
                    </Card>
                  </List.Item>
                );
              }}
            />
          ) : null}
        </Card>
      ) : null}

      {query.palaceRagSubview === 'projection' ? (
        <Card title="Projection status" data-testid="knowledge-palace-projection-status">
          {projectionError ? (
            <Alert
              showIcon
              type={projectionError.status >= 500 || projectionError.status === 0 ? 'error' : 'warning'}
              data-testid="knowledge-palace-projection-error"
              style={{ marginBottom: 16 }}
              message="projection status 读取失败"
              description={
                <Space direction="vertical" size={8}>
                  <span>{projectionError.message}</span>
                  <Typography.Text type="secondary">错误码：{projectionError.code}</Typography.Text>
                </Space>
              }
            />
          ) : null}

          {projectionLoading ? (
            <div style={{ padding: '24px 0' }}>
              <Spin tip="正在读取 projection status…" />
            </div>
          ) : null}

          {!projectionLoading && projectionStatus?.notReady ? (
            <Empty description="No projection available yet — trigger a book ingestion to populate." />
          ) : null}

          {!projectionLoading && projectionStatus && !projectionStatus.notReady ? (
            <Descriptions column={1} bordered size="small">
              <Descriptions.Item label="versionNum">{projectionStatus.versionNum ?? '—'}</Descriptions.Item>
              <Descriptions.Item label="roomCount">{projectionStatus.roomCount ?? '—'}</Descriptions.Item>
              <Descriptions.Item label="lastIngestionBatchId">{projectionStatus.lastIngestionBatchId ?? '—'}</Descriptions.Item>
              <Descriptions.Item label="status">{projectionStatus.status ?? '—'}</Descriptions.Item>
              <Descriptions.Item label="createdAt">{formatTimestamp(projectionStatus.createdAt)}</Descriptions.Item>
            </Descriptions>
          ) : null}
        </Card>
      ) : null}
    </>
  );
}

function PalaceRagActionFeedback({ state }: { state: PalaceRagActionState }) {
  if (state.phase === 'idle') {
    return null;
  }

  if (state.phase === 'pending') {
    return (
      <Alert
        showIcon
        type="info"
        data-testid="knowledge-palace-feedback"
        message="正在提交 bridge edge 决策"
        description={state.edgeId}
      />
    );
  }

  if (state.phase === 'error') {
    return (
      <Alert
        showIcon
        type="error"
        data-testid="knowledge-palace-feedback"
        message="bridge edge 决策失败"
        description={`${state.error.message}（${state.error.code}）`}
      />
    );
  }

  return (
    <Alert
      showIcon
      type="success"
      data-testid="knowledge-palace-feedback"
      message="bridge edge 状态已更新"
      description={`edgeId=${state.edge.id}; status=${state.edge.status}; reviewedBy=${state.edge.reviewedBy ?? '—'}; reviewedAt=${formatTimestamp(state.edge.reviewedAt)}`}
    />
  );
}
