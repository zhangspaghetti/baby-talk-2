import {
  Alert,
  Button,
  Card,
  Descriptions,
  Empty,
  Space,
  Spin,
  Table,
  Tag,
  Typography,
  type TableColumnsType,
} from 'antd';
import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { warmPaperAdmin } from '../app/theme';
import { useAuth } from '../auth/auth-provider';
import { DetailContainer } from '../components/workbench/DetailContainer';
import { QueuePageShell } from '../components/workbench/QueuePageShell';
import { ReasonRequiredConfirmation } from '../components/workbench/ReasonRequiredConfirmation';
import { ApiError, hasPermission, toApiError } from '../lib/authClient';
import {
  USER_LIST_STATUSES,
  type DisableUserView,
  type UserConsentAuditView,
  type UserDetailView,
  type UserListStatus,
  type UserSessionView,
  type UserSummaryView,
  type UsersListView,
  usersClient,
} from '../lib/usersClient';

const DEFAULT_PAGE = 1;
const DEFAULT_PAGE_SIZE = 20;
const DEFAULT_STATUS: UserListStatus = 'all';
const PAGE_SIZE_OPTIONS = ['10', '20', '50', '100'];
const QUERY_PARAM_KEYS = ['page', 'pageSize', 'status', 'query', 'selected'] as const;

const STATUS_OPTIONS: Array<{ value: UserListStatus; label: string }> = [
  { value: 'all', label: '全部' },
  { value: 'active', label: '活跃' },
  { value: 'deleted', label: '已禁用' },
];

type QueryState = {
  rawPage?: string;
  rawPageSize?: string;
  rawStatus?: string;
  rawQuery?: string;
  selected?: string;
  pageForControls: number;
  pageSizeForControls: number;
  statusDraftValue: UserListStatus;
};

type DisableMutationState =
  | { phase: 'idle' }
  | { phase: 'pending'; accountId: string; reason: string }
  | { phase: 'success'; accountId: string; reason: string; response: DisableUserView }
  | { phase: 'error'; accountId: string; reason: string; error: ApiError };

type UsersQueryPatch = Partial<Record<(typeof QUERY_PARAM_KEYS)[number], string | undefined>>;

export default function UsersPage() {
  const { session } = useAuth();
  if (!session) {
    throw new Error('UsersPage requires an active admin session.');
  }

  const admin = session.admin;
  const canWrite = hasPermission(admin, 'users:write');
  const canManageAdmins = hasPermission(admin, 'admins:read');
  const canWriteAdmins = hasPermission(admin, 'admins:write');
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const query = useMemo(() => readQueryState(searchParams), [searchParams]);
  const [searchDraft, setSearchDraft] = useState(query.rawQuery ?? '');
  const [statusDraft, setStatusDraft] = useState<UserListStatus>(query.statusDraftValue);
  const [listView, setListView] = useState<UsersListView | null>(null);
  const [listLoading, setListLoading] = useState(false);
  const [listError, setListError] = useState<ApiError | null>(null);
  const [listReloadNonce, setListReloadNonce] = useState(0);
  const [detail, setDetail] = useState<UserDetailView | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [detailError, setDetailError] = useState<ApiError | null>(null);
  const [detailReloadNonce, setDetailReloadNonce] = useState(0);
  const [disableModalOpen, setDisableModalOpen] = useState(false);
  const [disableState, setDisableState] = useState<DisableMutationState>({ phase: 'idle' });

  const needsCanonicalQuery = !searchParams.has('page') || !searchParams.has('pageSize') || !searchParams.has('status');
  const contextSummary = searchParams.toString() || `page=${DEFAULT_PAGE}&pageSize=${DEFAULT_PAGE_SIZE}&status=${DEFAULT_STATUS}`;
  const selectedFromQuery = query.selected;
  const selectedAccountId = detail?.account.accountId ?? selectedFromQuery;
  const selectedNotInList =
    selectedFromQuery !== undefined && listView != null && !listView.items.some((item) => item.accountId === selectedFromQuery);

  useEffect(() => {
    if (!needsCanonicalQuery) {
      return;
    }

    const nextParams = new URLSearchParams(searchParams);
    if (!searchParams.has('page')) {
      nextParams.set('page', String(DEFAULT_PAGE));
    }
    if (!searchParams.has('pageSize')) {
      nextParams.set('pageSize', String(DEFAULT_PAGE_SIZE));
    }
    if (!searchParams.has('status')) {
      nextParams.set('status', DEFAULT_STATUS);
    }
    setSearchParams(nextParams, { replace: true });
  }, [needsCanonicalQuery, searchParams, setSearchParams]);

  useEffect(() => {
    setSearchDraft(query.rawQuery ?? '');
    setStatusDraft(query.statusDraftValue);
  }, [query.rawQuery, query.statusDraftValue]);

  useEffect(() => {
    if (needsCanonicalQuery) {
      return;
    }

    let cancelled = false;
    setListLoading(true);
    setListError(null);

    void usersClient
      .listUsers({
        page: query.rawPage,
        pageSize: query.rawPageSize,
        status: query.rawStatus,
        query: query.rawQuery,
      })
      .then((nextList) => {
        if (cancelled) {
          return;
        }
        setListView(nextList);
      })
      .catch((error) => {
        const apiError = toApiError(error);
        if (cancelled) {
          return;
        }
        setListView(null);
        setListError(apiError);
      })
      .finally(() => {
        if (!cancelled) {
          setListLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [detailReloadNonce, listReloadNonce, needsCanonicalQuery, query.rawPage, query.rawPageSize, query.rawQuery, query.rawStatus]);

  useEffect(() => {
    if (selectedFromQuery === undefined) {
      setDetail(null);
      setDetailError(null);
      setDetailLoading(false);
      return;
    }

    let cancelled = false;
    setDetailLoading(true);
    setDetailError(null);
    setDetail(null);

    void usersClient
      .getUser(selectedFromQuery)
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
  }, [detailReloadNonce, selectedFromQuery]);

  const userColumns = useMemo<TableColumnsType<UserSummaryView>>(
    () => [
      {
        title: '手机号',
        dataIndex: 'phoneNumber',
        key: 'phoneNumber',
        render: (_, record) => <Typography.Text code>{record.phoneNumber}</Typography.Text>,
      },
      {
        title: '账号状态',
        dataIndex: 'status',
        key: 'status',
        render: (_, record) => <Tag color={statusColor(record.status)}>{record.status}</Tag>,
      },
      {
        title: 'Consent',
        dataIndex: 'latestConsentStatus',
        key: 'latestConsentStatus',
        render: (_, record) => <Tag color={consentColor(record.latestConsentStatus)}>{record.latestConsentStatus}</Tag>,
      },
      {
        title: '创建时间',
        dataIndex: 'createdAt',
        key: 'createdAt',
        render: (_, record) => formatTimestamp(record.createdAt),
      },
      {
        title: '删除时间',
        dataIndex: 'deletedAt',
        key: 'deletedAt',
        render: (_, record) => formatTimestamp(record.deletedAt),
      },
      {
        title: '操作',
        key: 'actions',
        width: 120,
        render: (_, record) => [
          <Button
            key={`open-${record.accountId}`}
            data-testid={`open-user-${record.accountId}`}
            type={record.accountId === selectedFromQuery ? 'default' : 'primary'}
            onClick={() => openDetail(record.accountId)}
          >
            {record.accountId === selectedFromQuery ? '已打开' : '查看详情'}
          </Button>,
        ],
      },
    ],
    [selectedFromQuery],
  );

  const sessionsColumns = useMemo<TableColumnsType<UserSessionView>>(
    () => [
      {
        title: 'sessionId',
        dataIndex: 'sessionId',
        key: 'sessionId',
        render: (value) => <Typography.Text code>{value}</Typography.Text>,
      },
      {
        title: 'installationId',
        dataIndex: 'installationId',
        key: 'installationId',
      },
      {
        title: 'status',
        dataIndex: 'status',
        key: 'status',
        render: (value) => <Tag color={sessionColor(value)}>{value}</Tag>,
      },
      {
        title: 'createdAt',
        dataIndex: 'createdAt',
        key: 'createdAt',
        render: (value) => formatTimestamp(value),
      },
      {
        title: 'revokedAt',
        dataIndex: 'revokedAt',
        key: 'revokedAt',
        render: (value) => formatTimestamp(value),
      },
    ],
    [],
  );

  const consentColumns = useMemo<TableColumnsType<UserConsentAuditView>>(
    () => [
      {
        title: 'action',
        dataIndex: 'action',
        key: 'action',
        render: (value) => <Tag color={value === 'delete' ? 'red' : 'processing'}>{value}</Tag>,
      },
      {
        title: 'result',
        dataIndex: 'result',
        key: 'result',
        render: (value) => <Tag color={value === 'applied' ? 'success' : 'warning'}>{value}</Tag>,
      },
      {
        title: 'reason',
        dataIndex: 'reason',
        key: 'reason',
        render: (value) => value ?? '—',
      },
      {
        title: 'sessionId',
        dataIndex: 'sessionId',
        key: 'sessionId',
        render: (value) => (value ? <Typography.Text code>{value}</Typography.Text> : '—'),
      },
      {
        title: 'installationId',
        dataIndex: 'installationId',
        key: 'installationId',
        render: (value) => value ?? '—',
      },
      {
        title: 'createdAt',
        dataIndex: 'createdAt',
        key: 'createdAt',
        render: (value) => formatTimestamp(value),
      },
    ],
    [],
  );

  const applyFilters = () => {
    patchQuery(searchParams, setSearchParams, {
      page: String(DEFAULT_PAGE),
      pageSize: String(query.pageSizeForControls),
      status: statusDraft,
      query: normalizeDraft(searchDraft),
      selected: undefined,
    });
  };

  const resetFilters = () => {
    patchQuery(searchParams, setSearchParams, {
      page: String(DEFAULT_PAGE),
      pageSize: String(DEFAULT_PAGE_SIZE),
      status: DEFAULT_STATUS,
      query: undefined,
      selected: undefined,
    });
    setDisableState({ phase: 'idle' });
  };

  const openDetail = (accountId: string) => {
    patchQuery(searchParams, setSearchParams, { selected: accountId });
  };

  const closeDetail = () => {
    patchQuery(searchParams, setSearchParams, { selected: undefined });
    setDisableState({ phase: 'idle' });
  };

  const handleTablePageChange = (page: number, pageSize: number) => {
    patchQuery(searchParams, setSearchParams, {
      page: String(page),
      pageSize: String(pageSize),
    });
  };

  const handleDisableUser = async (reason: string) => {
    const accountId = detail?.account.accountId ?? query.selected;
    if (!accountId) {
      throw new ApiError(400, 'invalid_user_account_id', '当前没有可禁用的账号。');
    }

    setDisableState({ phase: 'pending', accountId, reason });
    try {
      const response = await usersClient.disableUser(accountId, reason);
      setDisableState({ phase: 'success', accountId, reason, response });
      setDisableModalOpen(false);
      setListReloadNonce((value) => value + 1);
      setDetailReloadNonce((value) => value + 1);
    } catch (error) {
      const apiError = toApiError(error);
      setDisableState({ phase: 'error', accountId, reason, error: apiError });
      throw apiError;
    }
  };

  const activeDisableState = selectedAccountId && disableState.phase !== 'idle' && disableState.accountId === selectedAccountId
    ? disableState
    : { phase: 'idle' as const };

  return (
    <Space direction="vertical" size="large" style={{ width: '100%' }} data-testid="users-page">
      <Card size="small" title="Current admin / URL context">
        <Space direction="vertical" size={10} style={{ width: '100%' }}>
          <Space wrap>
            <Tag color={warmPaperAdmin.palette.info}>user: {admin.username}</Tag>
            <Tag color={hasPermission(admin, 'users:read') ? 'success' : 'default'}>
              users:read {hasPermission(admin, 'users:read') ? 'enabled' : 'missing'}
            </Tag>
            <Tag color={canWrite ? 'success' : 'default'}>users:write {canWrite ? 'enabled' : 'missing'}</Tag>
            <Tag color={canManageAdmins ? 'success' : 'default'}>
              admins:read {canManageAdmins ? 'enabled' : 'missing'}
            </Tag>
            <Tag color={canWriteAdmins ? 'success' : 'default'}>
              admins:write {canWriteAdmins ? 'enabled' : 'missing'}
            </Tag>
            <Tag>roles: {admin.roles.join(', ') || 'none'}</Tag>
            <Tag>session: HttpOnly cookie</Tag>
          </Space>
          <Space wrap>
            <Tag>page: {query.rawPage ?? DEFAULT_PAGE}</Tag>
            <Tag>pageSize: {query.rawPageSize ?? DEFAULT_PAGE_SIZE}</Tag>
            <Tag color={isKnownStatus(query.rawStatus) ? 'processing' : query.rawStatus === undefined ? 'processing' : 'warning'}>
              status: {query.rawStatus ?? DEFAULT_STATUS}
            </Tag>
            <Tag color={query.rawQuery ? 'processing' : 'default'}>query: {query.rawQuery || 'none'}</Tag>
            <Tag color={query.selected !== undefined ? 'warning' : 'default'}>selected: {query.selected ?? 'none'}</Tag>
          </Space>
          <Space wrap>
            {canManageAdmins ? (
              <Button data-testid="users-open-admin-accounts" onClick={() => navigate('/users/admins')}>
                打开管理员管理
              </Button>
            ) : null}
          </Space>
          <Typography.Text code data-testid="users-context-query">
            {contextSummary}
          </Typography.Text>
        </Space>
      </Card>

      <Card size="small" title="Users filters">
        <Space direction="vertical" size="middle" style={{ width: '100%' }}>
          <div>
            <Typography.Text type="secondary">status</Typography.Text>
            <Space wrap style={{ marginTop: 8 }}>
              {STATUS_OPTIONS.map((option) => (
                <Button
                  key={option.value}
                  data-testid={`users-status-option-${option.value}`}
                  type={statusDraft === option.value ? 'primary' : 'default'}
                  onClick={() => setStatusDraft(option.value)}
                >
                  {option.label}
                </Button>
              ))}
            </Space>
          </div>

          <div>
            <Typography.Text type="secondary">query</Typography.Text>
            <input
              aria-label="users query filter"
              data-testid="users-search-input"
              placeholder="手机号或 accountId"
              style={searchInputStyle}
              value={searchDraft}
              onChange={(event) => setSearchDraft(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === 'Enter') {
                  applyFilters();
                }
              }}
            />
          </div>

          <Space wrap>
            <Button data-testid="users-apply-filters" type="primary" onClick={applyFilters}>
              应用过滤
            </Button>
            <Button data-testid="users-reset-filters" onClick={resetFilters}>
              重置为默认
            </Button>
            <Button data-testid="users-reload-list" onClick={() => setListReloadNonce((value) => value + 1)}>
              重新读取列表
            </Button>
          </Space>
        </Space>
      </Card>

      <QueuePageShell
        queue={
          <Card title={`Accounts (${listView?.items.length ?? 0}/${listView?.total ?? 0})`} data-testid="users-list-card">
            {listError ? (
              <div data-testid="users-list-error-state" style={{ marginBottom: 16 }}>
                <Alert
                  showIcon
                  type={listError.status >= 500 ? 'error' : 'warning'}
                  message="users list 读取失败"
                  description={
                    <Space direction="vertical" size={8}>
                      <span>{listError.message}</span>
                      <Typography.Text type="secondary">错误码：{listError.code}</Typography.Text>
                      <Button onClick={() => setListReloadNonce((value) => value + 1)}>重试 list</Button>
                    </Space>
                  }
                />
              </div>
            ) : null}

            {selectedNotInList && !listError ? (
              <Alert
                showIcon
                type="warning"
                data-testid="users-selected-missing"
                style={{ marginBottom: 16 }}
                message="当前选中账号不在当前列表页"
                description="它可能已经被当前过滤条件排除，或者刚刚被禁用。详情面仍会保留当前账号上下文。"
              />
            ) : null}

            <div data-testid="users-list-table">
              <Table<UserSummaryView>
                columns={userColumns}
                dataSource={listView?.items ?? []}
                loading={listLoading}
                rowKey="accountId"
                pagination={{
                  current: listView?.page ?? query.pageForControls,
                  pageSize: listView?.pageSize ?? query.pageSizeForControls,
                  total: listView?.total ?? 0,
                  showSizeChanger: true,
                  pageSizeOptions: PAGE_SIZE_OPTIONS,
                  onChange: handleTablePageChange,
                }}
                locale={{
                  emptyText: listLoading ? '正在读取 users list…' : '当前过滤条件下没有账号。',
                }}
                onRow={(record) => ({
                  onClick: () => openDetail(record.accountId),
                  style: {
                    cursor: 'pointer',
                    background:
                      record.accountId === selectedFromQuery ? warmPaperAdmin.palette.infoSoft : undefined,
                  },
                })}
              />
            </div>
          </Card>
        }
        detail={
          <DetailContainer
            title={selectedAccountId ? `Account detail · ${selectedAccountId}` : 'Account detail'}
            extra={
              <Space>
                {selectedAccountId ? (
                  <Button data-testid="users-reload-detail" onClick={() => setDetailReloadNonce((value) => value + 1)}>
                    重试 detail
                  </Button>
                ) : null}
                {selectedAccountId ? (
                  <Button data-testid="users-close-detail" onClick={closeDetail}>
                    关闭详情
                  </Button>
                ) : null}
                {selectedAccountId && canWrite && detail?.account.status !== 'deleted' ? (
                  <Button danger type="primary" data-testid="disable-user-button" onClick={() => setDisableModalOpen(true)}>
                    禁用账号
                  </Button>
                ) : null}
              </Space>
            }
            testId="users-detail"
          >
            {!selectedAccountId ? (
              <div data-testid="users-detail-placeholder">
                <Empty description="从列表选择一个账号后，这里会显示 summary / sessions / consent audit。" />
              </div>
            ) : null}

            {selectedAccountId && detailLoading ? (
              <div style={{ padding: '24px 0' }} data-testid="users-detail-loading">
                <Spin tip="正在读取用户详情…" />
              </div>
            ) : null}

            {selectedAccountId && !detailLoading && detailError ? (
              <div data-testid="users-detail-error-state">
                <Alert
                  showIcon
                  type={detailError.status >= 500 ? 'error' : 'warning'}
                  message="用户详情读取失败"
                  description={
                    <Space direction="vertical" size={8}>
                      <span>{detailError.message}</span>
                      <Typography.Text type="secondary">错误码：{detailError.code}</Typography.Text>
                    </Space>
                  }
                />
              </div>
            ) : null}

            {detail && !detailLoading && !detailError ? (
              <Space direction="vertical" size="middle" style={{ width: '100%' }}>
                <DisableFeedback state={activeDisableState} />

                <Descriptions column={1} size="small" bordered data-testid="users-summary-card">
                  <Descriptions.Item label="accountId">
                    <Typography.Text code>{detail.account.accountId}</Typography.Text>
                  </Descriptions.Item>
                  <Descriptions.Item label="phoneNumber">
                    <Typography.Text code>{detail.account.phoneNumber}</Typography.Text>
                  </Descriptions.Item>
                  <Descriptions.Item label="status">
                    <Tag data-testid="users-detail-status" color={statusColor(detail.account.status)}>
                      {detail.account.status}
                    </Tag>
                  </Descriptions.Item>
                  <Descriptions.Item label="latestConsentStatus">
                    <Tag color={consentColor(detail.account.latestConsentStatus)}>{detail.account.latestConsentStatus}</Tag>
                  </Descriptions.Item>
                  <Descriptions.Item label="createdAt">{formatTimestamp(detail.account.createdAt)}</Descriptions.Item>
                  <Descriptions.Item label="deletedAt">{formatTimestamp(detail.account.deletedAt)}</Descriptions.Item>
                </Descriptions>

                <Card size="small" title={`Recent sessions (${detail.recentSessions.length})`} data-testid="users-sessions-card">
                  <Table<UserSessionView>
                    size="small"
                    columns={sessionsColumns}
                    dataSource={detail.recentSessions}
                    rowKey={(row) => row.sessionId}
                    pagination={false}
                    scroll={{ x: 760 }}
                    locale={{ emptyText: '当前账号没有 session history。' }}
                  />
                </Card>

                <Card
                  size="small"
                  title={`Consent audit (${detail.recentConsentAudit.length})`}
                  data-testid="users-consent-card"
                >
                  <Table<UserConsentAuditView>
                    size="small"
                    columns={consentColumns}
                    dataSource={detail.recentConsentAudit}
                    rowKey={(row) => row.auditId}
                    pagination={false}
                    scroll={{ x: 860 }}
                    locale={{ emptyText: '当前账号没有 consent audit history。' }}
                  />
                </Card>
              </Space>
            ) : null}
          </DetailContainer>
        }
      />

      <ReasonRequiredConfirmation
        open={disableModalOpen}
        title="确认禁用账号"
        subject={detail ? `accountId=${detail.account.accountId} · ${detail.account.phoneNumber}` : '当前选中账号'}
        description="必须填写 reason；提交后会调用 /api/admin/users/{accountId}/disable，并保留 applied / duplicate / backend code 供排查。"
        confirmText="确认禁用"
        onCancel={() => setDisableModalOpen(false)}
        onConfirm={handleDisableUser}
      />
    </Space>
  );
}

function DisableFeedback({ state }: { state: DisableMutationState }) {
  if (state.phase === 'idle') {
    return null;
  }

  if (state.phase === 'pending') {
    return (
      <Alert
        showIcon
        type="info"
        data-testid="users-disable-feedback"
        message="正在提交禁用"
        description={`reason=${state.reason}`}
      />
    );
  }

  if (state.phase === 'error') {
    return (
      <Alert
        showIcon
        type="error"
        data-testid="users-disable-feedback"
        message="禁用失败"
        description={`${state.error.message}（${state.error.code}）`}
      />
    );
  }

  return (
    <Alert
      showIcon
      type={state.response.applied ? 'success' : 'warning'}
      data-testid="users-disable-feedback"
      message={state.response.applied ? '禁用已应用' : '禁用重复提交'}
      description={`result=${state.response.result}; updatedAt=${formatTimestamp(state.response.updatedAt)}; revokedSessions=${state.response.revokedSessionCount}; deletedEvents=${state.response.deletedEventCount}`}
    />
  );
}

function readQueryState(searchParams: URLSearchParams): QueryState {
  const rawPage = readRawQueryValue(searchParams.get('page'));
  const rawPageSize = readRawQueryValue(searchParams.get('pageSize'));
  const rawStatus = readRawQueryValue(searchParams.get('status'));

  return {
    rawPage,
    rawPageSize,
    rawStatus,
    rawQuery: readRawQueryValue(searchParams.get('query')),
    selected: readRawQueryValue(searchParams.get('selected')),
    pageForControls: parsePositiveInt(rawPage) ?? DEFAULT_PAGE,
    pageSizeForControls: parsePositiveInt(rawPageSize) ?? DEFAULT_PAGE_SIZE,
    statusDraftValue: isKnownStatus(rawStatus) ? rawStatus : DEFAULT_STATUS,
  };
}

function readRawQueryValue(value: string | null): string | undefined {
  return value === null ? undefined : value;
}

function patchQuery(
  currentSearchParams: URLSearchParams,
  setSearchParams: ReturnType<typeof useSearchParams>[1],
  patch: UsersQueryPatch,
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

function normalizeDraft(value: string): string | undefined {
  const trimmed = value.trim();
  return trimmed ? trimmed : undefined;
}

function parsePositiveInt(value: string | undefined): number | undefined {
  if (value == null || !/^\d+$/.test(value)) {
    return undefined;
  }
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : undefined;
}

function isKnownStatus(value: string | undefined): value is UserListStatus {
  return value != null && (USER_LIST_STATUSES as readonly string[]).includes(value);
}

function statusColor(status: string): string {
  return status === 'deleted' ? 'red' : 'success';
}

function consentColor(status: string): string {
  switch (status) {
    case 'accepted':
      return 'success';
    case 'revoked':
      return 'warning';
    case 'deleted':
      return 'red';
    default:
      return 'default';
  }
}

function sessionColor(status: string): string {
  switch (status) {
    case 'active':
      return 'success';
    case 'deleted':
      return 'red';
    default:
      return 'warning';
  }
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

const searchInputStyle: React.CSSProperties = {
  width: '100%',
  maxWidth: 360,
  borderRadius: 8,
  border: '1px solid #d9d9d9',
  padding: '8px 12px',
  marginTop: 8,
};
