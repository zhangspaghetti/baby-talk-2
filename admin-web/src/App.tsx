import { useEffect, useMemo, useState } from 'react';
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
import {
  ApiError,
  authClient,
  clearStoredSession,
  loadStoredSession,
  persistStoredSession,
  type AdminIdentity,
  type AuthSession,
} from './lib/authClient';

const pageStyle: React.CSSProperties = {
  minHeight: '100vh',
  background: 'linear-gradient(180deg, #f5f3ff 0%, #f8fafc 100%)',
};

const centerStyle: React.CSSProperties = {
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

type SessionChangeHandler = (nextSession: AuthSession | null) => void;

function App() {
  const [session, setSession] = useState<AuthSession | null>(() => loadStoredSession());

  const onSessionChange = (nextSession: AuthSession | null) => {
    setSession(nextSession);
    if (nextSession) {
      persistStoredSession(nextSession);
      return;
    }
    clearStoredSession();
  };

  return (
    <Routes>
      <Route path="/" element={<Navigate to="/protected" replace />} />
      <Route
        path="/login"
        element={<LoginPage session={session} onSessionChange={onSessionChange} />}
      />
      <Route
        path="/protected"
        element={
          <ProtectedRoute session={session}>
            <ProtectedStubPage session={session} onSessionChange={onSessionChange} />
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
  if (!session) {
    return (
      <Navigate
        to="/login"
        replace
        state={{
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

  if (session) {
    return <Navigate to="/protected" replace />;
  }

  const onFinish = async (values: { username: string; password: string }) => {
    setSubmitting(true);
    setError(null);

    try {
      const nextSession = await authClient.login(values.username, values.password);
      onSessionChange(nextSession);
      navigate('/protected', { replace: true });
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
                最小 browser proof：真实登录 admin-api，验证 401 守卫和错误态。
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
              <Form.Item
                label="用户名"
                name="username"
                rules={[{ required: true, message: '请输入用户名。' }]}
              >
                <Input aria-label="用户名" autoComplete="username" placeholder="super_admin" />
              </Form.Item>
              <Form.Item
                label="密码"
                name="password"
                rules={[{ required: true, message: '请输入密码。' }]}
              >
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

function ProtectedStubPage({
  session,
  onSessionChange,
}: {
  session: AuthSession;
  onSessionChange: SessionChangeHandler;
}) {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [loggingOut, setLoggingOut] = useState(false);
  const [me, setMe] = useState<AdminIdentity | null>(session.admin);
  const [error, setError] = useState<ApiError | null>(null);
  const [reloadNonce, setReloadNonce] = useState(0);

  useEffect(() => {
    let cancelled = false;

    const loadMe = async () => {
      setLoading(true);
      setError(null);

      try {
        const currentAdmin = await authClient.me(session.accessToken);
        if (!cancelled) {
          setMe(currentAdmin);
        }
      } catch (requestError) {
        const apiError = toApiError(requestError);
        if (cancelled) {
          return;
        }

        if (apiError.status === 401) {
          onSessionChange(null);
          navigate('/login', {
            replace: true,
            state: {
              banner: {
                type: 'warning',
                message: apiError.message,
                code: apiError.code,
              } satisfies BannerState,
            },
          });
          return;
        }

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
  }, [navigate, onSessionChange, reloadNonce, session.accessToken]);

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
        <div style={{ maxWidth: 960, margin: '0 auto' }}>
          <Card data-testid="protected-shell" style={{ boxShadow: '0 24px 64px rgba(15, 23, 42, 0.08)' }}>
            <Space direction="vertical" size="large" style={{ width: '100%' }}>
              <Space direction="vertical" size={4}>
                <Typography.Title level={2} style={{ marginBottom: 0 }}>
                  Admin Protected Stub
                </Typography.Title>
                <Typography.Paragraph type="secondary" style={{ marginBottom: 0 }}>
                  当前页面用真实 `GET /api/admin/me` 验证 bearer token，而不是只看本地状态。
                </Typography.Paragraph>
              </Space>

              {loading ? (
                <div style={{ padding: '32px 0' }}>
                  <Spin tip="正在验证管理员会话…" />
                </div>
              ) : null}

              {error ? (
                <Alert
                  showIcon
                  type="error"
                  message="管理员会话校验失败"
                  description={
                    <Space direction="vertical" size={8}>
                      <span>{error.message}</span>
                      <Typography.Text type="secondary">错误码：{error.code}</Typography.Text>
                      <div>
                        <Button onClick={() => setReloadNonce((value) => value + 1)}>重试</Button>
                      </div>
                    </Space>
                  }
                />
              ) : null}

              {me && !loading ? (
                <Space direction="vertical" size="middle" style={{ width: '100%' }}>
                  <Card size="small">
                    <Space direction="vertical" size={8}>
                      <Typography.Text strong data-testid="session-user">
                        {me.username}
                      </Typography.Text>
                      <Typography.Text>{me.displayName}</Typography.Text>
                      <Space wrap>
                        {me.roles.map((role) => (
                          <Tag color="purple" key={role} data-testid={role === 'super_admin' ? 'session-role' : undefined}>
                            {role}
                          </Tag>
                        ))}
                      </Space>
                    </Space>
                  </Card>

                  <Card size="small" title="Session Observability">
                    <Space direction="vertical" size={6}>
                      <Typography.Text type="secondary">
                        access token expires at: {session.accessTokenExpiresAt}
                      </Typography.Text>
                      <Typography.Text type="secondary">
                        refresh token expires at: {session.refreshTokenExpiresAt}
                      </Typography.Text>
                    </Space>
                  </Card>
                </Space>
              ) : null}

              <Space>
                <Button type="primary" danger onClick={handleLogout} loading={loggingOut}>
                  退出登录
                </Button>
              </Space>
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

  const candidate = (state as { banner?: Partial<BannerState> }).banner;
  if (!candidate || typeof candidate.message !== 'string') {
    return null;
  }

  return {
    type: normalizeBannerTone(candidate.type),
    message: candidate.message,
    code: typeof candidate.code === 'string' ? candidate.code : undefined,
  };
}

function normalizeBannerTone(value: AlertProps['type']): BannerTone {
  return value === 'success' || value === 'info' || value === 'warning' || value === 'error'
    ? value
    : 'info';
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

export default App;
