import { LogoutOutlined, UserOutlined } from '@ant-design/icons';
import { ProLayout } from '@ant-design/pro-components';
import { Breadcrumb, Button, Collapse, Space, Tag, Typography } from 'antd';
import { Link } from 'react-router-dom';
import type { AdminWorkspaceRouteDefinition } from '../app/routes';
import { adminSurfaceStyles, warmPaperAdmin } from '../app/theme';
import type { AdminIdentity } from '../lib/authClient';

type AdminLayoutProps = {
  currentAdmin: AdminIdentity | null;
  activeRoute: AdminWorkspaceRouteDefinition | null;
  currentPath: string;
  visibleRoutes: readonly AdminWorkspaceRouteDefinition[];
  pageTitle: string;
  pageSubtitle: string;
  loggingOut: boolean;
  onLogout: () => void | Promise<void>;
  children: React.ReactNode;
};

type AdminMenuItem = {
  path: string;
  name: string;
  key: string;
  icon: React.ReactNode;
  testId: string;
};

export default function AdminLayout({
  currentAdmin,
  activeRoute,
  currentPath,
  visibleRoutes,
  pageTitle,
  pageSubtitle,
  loggingOut,
  onLogout,
  children,
}: AdminLayoutProps) {
  const menuData: AdminMenuItem[] = visibleRoutes.map((route) => ({
    path: route.path,
    name: route.title,
    key: route.key,
    icon: route.icon,
    testId: route.testId,
  }));

  const visibleModuleLabels = visibleRoutes.map((route) => route.title);
  const currentModuleTitle = activeRoute?.title ?? pageTitle;

  return (
    <div style={adminSurfaceStyles.page} data-testid="protected-shell">
      <ProLayout
        fixSiderbar
        fixedHeader
        layout="side"
        title="BabyTalk Admin"
        logo={<div style={logoStyle}>BT</div>}
        siderWidth={236}
        location={{ pathname: currentPath }}
        route={{ routes: menuData }}
        menuItemRender={(item, defaultDom) => {
          const menuItem = item as unknown as Partial<AdminMenuItem>;
          if (!menuItem.path) {
            return defaultDom;
          }
          return (
            <Link to={menuItem.path} data-testid={menuItem.testId}>
              {defaultDom}
            </Link>
          );
        }}
        avatarProps={{
          icon: <UserOutlined />,
          title: currentAdmin?.displayName ?? '管理员会话',
          render: (_, defaultDom) => (
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, overflow: 'hidden', minWidth: 0, maxWidth: '100%' }}>
              <div style={{ flexShrink: 0 }}>{defaultDom}</div>
              <Typography.Text
                type="secondary"
                style={{ flex: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', fontSize: 12 }}
              >
                {currentAdmin?.username ?? 'unknown-admin'}
              </Typography.Text>
            </div>
          ),
        }}
        menuFooterRender={() => (
          <div style={{ padding: '8px 12px 16px', display: 'flex', flexDirection: 'column', gap: 8 }}>
            <Tag
              color={warmPaperAdmin.palette.infoSoft}
              data-testid="header-current-route"
              style={{ display: 'block', textAlign: 'center', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
            >
              {currentModuleTitle}
            </Tag>
            <Button
              block
              danger
              icon={<LogoutOutlined />}
              loading={loggingOut}
              onClick={onLogout}
              type="primary"
              size="small"
            >
              退出登录
            </Button>
          </div>
        )}
        contentStyle={{ padding: 24 }}
        pageTitleRender={false}
      >
        <div>
          <Breadcrumb
            style={{ marginBottom: 8 }}
            items={[{ title: 'Admin Shell' }, { title: currentModuleTitle }]}
          />
          <Typography.Title level={4} style={{ margin: '0 0 4px' }}>{pageTitle}</Typography.Title>
          {pageSubtitle && (
            <Typography.Text type="secondary" style={{ display: 'block', marginBottom: 16 }}>
              {pageSubtitle}
            </Typography.Text>
          )}
          {children}
          <Collapse
            defaultActiveKey={['meta']}
            destroyInactivePanel={false}
            style={{ marginTop: 16 }}
            items={[{
              key: 'meta',
              label: '管理员会话详情',
              children: (
                <Space direction="vertical" size={10}>
                  <Space wrap align="center">
                    <Tag color={warmPaperAdmin.palette.info} data-testid="session-user">
                      user: {currentAdmin?.username ?? 'unknown-admin'}
                    </Tag>
                    <Tag data-testid="workspace-current">current: {currentModuleTitle}</Tag>
                    <Tag color={visibleRoutes.length > 0 ? 'success' : 'default'}>
                      visible modules: {visibleRoutes.length}
                    </Tag>
                  </Space>
                  <Space wrap data-testid="workspace-switcher">
                    {visibleModuleLabels.length > 0 ? (
                      visibleModuleLabels.map((label) => (
                        <Tag color={label === currentModuleTitle ? warmPaperAdmin.palette.accentLight : 'default'} key={label}>
                          {label}
                        </Tag>
                      ))
                    ) : (
                      <Tag color="default">no accessible module</Tag>
                    )}
                  </Space>
                  <Space wrap>
                    {(currentAdmin?.roles ?? []).map((role) => (
                      <Tag
                        color={role === 'super_admin' ? warmPaperAdmin.palette.info : 'default'}
                        data-testid={role === 'super_admin' ? 'session-role' : undefined}
                        key={role}
                      >
                        {role}
                      </Tag>
                    ))}
                  </Space>
                  <Space wrap>
                    {(currentAdmin?.permissions ?? []).map((permission) => (
                      <Tag
                        color={permission === 'mentor:audit' ? warmPaperAdmin.palette.info : undefined}
                        data-testid={permission === 'mentor:audit' ? 'session-permission' : undefined}
                        key={permission}
                      >
                        {permission}
                      </Tag>
                    ))}
                  </Space>
                  <Typography.Text type="secondary">session: HttpOnly cookie</Typography.Text>
                </Space>
              ),
            }]}
          />
        </div>
      </ProLayout>
    </div>
  );
}

const logoStyle: React.CSSProperties = {
  width: 32,
  height: 32,
  display: 'inline-flex',
  alignItems: 'center',
  justifyContent: 'center',
  borderRadius: 10,
  background: warmPaperAdmin.palette.accent,
  color: '#fff',
  fontWeight: 700,
  boxShadow: warmPaperAdmin.shadow.sm,
};
