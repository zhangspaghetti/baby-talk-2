import { useMemo, useState } from 'react';
import type { AlertProps } from 'antd';
import { Alert, Button, Card, Form, Input, Layout, Space, Typography } from 'antd';
import { Navigate, useLocation, useNavigate, useSearchParams } from 'react-router-dom';
import { resolvePostLoginPath } from '../app/default-landing';
import { normalizeAdminReturnTo } from '../app/routes';
import { adminSurfaceStyles } from '../app/theme';
import { ApiError, toApiError } from '../auth/auth-api';
import { useAuth } from '../auth/auth-provider';
import type { AuthBannerState } from '../auth/session-store';

type BannerTone = NonNullable<AlertProps['type']>;

type LoginRouteState = {
  banner?: Partial<AuthBannerState>;
  returnTo?: string;
};

export default function LoginPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const [searchParams] = useSearchParams();
  const { banner: sessionBanner, clearBanner, login, session } = useAuth();
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<ApiError | null>(null);
  const locationBanner = useMemo(() => readBanner(location.state), [location.state]);
  const returnTo = useMemo(
    () => normalizeAdminReturnTo(searchParams.get('returnTo')) ?? readReturnTo(location.state),
    [location.state, searchParams],
  );
  const banner = sessionBanner ?? locationBanner;

  if (session) {
    return <Navigate to={resolvePostLoginPath(session.admin, returnTo)} replace />;
  }

  const onFinish = async (values: { username: string; password: string }) => {
    setSubmitting(true);
    setError(null);
    clearBanner();

    try {
      const nextSession = await login(values.username, values.password);
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
        <Card style={{ ...adminSurfaceStyles.frameCard, width: '100%', maxWidth: 480 }}>
          <Space direction="vertical" size="large" style={{ width: '100%' }}>
            <div>
              <Typography.Title level={2} style={{ marginBottom: 8 }}>
                BabyTalk Admin 登录
              </Typography.Title>
            </div>

            {returnTo && returnTo !== '/protected' ? (
              <Typography.Text type="secondary" data-testid="login-return-to">
                登录后将返回：{returnTo}
              </Typography.Text>
            ) : null}

            {banner ? (
              <div data-testid="login-banner">
                <Alert
                  showIcon
                  type={normalizeBannerTone(banner.type)}
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

            <Form layout="vertical" onFinish={onFinish} initialValues={{ username: import.meta.env.DEV ? 'super_admin' : '' }}>
              <Form.Item label="用户名" name="username" rules={[{ required: true, message: '请输入用户名。' }]}>
                <Input size="large" aria-label="用户名" autoComplete="username" placeholder="super_admin" />
              </Form.Item>
              <Form.Item label="密码" name="password" rules={[{ required: true, message: '请输入密码。' }]}>
                <Input.Password
                  size="large"
                  aria-label="密码"
                  autoComplete="current-password"
                  placeholder="请输入管理员密码"
                />
              </Form.Item>
              <Button size="large" data-testid="login-submit" type="primary" htmlType="submit" loading={submitting} block>
                登录
              </Button>
            </Form>
          </Space>
        </Card>
      </Layout.Content>
    </Layout>
  );
}

function readBanner(state: unknown): AuthBannerState | null {
  if (!state || typeof state !== 'object' || !('banner' in state)) {
    return null;
  }

  const candidate = (state as LoginRouteState).banner;
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

  return normalizeAdminReturnTo((state as LoginRouteState).returnTo);
}

function normalizeBannerTone(value: AlertProps['type']): BannerTone {
  return value === 'success' || value === 'info' || value === 'warning' || value === 'error'
    ? value
    : 'info';
}
