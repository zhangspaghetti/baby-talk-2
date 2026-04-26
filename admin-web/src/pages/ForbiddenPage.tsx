import { Alert, Button, Card, Descriptions, Space, Tag, Typography } from 'antd';
import { Link, useSearchParams } from 'react-router-dom';
import type { AdminRouteAccessSnapshot } from '../app/access';
import type { DefaultLandingResolution } from '../app/default-landing';
import {
  ADMIN_PROTECTED_ALIAS_PATH,
  findAdminWorkspaceRouteByKey,
  normalizeAdminReturnTo,
} from '../app/routes';
import { warmPaperAdmin } from '../app/theme';
import type { AdminIdentity } from '../lib/authClient';

type ForbiddenPageProps = {
  admin: AdminIdentity;
  routeAccess: AdminRouteAccessSnapshot;
  landing: DefaultLandingResolution;
};

export default function ForbiddenPage({ admin, routeAccess, landing }: ForbiddenPageProps) {
  const [searchParams] = useSearchParams();
  const routeKey = searchParams.get('routeKey');
  const requestedRoute = routeKey ? findAdminWorkspaceRouteByKey(routeKey) : undefined;
  const reason = searchParams.get('reason') === 'no-accessible-route' ? 'no-accessible-route' : 'missing-permission';
  const requiredPermissions = readRequiredPermissions(searchParams.get('required'));
  const from = normalizeAdminReturnTo(searchParams.get('from'));
  const visibleRouteTitles = routeAccess.visibleRoutes.map((route) => route.title);
  const continuePath =
    landing.kind === 'route' ? landing.route.path : routeAccess.visibleRoutes[0]?.path ?? ADMIN_PROTECTED_ALIAS_PATH;

  return (
    <Space direction="vertical" size="large" style={{ width: '100%' }} data-testid="forbidden-page">
      <div data-testid="forbidden-banner">
        <Alert
          showIcon
          type="warning"
          message={
            reason === 'no-accessible-route'
              ? '当前账号没有任何可访问模块'
              : `当前账号缺少访问 ${requestedRoute?.title ?? '目标模块'} 所需权限`
          }
          description={
            <Space direction="vertical" size={8}>
              <span>
                {reason === 'no-accessible-route'
                  ? 'shell 会 fail closed，不会回退到一个看似成功但其实没有权限的工作面。'
                  : '这里显式落到 /403，而不是再把 RBAC 问题伪装成“重新登录”。'}
              </span>
              <Typography.Text type="secondary">
                user: {admin.username} · roles: {admin.roles.join(', ') || 'none'}
              </Typography.Text>
            </Space>
          }
        />
      </div>

      <Card title="Forbidden context / query diagnostics" size="small">
        <Space direction="vertical" size={10} style={{ width: '100%' }}>
          <Typography.Text code data-testid="forbidden-query">
            {searchParams.toString() || '(empty)'}
          </Typography.Text>
          <Descriptions column={1} size="small" bordered>
            <Descriptions.Item label="from">{from ?? '—'}</Descriptions.Item>
            <Descriptions.Item label="route">{requestedRoute?.title ?? routeKey ?? '—'}</Descriptions.Item>
            <Descriptions.Item label="required permissions">
              {requiredPermissions.length > 0 ? requiredPermissions.join(', ') : '—'}
            </Descriptions.Item>
            <Descriptions.Item label="visible modules">
              {visibleRouteTitles.length > 0 ? visibleRouteTitles.join(' / ') : 'none'}
            </Descriptions.Item>
          </Descriptions>
        </Space>
      </Card>

      <Card title="Current identity / permission codes" size="small">
        <Space direction="vertical" size={12} style={{ width: '100%' }}>
          <Space wrap>
            <Tag color={warmPaperAdmin.palette.info}>user: {admin.username}</Tag>
            <Tag color={warmPaperAdmin.palette.accentDark}>principal: {admin.principalId}</Tag>
            {admin.roles.map((role) => (
              <Tag color={role === 'super_admin' ? warmPaperAdmin.palette.info : 'default'} key={role}>
                {role}
              </Tag>
            ))}
          </Space>
          <Space wrap>
            {admin.permissions.length > 0 ? (
              admin.permissions.map((permission) => (
                <Tag
                  color={requiredPermissions.includes(permission) ? warmPaperAdmin.palette.error : 'default'}
                  key={permission}
                >
                  {permission}
                </Tag>
              ))
            ) : (
              <Tag color="default">no permission code</Tag>
            )}
          </Space>
          <Button data-testid="forbidden-continue" type="primary">
            <Link to={continuePath}>回到可访问工作面</Link>
          </Button>
        </Space>
      </Card>
    </Space>
  );
}

function readRequiredPermissions(value: string | null): string[] {
  if (!value) {
    return [];
  }
  return value
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean);
}
