import { useCallback, useEffect, useMemo, useState, type CSSProperties } from 'react';
import type { AlertProps } from 'antd';
import {
  Alert,
  Button,
  Card,
  Form,
  Input,
  Layout,
  Space,
  Spin,
  Tag,
  Typography,
} from 'antd';
import { Navigate, Route, Routes, useLocation, useNavigate } from 'react-router-dom';
import MentorAuditPage from './pages/MentorAuditPage';
import {
  ApiError,
  authClient,
  clearStoredSession,
  hasPermission,
  loadStoredSession,
  persistStoredSession,
  type AdminIdentity,
  type AuthSession,
} from './lib/authClient';

const pageStyle: CSSProperties = {
  minHeight: '100vh',
  background: 'linear-gradient(180deg, #f5f3ff 0%, #f8fafc 100%)',
};

const centerStyle: CSSProperties = {
  minHeight: '100vh',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  padding: 24,
};

type BannerTone = NonNullable<AlertProps['type']>;

type BannerState = {
  type: BannerTone;
  message: string;
  code?: string;
};

type RouteState = {
  banner?: Partial<BannerState>;
  returnTo?: string;
};

type SessionChangeHandler = (nextSession: AuthSession | null) => void;

function App() {
  const [session, setSession] = useState<AuthSession | null>(() => loadStoredSession());

  const onSessionChange = useCallback((nextSession: AuthSession | null) => {
    setSession(nextSession);
    if (nextSession) {
      persistStoredSession(nextSession);
      return;
    }
    clearStoredSession();
  }, []);

  return (
    <Routes>
      <Route path="/" element={<Navigate to="/protected" replace />} />
      <Route path="/login" element={<LoginPage session={session} onSessionChange={onSessionChange} />} />
      <Route
        path="/protected"
        element={
          <ProtectedRoute session={session}>
            <ProtectedWorkspace session={session} onSessionChange={onSessionChange} />
          </ProtectedRoute>
        }
      />
      <Route
        path="/mentor/audits"
        element={
          <ProtectedRoute session={session}>
            <ProtectedWorkspace session={session} onSessionChange={onSessionChange} />
          </ProtectedRoute>
        }
      />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

function ProtectedRoute({
  session,
  children,
}: {
  session: AuthSession | null;
  children: React.ReactNode;
}) {
  const location = useLocation();

  if (!session) {
    return (
      <Navigate
        to="/login"
        replace
        state={{
          returnTo: location.pathname + location.search,
          banner: {
            type: 'warning',
            message: '请先登录管理员账号。',
            code: 'admin_authentication_required',
          } satisfies BannerState,
        }}
      />
    );
  }

  return <>{children}</>;
}

function LoginPage({
  session,
  onSessionChange,
}: {
  session: AuthSession | null;
  onSessionChange: SessionChangeHandler;
}) {
  const navigate = useNavigate();
  const location = useLocation();
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<ApiError | null>(null);
  const banner = useMemo(() => readBanner(location.state), [location.state]);
  const returnTo = useMemo(() => readReturnTo(location.state), [location.state]);

  if (session) {
    return <Navigate to={returnTo ?? '/protected'} replace />;
  }

  const onFinish = async (values: { username: string; password: string }) => {
    setSubmitting(true);
    setError(null);

    try {
      const nextSession = await authClient.login(values.username, values.password);
      onSessionChange(nextSession);
      navigate(returnTo ?? '/protected', { replace: true });
    } catch (requestError) {
      setError(toApiError(requestError));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Layout style={pageStyle}>
      <Layout.Content style={centerStyle}>
        <Card
          style={{ width: '100%', maxWidth: 460, boxShadow: '0 24px 64px rgba(91, 33, 182, 0.08)' }}
        >
          <Space direction="vertical" size="large" style={{ width: '100%' }}>
            <div>
              <Typography.Title level={2} style={{ marginBottom: 8 }}>
                BabyTalk Admin 登录
              </Typography.Title>
              <Typography.Paragraph type="secondary" style={{ marginBottom: 0 }}>
                使用真实 admin-api 登录，并在进入受保护页面后刷新 `/api/admin/me` 当前权限。
              </Typography.Paragraph>
            </div>

            {banner ? (
              <div data-testid="login-banner">
                <Alert
                  showIcon
                  type={banner.type}
                  message={banner.message}
                  description={banner.code ? `错误码：${banner.code}` : undefined}
                />
              </div>
            ) : null}

            {error ? (
              <div data-testid="login-error">
                <Alert
                  showIcon
                  type="error"
                  message="登录失败"
                  description={
                    <Space direction="vertical" size={4}>
                      <span>{error.message}</span>
                      <Typography.Text type="secondary">错误码：{error.code}</Typography.Text>
                    </Space>
                  }
                />
              </div>
            ) : null}

            <Form layout="vertical" onFinish={onFinish} initialValues={{ username: 'super_admin' }}>
              <Form.Item label="用户名" name="username" rules={[{ required: true, message: '请输入用户名。' }]}>
                <Input aria-label="用户名" autoComplete="username" placeholder="super_admin" />
              </Form.Item>
              <Form.Item label="密码" name="password" rules={[{ required: true, message: '请输入密码。' }]}>
                <Input.Password
                  aria-label="密码"
                  autoComplete="current-password"
                  placeholder="请输入管理员密码"
                />
              </Form.Item>
              <Button data-testid="login-submit" type="primary" htmlType="submit" loading={submitting} block>
                登录
              </Button>
            </Form>
          </Space>
        </Card>
      </Layout.Content>
    </Layout>
  );
}

function ProtectedWorkspace({
  session,
  onSessionChange,
}: {
  session: AuthSession;
  onSessionChange: SessionChangeHandler;
}) {
  const navigate = useNavigate();
  const location = useLocation();
  const [loading, setLoading] = useState(true);
  const [loggingOut, setLoggingOut] = useState(false);
  const [me, setMe] = useState<AdminIdentity | null>(session.admin);
  const [error, setError] = useState<ApiError | null>(null);
  const [reloadNonce, setReloadNonce] = useState(0);

  const handleUnauthorized = useCallback(
    (apiError: ApiError) => {
      onSessionChange(null);
      navigate('/login', {
        replace: true,
        state: {
          returnTo: location.pathname + location.search,
          banner: {
            type: 'warning',
            message: apiError.message,
            code: apiError.code,
          } satisfies BannerState,
        },
      });
    },
    [location.pathname, location.search, navigate, onSessionChange],
  );

  useEffect(() => {
    let cancelled = false;

    const loadMe = async () => {
      setLoading(true);
      setError(null);

      try {
        const currentAdmin = await authClient.me(session.accessToken);
        if (cancelled) {
          return;
        }

        setMe(currentAdmin);
        if (!sameIdentity(currentAdmin, session.admin)) {
          onSessionChange({
            ...session,
            admin: currentAdmin,
          });
        }
      } catch (requestError) {
        const apiError = toApiError(requestError);
        if (cancelled) {
          return;
        }

        if (apiError.status === 401) {
          handleUnauthorized(normalizeMeUnauthorizedError(apiError));
          return;
        }

        setMe(null);
        setError(apiError);
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    };

    void loadMe();

    return () => {
      cancelled = true;
    };
  }, [handleUnauthorized, onSessionChange, reloadNonce, session]);

  const handleLogout = async () => {
    setLoggingOut(true);
    try {
      await authClient.logout(session.refreshToken);
    } catch {
      // Best-effort logout: local session should still be cleared.
    } finally {
      onSessionChange(null);
      navigate('/login', {
        replace: true,
        state: {
          banner: {
            type: 'success',
            message: '已退出管理员账号。',
          } satisfies BannerState,
        },
      });
      setLoggingOut(false);
    }
  };

  return (
    <Layout style={pageStyle}>
      <Layout.Content style={{ padding: 24 }}>
        <div style={{ maxWidth: 1280, margin: '0 auto' }}>
          <Card data-testid="protected-shell" style={{ boxShadow: '0 24px 64px rgba(15, 23, 42, 0.08)' }}>
            <Space direction="vertical" size="large" style={{ width: '100%' }}>
              <div
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'flex-start',
                  gap: 16,
                  flexWrap: 'wrap',
                }}
              >
                <Space direction="vertical" size={4}>
                  <Typography.Title level={2} style={{ marginBottom: 0 }}>
                    Admin Mentor Audit Workspace
                  </Typography.Title>
                  <Typography.Paragraph type="secondary" style={{ marginBottom: 0 }}>
                    这个 minimal shell 会先刷新 `/api/admin/me`，再决定是否放行 `mentor:audit` 页面；绝不只凭本地 role 猜测。
                  </Typography.Paragraph>
                </Space>
                <Button type="primary" danger onClick={handleLogout} loading={loggingOut}>
                  退出登录
                </Button>
              </div>

              <Card size="small" title="Session observability">
                <Space direction="vertical" size={10} style={{ width: '100%' }}>
                  <Space direction="vertical" size={6}>
                    <Typography.Text strong data-testid="session-user">
                      {me?.username ?? session.admin.username}
                    </Typography.Text>
                    <Typography.Text>{me?.displayName ?? session.admin.displayName}</Typography.Text>
                    <Typography.Text type="secondary">
                      access token expires at: {session.accessTokenExpiresAt}
                    </Typography.Text>
                    <Typography.Text type="secondary">
                      refresh token expires at: {session.refreshTokenExpiresAt}
                    </Typography.Text>
                  </Space>
                  <Space wrap>
                    {(me?.roles ?? session.admin.roles).map((role) => (
                      <Tag color="purple" key={role} data-testid={role === 'super_admin' ? 'session-role' : undefined}>
                        {role}
                      </Tag>
                    ))}
                  </Space>
                  <Space wrap>
                    {(me?.permissions ?? session.admin.permissions).map((permission) => (
                      <Tag
                        color={permission === 'mentor:audit' ? 'success' : 'blue'}
                        key={permission}
                        data-testid={permission === 'mentor:audit' ? 'session-permission' : undefined}
                      >
                        {permission}
                      </Tag>
                    ))}
                  </Space>
                </Space>
              </Card>

              {loading ? (
                <div style={{ padding: '32px 0' }}>
                  <Spin tip="正在刷新管理员身份与 permissions…" />
                </div>
              ) : null}

              {!loading && error ? (
                <Alert
                  showIcon
                  type="error"
                  message="管理员会话校验失败"
                  description={
                    <Space direction="vertical" size={8}>
                      <span>{error.message}</span>
                      <Typography.Text type="secondary">错误码：{error.code}</Typography.Text>
                      <div>
                        <Button data-testid="retry-me" onClick={() => setReloadNonce((value) => value + 1)}>
                          重试 `/api/admin/me`
                        </Button>
                      </div>
                    </Space>
                  }
                />
              ) : null}

              {!loading && !error && me && !hasPermission(me, 'mentor:audit') ? (
                <div data-testid="permission-denied-state">
                  <Alert
                    showIcon
                    type="warning"
                    message="当前账号缺少 mentor:audit 权限"
                    description={
                      <Space direction="vertical" size={8}>
                        <span>浏览器权限守卫已按 backend `permissions` 拒绝访问；请使用带 `mentor:audit` 的管理员账号。</span>
                        <Typography.Text type="secondary">错误码：forbidden</Typography.Text>
                      </Space>
                    }
                  />
                </div>
              ) : null}

              {!loading && !error && me && hasPermission(me, 'mentor:audit') ? (
                <MentorAuditPage accessToken={session.accessToken} admin={me} onUnauthorized={handleUnauthorized} />
              ) : null}
            </Space>
          </Card>
        </div>
      </Layout.Content>
    </Layout>
  );
}

function readBanner(state: unknown): BannerState | null {
  if (!state || typeof state !== 'object' || !('banner' in state)) {
    return null;
  }

  const candidate = (state as RouteState).banner;
  if (!candidate || typeof candidate.message !== 'string') {
    return null;
  }

  return {
    type: normalizeBannerTone(candidate.type),
    message: candidate.message,
    code: typeof candidate.code === 'string' ? candidate.code : undefined,
  };
}

function readReturnTo(state: unknown): string | undefined {
  if (!state || typeof state !== 'object' || !('returnTo' in state)) {
    return undefined;
  }

  const returnTo = (state as RouteState).returnTo;
  return typeof returnTo === 'string' && returnTo.startsWith('/') ? returnTo : undefined;
}

function normalizeBannerTone(value: AlertProps['type']): BannerTone {
  return value === 'success' || value === 'info' || value === 'warning' || value === 'error'
    ? value
    : 'info';
}

function sameIdentity(left: AdminIdentity, right: AdminIdentity): boolean {
  return (
    left.principalId === right.principalId &&
    left.username === right.username &&
    left.displayName === right.displayName &&
    sameStringList(left.roles, right.roles) &&
    sameStringList(left.permissions, right.permissions)
  );
}

function sameStringList(left: string[], right: string[]): boolean {
  return left.length === right.length && left.every((value, index) => value === right[index]);
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

function normalizeMeUnauthorizedError(error: ApiError): ApiError {
  if (
    error.code === 'request_failed' ||
    error.code === 'invalid_admin_access_token' ||
    error.code === 'unexpected_error'
  ) {
    return new ApiError(401, 'admin_session_invalid', '管理员会话已失效，请重新登录。');
  }
  return error;
}

export default App;
