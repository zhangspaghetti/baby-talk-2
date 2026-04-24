import { Suspense, useCallback, useEffect, useMemo, useState } from 'react';
import type { AlertProps } from 'antd';
import { Alert, Button, Card, Form, Input, Layout, Space, Spin, Typography } from 'antd';
import {
  Navigate,
  Outlet,
  Route,
  Routes,
  useLocation,
  useNavigate,
  useOutletContext,
} from 'react-router-dom';
import { resolveAdminRouteAccess, type AdminRouteAccessSnapshot } from './app/access';
import {
  resolveDefaultAdminLanding,
  resolvePostLoginPath,
  type DefaultLandingResolution,
} from './app/default-landing';
import {
  adminWorkspaceRoutes,
  findAdminWorkspaceRouteByKey,
  findAdminWorkspaceRouteByPath,
  type AdminWorkspaceRouteDefinition,
  type AdminWorkspaceRouteKey,
} from './app/routes';
import { adminSurfaceStyles } from './app/theme';
import AdminLayout from './layout/AdminLayout';
import {
  ApiError,
  authClient,
  clearStoredSession,
  loadStoredSession,
  persistStoredSession,
  type AdminIdentity,
  type AuthSession,
} from './lib/authClient';

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

type ProtectedShellOutletContext = {
  session: AuthSession;
  admin: AdminIdentity;
  onUnauthorized: (error: ApiError) => void;
  routeAccess: AdminRouteAccessSnapshot;
  landing: DefaultLandingResolution;
};

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
        element={
          <ProtectedRoute session={session}>
            <ProtectedShellRoute session={session!} onSessionChange={onSessionChange} />
          </ProtectedRoute>
        }
      >
        <Route path="/protected" element={<ProtectedLandingPage />} />
        {adminWorkspaceRoutes.map((route) => (
          <Route key={route.key} path={route.path} element={<WorkspaceRoute routeKey={route.key} />} />
        ))}
      </Route>
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
    return <Navigate to={resolvePostLoginPath(session.admin, returnTo)} replace />;
  }

  const onFinish = async (values: { username: string; password: string }) => {
    setSubmitting(true);
    setError(null);

    try {
      const nextSession = await authClient.login(values.username, values.password);
      onSessionChange(nextSession);
      navigate(resolvePostLoginPath(nextSession.admin, returnTo), { replace: true });
    } catch (requestError) {
      setError(toApiError(requestError));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Layout style={adminSurfaceStyles.page}>
      <Layout.Content style={adminSurfaceStyles.centeredPage}>
        <Card style={{ ...adminSurfaceStyles.frameCard, width: '100%', maxWidth: 460 }}>
          <Space direction="vertical" size="large" style={{ width: '100%' }}>
            <div>
              <Typography.Title level={2} style={{ marginBottom: 8 }}>
                BabyTalk Admin 登录
              </Typography.Title>
              <Typography.Paragraph type="secondary" style={{ marginBottom: 0 }}>
                当前 shell 会把登录结果直接解析到真实模块路由；导航、默认 landing 与可见性都由 typed route catalog 提供。
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

function ProtectedShellRoute({
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
  const [me, setMe] = useState<AdminIdentity | null>(null);
  const [error, setError] = useState<ApiError | null>(null);
  const [reloadNonce, setReloadNonce] = useState(0);

  const handleSessionReset = useCallback(
    (apiError: ApiError) => {
      onSessionChange(null);
      navigate('/login', {
        replace: true,
        state: {
          returnTo: location.pathname + location.search,
          banner: {
            type: apiError.code === 'invalid_response_payload' ? 'error' : 'warning',
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

        if (shouldResetSessionFromMeError(apiError)) {
          handleSessionReset(normalizeMeResetError(apiError));
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
  }, [handleSessionReset, onSessionChange, reloadNonce, session]);

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

  const chromeIdentity = me ?? session.admin;
  const accessIdentity = error ? null : chromeIdentity;
  const routeAccess = useMemo(() => resolveAdminRouteAccess(accessIdentity), [accessIdentity]);
  const landing = useMemo(() => resolveDefaultAdminLanding(accessIdentity), [accessIdentity]);
  const requestedRoute = useMemo(() => findAdminWorkspaceRouteByPath(location.pathname), [location.pathname]);

  useEffect(() => {
    if (loading || error || location.pathname !== '/protected' || landing.kind !== 'route') {
      return;
    }
    navigate(landing.route.path, { replace: true });
  }, [error, landing, loading, location.pathname, navigate]);

  const pageTitle = requestedRoute?.title ?? readShellTitle(location.pathname, landing, error);
  const pageSubtitle = requestedRoute?.description ?? readShellSubtitle(location.pathname, landing, error);
  const activeRoute = requestedRoute ?? (location.pathname === '/protected' && landing.kind === 'route' ? landing.route : null);

  const shellContext = useMemo<ProtectedShellOutletContext | null>(() => {
    if (!me) {
      return null;
    }
    return {
      session,
      admin: me,
      onUnauthorized: handleSessionReset,
      routeAccess,
      landing,
    };
  }, [handleSessionReset, landing, me, routeAccess, session]);

  let shellBody: React.ReactNode;
  if (loading) {
    shellBody = <ShellLoadingState message="正在解析管理员模块、导航与默认 landing…" />;
  } else if (error) {
    shellBody = <ShellBootstrapErrorState error={error} onRetry={() => setReloadNonce((value) => value + 1)} />;
  } else if (!shellContext) {
    shellBody = <ShellPermissionState requestedRoute={requestedRoute} visibleRoutes={routeAccess.visibleRoutes} />;
  } else {
    shellBody = <Outlet context={shellContext} />;
  }

  return (
    <AdminLayout
      currentAdmin={chromeIdentity}
      session={session}
      activeRoute={activeRoute}
      currentPath={location.pathname}
      visibleRoutes={routeAccess.visibleRoutes}
      pageTitle={pageTitle}
      pageSubtitle={pageSubtitle}
      landing={landing}
      loggingOut={loggingOut}
      onLogout={handleLogout}
    >
      {shellBody}
    </AdminLayout>
  );
}

function ProtectedLandingPage() {
  const { landing, routeAccess } = useOutletContext<ProtectedShellOutletContext>();

  if (landing.kind === 'route') {
    return <ShellLoadingState message={`正在进入 ${landing.route.title}…`} />;
  }

  return <ShellPermissionState visibleRoutes={routeAccess.visibleRoutes} />;
}

function WorkspaceRoute({ routeKey }: { routeKey: AdminWorkspaceRouteKey }) {
  const { admin, onUnauthorized, routeAccess, session } = useOutletContext<ProtectedShellOutletContext>();
  const route = findAdminWorkspaceRouteByKey(routeKey);

  if (!route) {
    return <Navigate to="/protected" replace />;
  }

  const hasRouteAccess = routeAccess.accessibleRoutes.some((candidate) => candidate.key === route.key);
  if (!hasRouteAccess) {
    return <ShellPermissionState requestedRoute={route} visibleRoutes={routeAccess.visibleRoutes} />;
  }

  const ActivePage = route.component;

  return (
    <Suspense fallback={<ShellLoadingState message={`正在加载 ${route.title}…`} />}>
      <ActivePage accessToken={session.accessToken} admin={admin} onUnauthorized={onUnauthorized} />
    </Suspense>
  );
}

function ShellLoadingState({ message }: { message: string }) {
  return (
    <Card style={adminSurfaceStyles.frameCard}>
      <div style={{ padding: '40px 0' }}>
        <Spin tip={message} />
      </div>
    </Card>
  );
}

function ShellBootstrapErrorState({
  error,
  onRetry,
}: {
  error: ApiError;
  onRetry: () => void;
}) {
  return (
    <div data-testid="shell-bootstrap-error">
      <Alert
        showIcon
        type="error"
        message="管理员会话校验失败"
        description={
          <Space direction="vertical" size={8}>
            <span>{error.message}</span>
            <Typography.Text type="secondary">错误码：{error.code}</Typography.Text>
            <div>
              <Button data-testid="retry-me" onClick={onRetry}>
                重试 `/api/admin/me`
              </Button>
            </div>
          </Space>
        }
      />
    </div>
  );
}

function ShellPermissionState({
  requestedRoute,
  visibleRoutes,
}: {
  requestedRoute?: AdminWorkspaceRouteDefinition | null;
  visibleRoutes: readonly AdminWorkspaceRouteDefinition[];
}) {
  const visibleTitles = visibleRoutes.map((route) => route.title);
  const isNoAccess = !requestedRoute;

  return (
    <div data-testid="permission-denied-state">
      <Alert
        showIcon
        type="warning"
        message={
          isNoAccess ? '当前账号没有任何可访问模块' : `当前账号缺少访问 ${requestedRoute.title} 所需权限`
        }
        description={
          <Space direction="vertical" size={8}>
            <span>
              {visibleTitles.length > 0
                ? `仍可访问：${visibleTitles.join(' / ')}。`
                : '当前 shell 会 fail closed，不会因为缺少 identity/permission 数据而暴露全部模块。'}
            </span>
            <Typography.Text type="secondary">
              错误码：{isNoAccess ? 'no_accessible_module' : 'forbidden'}
            </Typography.Text>
          </Space>
        }
      />
    </div>
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

function shouldResetSessionFromMeError(error: ApiError): boolean {
  return error.status === 401 || error.code === 'invalid_response_payload';
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

function normalizeMeResetError(error: ApiError): ApiError {
  if (error.code === 'invalid_response_payload') {
    return new ApiError(401, 'invalid_response_payload', '管理员身份响应异常，已清理本地会话，请重新登录。');
  }
  if (
    error.code === 'request_failed' ||
    error.code === 'invalid_admin_access_token' ||
    error.code === 'unexpected_error'
  ) {
    return new ApiError(401, 'admin_session_invalid', '管理员会话已失效，请重新登录。');
  }
  return error;
}

function readShellTitle(
  pathname: string,
  landing: DefaultLandingResolution,
  error: ApiError | null,
): string {
  if (error) {
    return 'Admin shell bootstrap failed';
  }
  if (pathname === '/protected') {
    return landing.kind === 'route' ? 'Resolving default landing' : 'No accessible module';
  }
  return 'Admin shell';
}

function readShellSubtitle(
  pathname: string,
  landing: DefaultLandingResolution,
  error: ApiError | null,
): string {
  if (error) {
    return ' `/api/admin/me` 失败时 shell 仍保留 logout，并对导航 fail closed。';
  }
  if (pathname === '/protected' && landing.kind === 'route') {
    return `role-aware landing 已解析到 ${landing.route.title}；此别名路由只作为旧入口兼容层。`;
  }
  if (pathname === '/protected') {
    return '当前账号没有真实模块可落点，shell 会显式暴露 no-access 状态。';
  }
  return '左侧导航、当前页标题与默认落点都来自同一套路由元数据。';
}

export default App;
