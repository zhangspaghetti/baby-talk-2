import { QueuePageShell } from '../components/workbench/QueuePageShell';
import {
  adminAccountsClient,
  type AdminAccountStatus,
  type AdminAccountView,
  type AdminRoleView,
} from '../lib/adminAccountsClient';
import { ApiError, hasPermission, toApiError } from '../lib/authClient';
import { useAuth } from '../auth/auth-provider';
import { warmPaperAdmin } from '../app/theme';
import {
  Alert,
  Button,
  Card,
  Checkbox,
  Empty,
  Input,
  Space,
  Spin,
  Table,
  Tag,
  Typography,
  type TableColumnsType,
} from 'antd';
import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';

type CreateDraft = {
  username: string;
  displayName: string;
  password: string;
  roleCodes: string[];
};

type CreateMutationState =
  | { phase: 'idle' }
  | { phase: 'pending' }
  | { phase: 'success'; response: AdminAccountView }
  | { phase: 'error'; error: ApiError };

type DisableMutationState =
  | { phase: 'idle' }
  | { phase: 'pending'; principalId: string; previousStatus: AdminAccountStatus }
  | { phase: 'success'; principalId: string; previousStatus: AdminAccountStatus; response: AdminAccountView }
  | { phase: 'error'; principalId: string; previousStatus: AdminAccountStatus; error: ApiError };

const EMPTY_CREATE_DRAFT: CreateDraft = {
  username: '',
  displayName: '',
  password: '',
  roleCodes: [],
};

export default function AdminAccountsPage() {
  const { session } = useAuth();
  const navigate = useNavigate();

  if (!session) {
    throw new Error('AdminAccountsPage requires an active admin session.');
  }

  const admin = session.admin;
  const canWrite = hasPermission(admin, 'admins:write');
  const canReadRoles = hasPermission(admin, 'rbac:read');
  const [roles, setRoles] = useState<AdminRoleView[] | null>(null);
  const [rolesLoading, setRolesLoading] = useState(false);
  const [rolesError, setRolesError] = useState<ApiError | null>(null);
  const [rolesReloadNonce, setRolesReloadNonce] = useState(0);
  const [admins, setAdmins] = useState<AdminAccountView[] | null>(null);
  const [adminsLoading, setAdminsLoading] = useState(false);
  const [adminsError, setAdminsError] = useState<ApiError | null>(null);
  const [adminsReloadNonce, setAdminsReloadNonce] = useState(0);
  const [createDraft, setCreateDraft] = useState<CreateDraft>(EMPTY_CREATE_DRAFT);
  const [createState, setCreateState] = useState<CreateMutationState>({ phase: 'idle' });
  const [disableState, setDisableState] = useState<DisableMutationState>({ phase: 'idle' });

  useEffect(() => {
    let cancelled = false;
    setRolesLoading(true);
    setRolesError(null);

    void adminAccountsClient
      .listRoles()
      .then((nextRoles) => {
        if (cancelled) {
          return;
        }
        setRoles(nextRoles);
      })
      .catch((error) => {
        const apiError = toApiError(error);
        if (cancelled) {
          return;
        }
        setRolesError(apiError);
      })
      .finally(() => {
        if (!cancelled) {
          setRolesLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [rolesReloadNonce]);

  useEffect(() => {
    let cancelled = false;
    setAdminsLoading(true);
    setAdminsError(null);

    void adminAccountsClient
      .listAdmins()
      .then((nextAdmins) => {
        if (cancelled) {
          return;
        }
        setAdmins(nextAdmins);
      })
      .catch((error) => {
        const apiError = toApiError(error);
        if (cancelled) {
          return;
        }
        setAdminsError(apiError);
      })
      .finally(() => {
        if (!cancelled) {
          setAdminsLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [adminsReloadNonce]);

  const adminColumns = useMemo<TableColumnsType<AdminAccountView>>(
    () => [
      {
        title: 'username',
        dataIndex: 'username',
        key: 'username',
        render: (value) => <Typography.Text code>{value}</Typography.Text>,
      },
      {
        title: 'displayName',
        dataIndex: 'displayName',
        key: 'displayName',
      },
      {
        title: 'status',
        dataIndex: 'status',
        key: 'status',
        render: (value) => <Tag color={adminStatusColor(value)}>{value}</Tag>,
      },
      {
        title: 'roles',
        dataIndex: 'roleCodes',
        key: 'roleCodes',
        render: (_, record) =>
          record.roleCodes.length > 0 ? (
            <Space wrap>
              {record.roleCodes.map((roleCode) => (
                <Tag key={`${record.principalId}-${roleCode}`}>{roleCode}</Tag>
              ))}
            </Space>
          ) : (
            '—'
          ),
      },
      {
        title: 'updatedAt',
        dataIndex: 'updatedAt',
        key: 'updatedAt',
        render: (value) => formatTimestamp(value),
      },
      {
        title: 'actions',
        key: 'actions',
        width: 140,
        render: (_, record) => {
          if (!canWrite) {
            return <Typography.Text type="secondary">read only</Typography.Text>;
          }

          const isPending = disableState.phase === 'pending' && disableState.principalId === record.principalId;

          return (
            <Button
              danger
              type={record.status === 'disabled' ? 'text' : 'default'}
              loading={isPending}
              disabled={disableState.phase === 'pending' && disableState.principalId !== record.principalId}
              data-testid={`disable-admin-${record.principalId}`}
              onClick={() => void handleDisable(record)}
            >
              {record.status === 'disabled' ? '已禁用' : '禁用'}
            </Button>
          );
        },
      },
    ],
    [canWrite, disableState],
  );

  const roleColumns = useMemo<TableColumnsType<AdminRoleView>>(
    () => [
      {
        title: 'roleCode',
        dataIndex: 'roleCode',
        key: 'roleCode',
        render: (value) => <Typography.Text code>{value}</Typography.Text>,
      },
      {
        title: 'permissions',
        dataIndex: 'permissionCodes',
        key: 'permissionCodes',
        render: (_, record) =>
          record.permissionCodes.length > 0 ? (
            <Space wrap>
              {record.permissionCodes.map((permissionCode) => (
                <Tag key={`${record.roleCode}-${permissionCode}`}>{permissionCode}</Tag>
              ))}
            </Space>
          ) : (
            '—'
          ),
      },
    ],
    [],
  );

  const createDisabled =
    !canWrite || rolesLoading || rolesError !== null || (roles?.length ?? 0) === 0 || createState.phase === 'pending';
  const roleOptions = roles?.map((role) => ({
    label: `${role.roleCode} · ${role.permissionCodes.join(', ') || 'no permissions'}`,
    value: role.roleCode,
  }));

  async function handleCreate() {
    const validationError = validateCreateDraft(createDraft);
    if (validationError) {
      setCreateState({ phase: 'error', error: validationError });
      return;
    }

    setCreateState({ phase: 'pending' });
    try {
      const createdAdmin = await adminAccountsClient.createAdmin({
        username: createDraft.username.trim(),
        displayName: createDraft.displayName.trim(),
        password: createDraft.password,
        roleCodes: createDraft.roleCodes,
      });
      setAdmins((current) => {
        if (!current) {
          return [createdAdmin];
        }
        return [createdAdmin, ...current.filter((item) => item.principalId !== createdAdmin.principalId)];
      });
      setCreateDraft((current) => ({ ...EMPTY_CREATE_DRAFT, roleCodes: current.roleCodes }));
      setCreateState({ phase: 'success', response: createdAdmin });
      setAdminsReloadNonce((value) => value + 1);
    } catch (error) {
      setCreateState({ phase: 'error', error: toApiError(error) });
    }
  }

  async function handleDisable(record: AdminAccountView) {
    setDisableState({
      phase: 'pending',
      principalId: record.principalId,
      previousStatus: record.status,
    });
    try {
      const disabledAdmin = await adminAccountsClient.disableAdmin(record.principalId);
      setAdmins((current) =>
        current?.map((item) => (item.principalId === disabledAdmin.principalId ? disabledAdmin : item)) ?? current,
      );
      setDisableState({
        phase: 'success',
        principalId: record.principalId,
        previousStatus: record.status,
        response: disabledAdmin,
      });
      setAdminsReloadNonce((value) => value + 1);
    } catch (error) {
      setDisableState({
        phase: 'error',
        principalId: record.principalId,
        previousStatus: record.status,
        error: toApiError(error),
      });
    }
  }

  return (
    <Space direction="vertical" size="large" style={{ width: '100%' }} data-testid="admin-accounts-page">
      <Card size="small" title="Current admin / permission context" data-testid="admin-accounts-context">
        <Space direction="vertical" size={10} style={{ width: '100%' }}>
          <Space wrap>
            <Tag color={warmPaperAdmin.palette.info}>user: {admin.username}</Tag>
            <Tag color={hasPermission(admin, 'admins:read') ? 'success' : 'default'}>
              admins:read {hasPermission(admin, 'admins:read') ? 'enabled' : 'missing'}
            </Tag>
            <Tag color={canWrite ? 'success' : 'default'}>admins:write {canWrite ? 'enabled' : 'missing'}</Tag>
            <Tag color={canReadRoles ? 'success' : 'default'}>rbac:read {canReadRoles ? 'enabled' : 'missing'}</Tag>
            <Tag>roles: {admin.roles.join(', ') || 'none'}</Tag>
          </Space>
          <Space wrap>
            <Tag color={adminsLoading ? 'processing' : adminsError ? 'warning' : 'success'}>
              admins request: {adminsLoading ? 'loading' : adminsError ? adminsError.code : 'ready'}
            </Tag>
            <Tag color={rolesLoading ? 'processing' : rolesError ? 'warning' : 'success'}>
              roles request: {rolesLoading ? 'loading' : rolesError ? rolesError.code : 'ready'}
            </Tag>
            <Tag>admin count: {admins?.length ?? 0}</Tag>
            <Tag>role count: {roles?.length ?? 0}</Tag>
          </Space>
          <Space wrap>
            <Button data-testid="admin-accounts-back-to-users" onClick={() => navigate('/users')}>
              返回 Users workspace
            </Button>
            <Button data-testid="admin-accounts-reload-admins" onClick={() => setAdminsReloadNonce((value) => value + 1)}>
              重新读取 admin list
            </Button>
            <Button data-testid="admin-accounts-reload-roles" onClick={() => setRolesReloadNonce((value) => value + 1)}>
              重新读取 role catalog
            </Button>
          </Space>
        </Space>
      </Card>

      <QueuePageShell
        queue={
          <Card title={`Admins (${admins?.length ?? 0})`} data-testid="admin-accounts-list-card">
            <Space direction="vertical" size="middle" style={{ width: '100%' }}>
              <DisableFeedback state={disableState} />

              {adminsError ? (
                <Alert
                  showIcon
                  type={adminsError.status >= 500 ? 'error' : 'warning'}
                  data-testid="admin-accounts-list-error"
                  message="admin list 读取失败"
                  description={`${adminsError.message}（${adminsError.code}）`}
                />
              ) : null}

              <Table<AdminAccountView>
                size="small"
                rowKey={(record) => record.principalId}
                columns={adminColumns}
                dataSource={admins ?? []}
                loading={adminsLoading}
                pagination={false}
                scroll={{ x: 920 }}
                locale={{
                  emptyText: adminsLoading ? '正在读取 admin list…' : <Empty description="当前没有管理员账号。" />,
                }}
              />
            </Space>
          </Card>
        }
        detail={
          <Space direction="vertical" size="middle" style={{ width: '100%' }}>
            <Card title={`Role catalog (${roles?.length ?? 0})`} data-testid="admin-accounts-roles-card">
              <Space direction="vertical" size="middle" style={{ width: '100%' }}>
                {rolesError ? (
                  <Alert
                    showIcon
                    type={rolesError.status >= 500 ? 'error' : 'warning'}
                    data-testid="admin-accounts-roles-error"
                    message="role catalog 读取失败"
                    description={`${rolesError.message}（${rolesError.code}）`}
                  />
                ) : null}

                <Table<AdminRoleView>
                  size="small"
                  rowKey={(record) => record.roleCode}
                  columns={roleColumns}
                  dataSource={roles ?? []}
                  loading={rolesLoading}
                  pagination={false}
                  scroll={{ x: 620 }}
                  locale={{
                    emptyText: rolesLoading ? '正在读取 role catalog…' : <Empty description="当前没有可选 role。" />,
                  }}
                />
              </Space>
            </Card>

            <Card title="Create admin" data-testid="admin-accounts-create-card">
              <Space direction="vertical" size="middle" style={{ width: '100%' }}>
                {!canWrite ? (
                  <Alert
                    showIcon
                    type="info"
                    data-testid="admin-accounts-readonly-note"
                    message="当前账号只有 admins:read"
                    description="create/disable actions 已在页面内收口；仍可检查现有 admin/role contract 与权限上下文。"
                  />
                ) : null}

                <CreateFeedback state={createState} />

                <Space direction="vertical" size={6} style={{ width: '100%' }}>
                  <Typography.Text type="secondary">username</Typography.Text>
                  <Input
                    value={createDraft.username}
                    disabled={!canWrite}
                    data-testid="admin-create-username"
                    placeholder="例如：admin_browser"
                    onChange={(event) => setCreateDraft((current) => ({ ...current, username: event.target.value }))}
                  />
                </Space>

                <Space direction="vertical" size={6} style={{ width: '100%' }}>
                  <Typography.Text type="secondary">displayName</Typography.Text>
                  <Input
                    value={createDraft.displayName}
                    disabled={!canWrite}
                    data-testid="admin-create-display-name"
                    placeholder="例如：Browser Managed Admin"
                    onChange={(event) => setCreateDraft((current) => ({ ...current, displayName: event.target.value }))}
                  />
                </Space>

                <Space direction="vertical" size={6} style={{ width: '100%' }}>
                  <Typography.Text type="secondary">password</Typography.Text>
                  <Input.Password
                    value={createDraft.password}
                    disabled={!canWrite}
                    data-testid="admin-create-password"
                    placeholder="至少填写一个临时密码"
                    onChange={(event) => setCreateDraft((current) => ({ ...current, password: event.target.value }))}
                  />
                </Space>

                <Space direction="vertical" size={6} style={{ width: '100%' }}>
                  <Typography.Text type="secondary">roleCodes</Typography.Text>
                  <Checkbox.Group
                    value={createDraft.roleCodes}
                    disabled={!canWrite || rolesLoading || (roles?.length ?? 0) === 0}
                    options={roleOptions}
                    onChange={(values) =>
                      setCreateDraft((current) => ({
                        ...current,
                        roleCodes: values.filter((value): value is string => typeof value === 'string'),
                      }))
                    }
                  />
                </Space>

                <Space wrap>
                  <Button data-testid="admin-create-submit" type="primary" disabled={createDisabled} onClick={() => void handleCreate()}>
                    创建管理员
                  </Button>
                  <Button
                    data-testid="admin-create-reset"
                    disabled={createState.phase === 'pending'}
                    onClick={() => {
                      setCreateDraft(EMPTY_CREATE_DRAFT);
                      setCreateState({ phase: 'idle' });
                    }}
                  >
                    清空表单
                  </Button>
                </Space>
              </Space>
            </Card>
          </Space>
        }
      />
    </Space>
  );
}

function CreateFeedback({ state }: { state: CreateMutationState }) {
  if (state.phase === 'idle') {
    return null;
  }

  if (state.phase === 'pending') {
    return <Alert showIcon type="info" data-testid="admin-accounts-create-feedback" message="正在创建管理员" />;
  }

  if (state.phase === 'error') {
    return (
      <Alert
        showIcon
        type="error"
        data-testid="admin-accounts-create-feedback"
        message="创建管理员失败"
        description={`${state.error.message}（${state.error.code}）`}
      />
    );
  }

  return (
    <Alert
      showIcon
      type="success"
      data-testid="admin-accounts-create-feedback"
      message="管理员创建成功"
      description={`principalId=${state.response.principalId}; username=${state.response.username}; status=${state.response.status}`}
    />
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
        data-testid="admin-accounts-disable-feedback"
        message="正在提交管理员禁用"
        description={`principalId=${state.principalId}`}
      />
    );
  }

  if (state.phase === 'error') {
    return (
      <Alert
        showIcon
        type="error"
        data-testid="admin-accounts-disable-feedback"
        message="管理员禁用失败"
        description={`${state.error.message}（${state.error.code}）`}
      />
    );
  }

  const idempotent = state.previousStatus === 'disabled';

  return (
    <Alert
      showIcon
      type={idempotent ? 'warning' : 'success'}
      data-testid="admin-accounts-disable-feedback"
      message={idempotent ? '管理员已处于 disabled 状态' : '管理员已禁用'}
      description={`principalId=${state.response.principalId}; status=${state.response.status}; updatedAt=${formatTimestamp(state.response.updatedAt)}`}
    />
  );
}

function validateCreateDraft(draft: CreateDraft): ApiError | null {
  if (!draft.username.trim()) {
    return new ApiError(400, 'invalid_admin_username', 'username 不能为空。');
  }
  if (!draft.displayName.trim()) {
    return new ApiError(400, 'invalid_admin_display_name', 'displayName 不能为空。');
  }
  if (!draft.password) {
    return new ApiError(400, 'invalid_admin_password', 'password 不能为空。');
  }
  if (draft.roleCodes.length === 0) {
    return new ApiError(400, 'invalid_admin_role_codes', 'roleCodes 不能为空。');
  }
  return null;
}

function adminStatusColor(status: AdminAccountStatus): string {
  return status === 'disabled' ? 'red' : 'success';
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
