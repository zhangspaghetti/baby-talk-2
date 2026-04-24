import { Suspense, useCallback, useEffect, useMemo, useState } from 'react';
import { Alert, Button, Card, Space, Spin, Typography } from 'antd';
import { Navigate, Outlet, Route, Routes, useLocation, useNavigate, useOutletContext } from 'react-router-dom';
import {
  resolveAdminRouteAccess,
  resolveAdminRouteAuthorization,
  type AdminRouteAccessSnapshot,
} from './app/access';
import {
  resolveDefaultAdminLanding,
  type DefaultLandingResolution,
} from './app/default-landing';
import {
  ADMIN_FORBIDDEN_PATH,
  ADMIN_PROTECTED_ALIAS_PATH,
  buildAdminForbiddenPath,
  buildAdminLoginPath,
  findAdminWorkspaceRouteByKey,
  findAdminWorkspaceRouteByPath,
  adminWorkspaceRoutes,
  type AdminWorkspaceRouteDefinition,
  type AdminWorkspaceRouteKey,
} from './app/routes';
import { adminSurfaceStyles } from './app/theme';
import { AuthProvider, useAuth } from './auth/auth-provider';
import { requestCurrentAdmin } from './auth/http-client';
import type { AuthBannerState } from './auth/session-store';
import AdminLayout from './layout/AdminLayout';
import {
  ApiError,
  sameIdentity,
  toApiError,
  type AdminIdentity,
} from './lib/authClient';
import ForbiddenPage from './pages/ForbiddenPage';
import LoginPage from './pages/LoginPage';

type ProtectedShellOutletContext = {
  admin: AdminIdentity;
  routeAccess: AdminRouteAccessSnapshot;
  landing: DefaultLandingResolution;
};

type RouteState = {
  banner?: AuthBannerState;
  returnTo?: string;
};

function App() {
  return (
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>
  );
}

function AppRoutes() {
  return (
    <Routes>
      <Route path="/" element={<Navigate to={ADMIN_PROTECTED_ALIAS_PATH} replace />} />
      <Route path="/login" element={<LoginPage />} />
      <Route
        element={
          <RequireAuth>
            <ProtectedShellRoute />
          </RequireAuth>
        }
      >
        <Route path={ADMIN_PROTECTED_ALIAS_PATH} element={<ProtectedLandingPage />} />
        <Route path={ADMIN_FORBIDDEN_PATH} element={<ForbiddenRoute />} />
        {adminWorkspaceRoutes.map((route) => (
          <Route
            key={route.key}
            path={route.path}
            element={
              <RequireAccess route={route}>
                <WorkspaceRoute routeKey={route.key} />
              </RequireAccess>
            }
          />
        ))}
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

function RequireAuth({ children }: { children: React.ReactNode }) {
  const { session } = useAuth();
  const location = useLocation();

  if (!session) {
    const returnTo = location.pathname + location.search;
    return (
      <Navigate
        to={buildAdminLoginPath(returnTo)}
        replace
        state={{
          returnTo,
          banner: {
            type: 'warning',
            message: '请先登录管理员账号。',
            code: 'admin_authentication_required',
          } satisfies AuthBannerState,
        } satisfies RouteState}
      />
    );
  }

  return <>{children}</>;
}

function RequireAccess({
  route,
  children,
}: {
  route: AdminWorkspaceRouteDefinition;
  children: React.ReactNode;
}) {
  const { admin } = useOutletContext<ProtectedShellOutletContext>();
  const location = useLocation();
  const authorization = useMemo(() => resolveAdminRouteAuthorization(admin, route), [admin, route]);

  if (authorization.allowed) {
    return <>{children}</>;
  }

  return (
    <Navigate
      to={buildAdminForbiddenPath({
        from: location.pathname + location.search,
        reason: 'missing-permission',
        route,
        requiredPermissions:
          authorization.missingPermissions.length > 0 ? authorization.missingPermissions : route.requiredPermissions,
      })}
      replace
    />
  );
}

function ProtectedShellRoute() {
  const { logout, resetSession, session, syncIdentity } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [loading, setLoading] = useState(true);
  const [loggingOut, setLoggingOut] = useState(false);
  const [me, setMe] = useState<AdminIdentity | null>(session?.admin ?? null);
  const [error, setError] = useState<ApiError | null>(null);
  const [reloadNonce, setReloadNonce] = useState(0);

  const handleSessionReset = useCallback(
    (apiError: ApiError) => {
      resetSession(toResetBanner(apiError));
    },
    [resetSession],
  );

  useEffect(() => {
    setMe(session?.admin ?? null);
  }, [session]);

  useEffect(() => {
    if (!session) {
      return;
    }

    let cancelled = false;
    setLoading(true);
    setError(null);

    void requestCurrentAdmin()
      .then((currentAdmin) => {
        if (cancelled) {
          return;
        }

        setMe(currentAdmin);
        if (!sameIdentity(currentAdmin, session.admin)) {
          syncIdentity(currentAdmin);
        }
      })
      .catch((requestError) => {
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
      })
      .finally(() => {
        if (!cancelled) {
          setLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [handleSessionReset, reloadNonce, session, syncIdentity]);

  const chromeIdentity = me ?? session?.admin ?? null;
  const accessIdentity = error ? null : chromeIdentity;
  const routeAccess = useMemo(() => resolveAdminRouteAccess(accessIdentity), [accessIdentity]);
  const landing = useMemo(() => resolveDefaultAdminLanding(accessIdentity), [accessIdentity]);
  const requestedRoute = useMemo(() => findAdminWorkspaceRouteByPath(location.pathname), [location.pathname]);

  useEffect(() => {
    if (loading || error || location.pathname !== ADMIN_PROTECTED_ALIAS_PATH) {
      return;
    }

    if (landing.kind === 'route') {
      navigate(landing.route.path, { replace: true });
      return;
    }

    navigate(
      buildAdminForbiddenPath({
        from: ADMIN_PROTECTED_ALIAS_PATH,
        reason: 'no-accessible-route',
      }),
      { replace: true },
    );
  }, [error, landing, loading, location.pathname, navigate]);

  const handleLogout = async () => {
    setLoggingOut(true);
    try {
      await logout();
    } finally {
      setLoggingOut(false);
    }
  };

  const pageTitle = requestedRoute?.title ?? readShellTitle(location.pathname, landing, error);
  const pageSubtitle = requestedRoute?.description ?? readShellSubtitle(location.pathname, landing, error);
  const activeRoute =
    requestedRoute ??
    (location.pathname === ADMIN_PROTECTED_ALIAS_PATH && landing.kind === 'route' ? landing.route : null);

  const shellContext = useMemo<ProtectedShellOutletContext | null>(() => {
    if (!me) {
      return null;
    }
    return {
      admin: me,
      routeAccess,
      landing,
    };
  }, [landing, me, routeAccess]);

  if (!session) {
    return null;
  }

  let shellBody: React.ReactNode;
  if (loading) {
    shellBody = <ShellLoadingState message="正在校验管理员身份并收敛会话真相源…" />;
  } else if (error) {
    shellBody = <ShellBootstrapErrorState error={error} onRetry={() => setReloadNonce((value) => value + 1)} />;
  } else if (!shellContext) {
    shellBody = <ShellLoadingState message="正在整理管理员身份上下文…" />;
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
  const { landing } = useOutletContext<ProtectedShellOutletContext>();

  if (landing.kind === 'route') {
    return <ShellLoadingState message={`正在进入 ${landing.route.title}…`} />;
  }

  return (
    <Navigate
      to={buildAdminForbiddenPath({
        from: ADMIN_PROTECTED_ALIAS_PATH,
        reason: 'no-accessible-route',
      })}
      replace
    />
  );
}

function ForbiddenRoute() {
  const { admin, landing, routeAccess } = useOutletContext<ProtectedShellOutletContext>();
  return <ForbiddenPage admin={admin} routeAccess={routeAccess} landing={landing} />;
}

function WorkspaceRoute({ routeKey }: { routeKey: AdminWorkspaceRouteKey }) {
  const route = findAdminWorkspaceRouteByKey(routeKey);

  if (!route) {
    return <Navigate to={ADMIN_PROTECTED_ALIAS_PATH} replace />;
  }

  const ActivePage = route.component;

  return (
    <Suspense fallback={<ShellLoadingState message={`正在加载 ${route.title}…`} />}>
      <ActivePage />
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

function shouldResetSessionFromMeError(error: ApiError): boolean {
  return error.status === 401 || error.code === 'invalid_response_payload';
}

function normalizeMeResetError(error: ApiError): ApiError {
  if (error.code === 'invalid_response_payload') {
    return new ApiError(401, 'invalid_response_payload', '管理员身份响应异常，已清理本地会话，请重新登录。');
  }

  return error;
}

function toResetBanner(error: ApiError): AuthBannerState {
  if (error.code === 'invalid_response_payload') {
    return {
      type: 'error',
      message: '管理员身份响应异常，已清理本地会话，请重新登录。',
      code: error.code,
    };
  }

  return {
    type: error.status === 401 ? 'warning' : 'error',
    message: error.message,
    code: error.code,
  };
}

function readShellTitle(
  pathname: string,
  landing: DefaultLandingResolution,
  error: ApiError | null,
): string {
  if (error) {
    return 'Admin shell bootstrap failed';
  }
  if (pathname === ADMIN_FORBIDDEN_PATH) {
    return 'Forbidden';
  }
  if (pathname === ADMIN_PROTECTED_ALIAS_PATH) {
    return landing.kind === 'route' ? 'Resolving default landing' : 'Forbidden';
  }
  return 'Admin shell';
}

function readShellSubtitle(
  pathname: string,
  landing: DefaultLandingResolution,
  error: ApiError | null,
): string {
  if (error) {
    return ' `/api/admin/me` 失败时 shell 会保留显式错误态，而不是静默回退。';
  }
  if (pathname === ADMIN_FORBIDDEN_PATH) {
    return '当前页面显式暴露 authz denial，而不是把缺权限伪装成“请重新登录”。';
  }
  if (pathname === ADMIN_PROTECTED_ALIAS_PATH && landing.kind === 'route') {
    return `role-aware landing 已解析到 ${landing.route.title}；此别名路由只作为旧入口兼容层。`;
  }
  if (pathname === ADMIN_PROTECTED_ALIAS_PATH) {
    return '当前账号没有真实模块可落点，shell 会显式把它送到 /403。';
  }
  return '左侧导航、当前页标题与默认落点都来自同一套路由元数据。';
}

export default App;
