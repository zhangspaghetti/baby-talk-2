import { Alert, Button, Card, Descriptions, Empty, Input, List, Space, Spin, Tag, Typography } from 'antd';
import { useCallback, useEffect, useState } from 'react';
import { warmPaperAdmin } from '../../app/theme';
import { ApiError, toApiError } from '../../lib/authClient';
import {
  KNOWLEDGE_CONTRADICTION_FILTERS,
  knowledgeOpsClient,
  type KnowledgeContradictionFilter,
  type KnowledgeContradictionQueueItemView,
  type KnowledgeContradictionDetailView,
  type KnowledgeNotificationView,
} from '../../lib/knowledgeOpsClient';
import {
  DEFAULT_NOTIFICATION_LIMIT,
  DEFAULT_QUEUE_LIMIT,
  type KgActionState,
  type KnowledgeQueryPatch,
  type QueryState,
  contradictionStatusColor,
  formatTimestamp,
  notificationTypeColor,
  readStringDetail,
} from '../../lib/knowledgeOpsUtils';
import { DetailContainer } from './DetailContainer';
import { QueuePageShell } from './QueuePageShell';

const KG_VIEW_OPTIONS: Array<{ value: KnowledgeContradictionFilter; label: string }> = KNOWLEDGE_CONTRADICTION_FILTERS.map(
  (value) => ({
    value,
    label: value === 'all' ? '全部' : value,
  }),
);

export interface KgSurfaceProps {
  query: QueryState;
  onPatchQuery: (patch: KnowledgeQueryPatch) => void;
  canRead: boolean;
  canReview: boolean;
  needsCanonicalQuery: boolean;
}

export function KgSurface({ query, onPatchQuery, canRead, canReview, needsCanonicalQuery }: KgSurfaceProps) {
  const [kgQueueItems, setKgQueueItems] = useState<KnowledgeContradictionQueueItemView[]>([]);
  const [kgLoading, setKgLoading] = useState(false);
  const [kgError, setKgError] = useState<ApiError | null>(null);
  const [kgReloadNonce, setKgReloadNonce] = useState(0);
  const [kgDetail, setKgDetail] = useState<KnowledgeContradictionDetailView | null>(null);
  const [kgDetailLoading, setKgDetailLoading] = useState(false);
  const [kgDetailError, setKgDetailError] = useState<ApiError | null>(null);
  const [notifications, setNotifications] = useState<KnowledgeNotificationView[]>([]);
  const [notificationsLoading, setNotificationsLoading] = useState(false);
  const [notificationsError, setNotificationsError] = useState<ApiError | null>(null);
  const [kgActionState, setKgActionState] = useState<KgActionState>({ phase: 'idle' });
  const [resolveDraft, setResolveDraft] = useState('');

  useEffect(() => {
    if (query.view !== 'kg-review') {
      return;
    }
    setResolveDraft(kgDetail?.adminNotes ?? '');
  }, [kgDetail?.adminNotes, kgDetail?.id, query.view]);

  const fetchKgQueue = useCallback(async () => {
    setKgLoading(true);
    setKgError(null);
    try {
      const nextItems = await knowledgeOpsClient.listContradictions({
        status: query.kgStatus === 'all' ? undefined : query.kgStatus,
        limit: DEFAULT_QUEUE_LIMIT,
      });
      setKgQueueItems(nextItems);
      return nextItems;
    } catch (error) {
      const apiError = toApiError(error);
      setKgQueueItems([]);
      setKgError(apiError);
      return null;
    } finally {
      setKgLoading(false);
    }
  }, [query.kgStatus]);

  const fetchKgDetail = useCallback(async (contradictionId: string) => {
    setKgDetailLoading(true);
    setKgDetailError(null);
    try {
      const nextDetail = await knowledgeOpsClient.getContradiction(contradictionId);
      setKgDetail(nextDetail);
      return nextDetail;
    } catch (error) {
      const apiError = toApiError(error);
      setKgDetail(null);
      setKgDetailError(apiError);
      return null;
    } finally {
      setKgDetailLoading(false);
    }
  }, []);

  const fetchNotifications = useCallback(async (contradictionId: string) => {
    setNotificationsLoading(true);
    setNotificationsError(null);
    try {
      const nextNotifications = await knowledgeOpsClient.listNotifications(contradictionId, {
        limit: DEFAULT_NOTIFICATION_LIMIT,
      });
      setNotifications(nextNotifications);
      return nextNotifications;
    } catch (error) {
      const apiError = toApiError(error);
      setNotifications([]);
      setNotificationsError(apiError);
      return null;
    } finally {
      setNotificationsLoading(false);
    }
  }, []);

  const refreshKgSurface = useCallback(async () => {
    const selectedId = query.selected;
    await Promise.all([
      fetchKgQueue(),
      selectedId ? fetchKgDetail(selectedId) : Promise.resolve(null),
      selectedId ? fetchNotifications(selectedId) : Promise.resolve(null),
    ]);
  }, [fetchKgDetail, fetchKgQueue, fetchNotifications, query.selected]);

  useEffect(() => {
    if (needsCanonicalQuery || query.view !== 'kg-review') {
      return;
    }
    void refreshKgSurface();
  }, [kgReloadNonce, needsCanonicalQuery, query.kgStatus, query.selected, query.view, refreshKgSurface]);

  const selectedContradictionId = query.view === 'kg-review' ? query.selected : undefined;
  const selectedContradictionNotInList =
    selectedContradictionId !== undefined &&
    !kgLoading &&
    kgError == null &&
    !kgQueueItems.some((item) => item.id === selectedContradictionId);

  const handleResolve = useCallback(async () => {
    const contradictionId = kgDetail?.id ?? selectedContradictionId;
    if (!contradictionId) {
      setKgActionState({
        phase: 'error',
        kind: 'resolve',
        target: 'missing',
        error: new ApiError(400, 'invalid_knowledge_contradiction_id', '当前没有可处理的 contradiction。'),
      });
      return;
    }

    setKgActionState({ phase: 'pending', kind: 'resolve', target: contradictionId });
    try {
      const detail = await knowledgeOpsClient.resolveContradiction(contradictionId, resolveDraft);
      setKgActionState({ phase: 'success', kind: 'resolve', detail });
      setKgReloadNonce((value) => value + 1);
    } catch (error) {
      setKgActionState({ phase: 'error', kind: 'resolve', target: contradictionId, error: toApiError(error) });
    }
  }, [kgDetail?.id, resolveDraft, selectedContradictionId]);

  const handleMarkNotificationRead = useCallback(async (notificationId: string) => {
    setKgActionState({ phase: 'pending', kind: 'mark-read', target: notificationId });
    try {
      const notification = await knowledgeOpsClient.markNotificationRead(notificationId);
      setKgActionState({ phase: 'success', kind: 'mark-read', notification });
      setKgReloadNonce((value) => value + 1);
    } catch (error) {
      setKgActionState({ phase: 'error', kind: 'mark-read', target: notificationId, error: toApiError(error) });
    }
  }, []);

  if (!canRead || query.view !== 'kg-review') {
    return null;
  }

  const notificationsTagColor = notificationsError
    ? 'warning'
    : notificationsLoading
      ? 'processing'
      : selectedContradictionId
        ? 'success'
        : 'default';
  const notificationsTagLabel = notificationsError
    ? notificationsError.code
    : notificationsLoading
      ? 'loading'
      : selectedContradictionId
        ? 'ready'
        : 'idle';

  return (
    <>
      <Card size="small" title="KG diagnostics" data-testid="knowledge-kg-diagnostics">
        <Space direction="vertical" size={8} style={{ width: '100%' }}>
          <Typography.Text type="secondary">
            contradiction queue / detail / notifications 的读取状态都留在 KG surface 内；失败时保留当前 URL 上下文，operator 可以继续在当前 surface 排查。
          </Typography.Text>
          <Space wrap>
            <Tag color={kgError ? 'warning' : kgLoading ? 'processing' : 'success'}>
              list: {kgError ? kgError.code : kgLoading ? 'loading' : 'ready'}
            </Tag>
            <Tag color={kgDetailError ? 'warning' : kgDetailLoading ? 'processing' : 'success'}>
              detail: {kgDetailError ? kgDetailError.code : kgDetailLoading ? 'loading' : 'ready'}
            </Tag>
            <Tag color={notificationsTagColor}>notifications: {notificationsTagLabel}</Tag>
          </Space>
        </Space>
      </Card>

      <Card size="small" title="KG review controls">
        <Space direction="vertical" size="middle" style={{ width: '100%' }}>
          <div>
            <Typography.Text type="secondary">status filter</Typography.Text>
            <Space wrap style={{ marginTop: 8 }}>
              {KG_VIEW_OPTIONS.map((option) => (
                <Button
                  key={option.value}
                  data-testid={`knowledge-kg-status-${option.value}`}
                  type={query.kgStatus === option.value ? 'primary' : 'default'}
                  onClick={() =>
                    onPatchQuery({
                      status: option.value,
                      selected: undefined,
                    })
                  }
                >
                  {option.label}
                </Button>
              ))}
            </Space>
          </div>

          <Space wrap>
            <Button data-testid="knowledge-kg-reload" onClick={() => setKgReloadNonce((value) => value + 1)}>
              重新读取 contradiction queue
            </Button>
          </Space>

          <KgActionFeedback state={kgActionState} />
        </Space>
      </Card>

      <QueuePageShell
        queue={
          <Card title={`KG contradictions (${kgQueueItems.length})`} data-testid="knowledge-contradiction-list">
            {kgError ? (
              <Alert
                showIcon
                type={kgError.status >= 500 || kgError.status === 0 ? 'error' : 'warning'}
                data-testid="knowledge-kg-list-error"
                style={{ marginBottom: 16 }}
                message="contradiction queue 读取失败"
                description={
                  <Space direction="vertical" size={8}>
                    <span>{kgError.message}</span>
                    <Typography.Text type="secondary">错误码：{kgError.code}</Typography.Text>
                  </Space>
                }
              />
            ) : null}

            {selectedContradictionNotInList && !kgError ? (
              <Alert
                showIcon
                type="warning"
                data-testid="knowledge-kg-selected-missing"
                style={{ marginBottom: 16 }}
                message="当前选中的 contradiction 不在当前过滤结果里"
                description="可能是因为刚刚 resolve 后状态已变化。详情和通知列表仍会保留当前 selected contradiction。"
              />
            ) : null}

            {kgLoading ? (
              <div style={{ padding: '24px 0' }}>
                <Spin tip="正在读取 KG contradiction queue…" />
              </div>
            ) : null}

            {!kgLoading && kgQueueItems.length === 0 && !kgError ? (
              <div data-testid="knowledge-kg-empty">
                <Empty description="当前过滤条件下没有 contradiction queue items。" />
              </div>
            ) : null}

            {!kgLoading && kgQueueItems.length > 0 ? (
              <List
                dataSource={kgQueueItems}
                renderItem={(item) => {
                  const selected = item.id === selectedContradictionId;
                  return (
                    <List.Item key={item.id} data-testid={`knowledge-kg-row-${item.id}`}>
                      <Card
                        size="small"
                        style={{
                          width: '100%',
                          borderColor: selected ? warmPaperAdmin.palette.accentDark : undefined,
                        }}
                        title={
                          <Space wrap>
                            <Typography.Text code>{item.id}</Typography.Text>
                            <Tag color={contradictionStatusColor(item.status)}>{item.status}</Tag>
                            <Tag color={item.unreadNotificationCount > 0 ? 'gold' : 'default'}>
                              unread {item.unreadNotificationCount}
                            </Tag>
                          </Space>
                        }
                        extra={
                          <Button
                            type={selected ? 'default' : 'primary'}
                            data-testid={`knowledge-open-kg-${item.id}`}
                            onClick={() =>
                              onPatchQuery({
                                selected: item.id,
                              })
                            }
                          >
                            {selected ? '已打开' : '查看详情'}
                          </Button>
                        }
                      >
                        <Descriptions column={1} size="small">
                          <Descriptions.Item label="entityTopic">{item.entityTopic}</Descriptions.Item>
                          <Descriptions.Item label="sourceA / sourceB">
                            {item.sourceABook} / {item.sourceBBook}
                          </Descriptions.Item>
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
            title={selectedContradictionId ? `KG detail · ${selectedContradictionId}` : 'KG detail'}
            extra={
              <Space>
                {selectedContradictionId ? (
                  <Button data-testid="knowledge-close-kg-detail" onClick={() => onPatchQuery({ selected: undefined })}>
                    关闭详情
                  </Button>
                ) : null}
                {selectedContradictionId ? (
                  <Button data-testid="knowledge-reload-kg-detail" onClick={() => setKgReloadNonce((value) => value + 1)}>
                    重试 detail
                  </Button>
                ) : null}
              </Space>
            }
            testId="knowledge-kg-detail"
          >
            {!selectedContradictionId ? (
              <div data-testid="knowledge-kg-detail-placeholder">
                <Empty description="从 contradiction queue 里选择一项后，这里会显示 detail、resolve 区与通知列表。" />
              </div>
            ) : null}

            {selectedContradictionId && kgDetailLoading ? (
              <div data-testid="knowledge-kg-detail-loading" style={{ padding: '24px 0' }}>
                <Spin tip="正在读取 contradiction detail…" />
              </div>
            ) : null}

            {selectedContradictionId && !kgDetailLoading && kgDetailError ? (
              <Alert
                showIcon
                type={kgDetailError.status === 404 ? 'warning' : 'error'}
                data-testid="knowledge-kg-detail-error"
                message={kgDetailError.status === 404 ? 'contradiction detail 不存在' : 'contradiction detail 读取失败'}
                description={
                  <Space direction="vertical" size={8}>
                    <span>{kgDetailError.message}</span>
                    <Typography.Text type="secondary">错误码：{kgDetailError.code}</Typography.Text>
                  </Space>
                }
              />
            ) : null}

            {kgDetail && !kgDetailLoading && !kgDetailError ? (
              <Space direction="vertical" size="middle" style={{ width: '100%' }}>
                <Descriptions column={1} bordered size="small">
                  <Descriptions.Item label="id">
                    <Typography.Text code>{kgDetail.id}</Typography.Text>
                  </Descriptions.Item>
                  <Descriptions.Item label="entityTopic">{kgDetail.entityTopic}</Descriptions.Item>
                  <Descriptions.Item label="status">
                    <Tag data-testid="knowledge-kg-status" color={contradictionStatusColor(kgDetail.status)}>
                      {kgDetail.status}
                    </Tag>
                  </Descriptions.Item>
                  <Descriptions.Item label="sourceA / sourceB">
                    {kgDetail.sourceABook} / {kgDetail.sourceBBook}
                  </Descriptions.Item>
                  <Descriptions.Item label="detectedAt">{formatTimestamp(kgDetail.detectedAt)}</Descriptions.Item>
                  <Descriptions.Item label="reviewedAt">{formatTimestamp(kgDetail.reviewedAt)}</Descriptions.Item>
                  <Descriptions.Item label="resolvedAt">{formatTimestamp(kgDetail.resolvedAt)}</Descriptions.Item>
                  <Descriptions.Item label="notificationCount">{kgDetail.notificationCount}</Descriptions.Item>
                  <Descriptions.Item label="unreadNotificationCount">{kgDetail.unreadNotificationCount}</Descriptions.Item>
                </Descriptions>

                <Card size="small" title="Contradiction detail">
                  <Space direction="vertical" size={8} style={{ width: '100%' }}>
                    <Typography.Paragraph style={{ marginBottom: 0, whiteSpace: 'pre-wrap' }}>
                      {kgDetail.description}
                    </Typography.Paragraph>
                    <Typography.Text type="secondary">agentReviewResult: {kgDetail.agentReviewResult ?? '—'}</Typography.Text>
                  </Space>
                </Card>

                <Card size="small" title="Resolve contradiction">
                  <Space direction="vertical" size="middle" style={{ width: '100%' }}>
                    <Input.TextArea
                      data-testid="knowledge-resolve-notes"
                      rows={4}
                      value={resolveDraft}
                      disabled={!canReview}
                      placeholder="可选：admin notes"
                      onChange={(event) => setResolveDraft(event.target.value)}
                    />
                    <Space wrap>
                      <Button
                        type="primary"
                        data-testid="knowledge-resolve-submit"
                        disabled={!canReview || kgDetail.status === 'resolved'}
                        loading={kgActionState.phase === 'pending' && kgActionState.kind === 'resolve'}
                        onClick={() => void handleResolve()}
                      >
                        标记为已解决
                      </Button>
                      <Tag color={kgDetail.status === 'resolved' ? 'success' : 'default'}>
                        current status: {kgDetail.status}
                      </Tag>
                    </Space>
                  </Space>
                </Card>
              </Space>
            ) : null}

            <Card
              size="small"
              title={`Notifications (${notifications.length})`}
              data-testid="knowledge-notification-list"
              style={{ marginTop: 16 }}
            >
              {notificationsError ? (
                <Alert
                  showIcon
                  type={notificationsError.status >= 500 || notificationsError.status === 0 ? 'error' : 'warning'}
                  data-testid="knowledge-notification-error"
                  style={{ marginBottom: 16 }}
                  message="管理员通知读取失败"
                  description={
                    <Space direction="vertical" size={8}>
                      <span>{notificationsError.message}</span>
                      <Typography.Text type="secondary">错误码：{notificationsError.code}</Typography.Text>
                    </Space>
                  }
                />
              ) : null}

              {selectedContradictionId && notificationsLoading ? (
                <div style={{ padding: '24px 0' }}>
                  <Spin tip="正在读取 notifications…" />
                </div>
              ) : null}

              {!selectedContradictionId ? <Empty description="选择一个 contradiction 后，这里会显示相关管理员通知。" /> : null}

              {selectedContradictionId && !notificationsLoading && notifications.length === 0 && !notificationsError ? (
                <Empty description="当前 contradiction 没有管理员通知。" />
              ) : null}

              {selectedContradictionId && !notificationsLoading && notifications.length > 0 ? (
                <List
                  dataSource={notifications}
                  renderItem={(notification) => (
                    <List.Item key={notification.id} data-testid={`knowledge-notification-row-${notification.id}`}>
                      <Card size="small" style={{ width: '100%' }}>
                        <Space direction="vertical" size={8} style={{ width: '100%' }}>
                          <Space wrap>
                            <Typography.Text code>{notification.id}</Typography.Text>
                            <Tag color={notificationTypeColor(notification.notificationType)}>{notification.notificationType}</Tag>
                            <Tag color={notification.isRead ? 'success' : 'gold'}>
                              {notification.isRead ? 'read' : 'unread'}
                            </Tag>
                          </Space>
                          <Typography.Paragraph style={{ marginBottom: 0, whiteSpace: 'pre-wrap' }}>
                            {notification.message}
                          </Typography.Paragraph>
                          <Space wrap>
                            <Typography.Text type="secondary">createdAt: {formatTimestamp(notification.createdAt)}</Typography.Text>
                            {canReview && !notification.isRead ? (
                              <Button
                                type="primary"
                                size="small"
                                data-testid={`knowledge-notification-read-${notification.id}`}
                                loading={
                                  kgActionState.phase === 'pending' &&
                                  kgActionState.kind === 'mark-read' &&
                                  kgActionState.target === notification.id
                                }
                                onClick={() => void handleMarkNotificationRead(notification.id)}
                              >
                                标记已读
                              </Button>
                            ) : null}
                          </Space>
                        </Space>
                      </Card>
                    </List.Item>
                  )}
                />
              ) : null}
            </Card>
          </DetailContainer>
        }
      />
    </>
  );
}

function KgActionFeedback({ state }: { state: KgActionState }) {
  if (state.phase === 'idle') {
    return null;
  }

  if (state.phase === 'pending') {
    return (
      <Alert
        showIcon
        type="info"
        data-testid="knowledge-kg-feedback"
        message={state.kind === 'resolve' ? '正在 resolve contradiction' : '正在标记通知已读'}
        description={state.target}
      />
    );
  }

  if (state.phase === 'error') {
    const contradictionId = readStringDetail(state.error, 'contradictionId');
    const notificationId = readStringDetail(state.error, 'notificationId');
    return (
      <Alert
        showIcon
        type="error"
        data-testid="knowledge-kg-feedback"
        message={state.kind === 'resolve' ? 'resolve 失败' : '标记已读失败'}
        description={
          <Space direction="vertical" size={4}>
            <span>{state.error.message}</span>
            <Typography.Text type="secondary">错误码：{state.error.code}</Typography.Text>
            {contradictionId ? <Typography.Text type="secondary">contradictionId: {contradictionId}</Typography.Text> : null}
            {notificationId ? <Typography.Text type="secondary">notificationId: {notificationId}</Typography.Text> : null}
          </Space>
        }
      />
    );
  }

  if (state.kind === 'resolve') {
    return (
      <Alert
        showIcon
        type="success"
        data-testid="knowledge-kg-feedback"
        message="contradiction 已解决"
        description={`id=${state.detail.id}; status=${state.detail.status}; resolvedAt=${formatTimestamp(state.detail.resolvedAt)}; adminNotes=${state.detail.adminNotes ?? '—'}`}
      />
    );
  }

  return (
    <Alert
      showIcon
      type="success"
      data-testid="knowledge-kg-feedback"
      message="通知已标记为已读"
      description={`notificationId=${state.notification.id}; isRead=${String(state.notification.isRead)}; createdAt=${formatTimestamp(state.notification.createdAt)}`}
    />
  );
}
