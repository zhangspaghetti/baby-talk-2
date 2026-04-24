import { LogoutOutlined, UserOutlined } from '@ant-design/icons';
import { PageContainer, ProLayout } from '@ant-design/pro-components';
import { Button, Space, Tag, Typography } from 'antd';
import { Link } from 'react-router-dom';
import type { DefaultLandingResolution } from '../app/default-landing';
import type { AdminWorkspaceRouteDefinition } from '../app/routes';
import { adminSurfaceStyles, warmPaperAdmin } from '../app/theme';
import type { AdminIdentity, AuthSession } from '../lib/authClient';

type AdminLayoutProps = {
  currentAdmin: AdminIdentity | null;
  session: AuthSession;
  activeRoute: AdminWorkspaceRouteDefinition | null;
  currentPath: string;
  visibleRoutes: readonly AdminWorkspaceRouteDefinition[];
  pageTitle: string;
  pageSubtitle: string;
  landing: DefaultLandingResolution;
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
  session,
  activeRoute,
  currentPath,
  visibleRoutes,
  pageTitle,
  pageSubtitle,
  landing,
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
            <Space size={8} align="center">
              {defaultDom}
              <Typography.Text type="secondary">{currentAdmin?.username ?? 'unknown-admin'}</Typography.Text>
            </Space>
          ),
        }}
        actionsRender={() => [
          <Tag color={warmPaperAdmin.palette.infoSoft} key="current-route" data-testid="header-current-route">
            {currentModuleTitle}
          </Tag>,
          <Button
            key="logout"
            danger
            icon={<LogoutOutlined />}
            loading={loggingOut}
            onClick={onLogout}
            type="primary"
          >
            退出登录
          </Button>,
        ]}
        contentStyle={{ padding: 24 }}
        pageTitleRender={false}
      >
        <PageContainer
          title={pageTitle}
          subTitle={pageSubtitle}
          breadcrumb={{
            items: [
              { title: 'Admin Shell' },
              { title: currentModuleTitle },
            ],
          }}
          content={
            <Typography.Paragraph type="secondary" style={{ marginBottom: 0 }}>
              {renderLandingNote(landing)}
            </Typography.Paragraph>
          }
          extraContent={
            <Space direction="vertical" size={10} style={{ minWidth: 320, maxWidth: 560 }}>
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

              <Space direction="vertical" size={2}>
                <Typography.Text type="secondary">
                  access token expires at: {session.accessTokenExpiresAt}
                </Typography.Text>
                <Typography.Text type="secondary">
                  refresh token expires at: {session.refreshTokenExpiresAt}
                </Typography.Text>
              </Space>
            </Space>
          }
        >
          {children}
        </PageContainer>
      </ProLayout>
    </div>
  );
}

function renderLandingNote(landing: DefaultLandingResolution): string {
  if (landing.kind === 'none') {
    return '当前账号没有可访问模块；shell 会保持 logout/identity 可见，并显式暴露 no-access 状态。';
  }

  switch (landing.reason) {
    case 'super-admin-overview':
      return 'super_admin 默认落到 Overview，避免多模块账号直接跳进某个单工作面。';
    case 'multi-domain-overview':
      return '多域管理员默认落到 Overview；导航与 landing 都复用同一套路由元数据。';
    case 'single-domain-route':
      return `当前账号只暴露单一主工作面，默认直达 ${landing.route.title}。`;
    case 'overview-only-route':
      return `当前账号只有 ${landing.route.title} 可访问，shell 会直接把它作为默认入口。`;
    default:
      return 'shell 继续根据 route catalog 解析默认入口。';
  }
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
