import type { ComponentType, ReactNode } from 'react';
import {
  BarChartOutlined,
  HomeOutlined,
  ReadOutlined,
  SafetyCertificateOutlined,
  TeamOutlined,
} from '@ant-design/icons';
import type { ApiError, AdminIdentity } from '../lib/authClient';
import DistributionStatsPage from '../pages/DistributionStatsPage';
import KnowledgeOpsPage from '../pages/KnowledgeOpsPage';
import MentorAuditPage from '../pages/MentorAuditPage';
import OverviewPage from '../pages/OverviewPage';
import UsersPage from '../pages/UsersPage';

export const ADMIN_ROUTE_PERMISSION_CODES = [
  'users:read',
  'rag:read',
  'kg:read',
  'mentor:audit',
  'distribution:read',
] as const;

export type AdminRoutePermissionCode = (typeof ADMIN_ROUTE_PERMISSION_CODES)[number];
export type AdminWorkspaceRouteKey =
  | 'overview'
  | 'users'
  | 'knowledge-ops'
  | 'mentor-safety'
  | 'distribution-stats';
export type AdminWorkspaceNavVisibility = 'primary' | 'hidden';

export type AdminRouteComponentProps = {
  accessToken: string;
  admin: AdminIdentity;
  onUnauthorized: (error: ApiError) => void;
};

export type AdminWorkspaceRouteDefinition = {
  key: AdminWorkspaceRouteKey;
  path: `/${string}`;
  title: string;
  description: string;
  icon: ReactNode;
  requiredPermissions: readonly AdminRoutePermissionCode[];
  navVisibility: AdminWorkspaceNavVisibility;
  defaultLandingWeight: number;
  testId: string;
  component: ComponentType<AdminRouteComponentProps>;
};

export const adminWorkspaceRoutes = defineAdminWorkspaceRoutes([
  {
    key: 'overview',
    path: '/overview',
    title: 'Overview',
    description: 'prioritized inbox / 健康信号 / recent activity 的统一入口。',
    icon: <HomeOutlined />,
    requiredPermissions: ['users:read', 'rag:read', 'kg:read', 'mentor:audit', 'distribution:read'],
    navVisibility: 'primary',
    defaultLandingWeight: 100,
    testId: 'workspace-link-overview',
    component: OverviewPage,
  },
  {
    key: 'users',
    path: '/users',
    title: 'Users',
    description: 'consumer account list、detail 与 actions 的占位入口。',
    icon: <TeamOutlined />,
    requiredPermissions: ['users:read'],
    navVisibility: 'primary',
    defaultLandingWeight: 90,
    testId: 'workspace-link-users',
    component: UsersPage,
  },
  {
    key: 'knowledge-ops',
    path: '/knowledge-ops',
    title: 'Knowledge Ops',
    description: 'ingestion queue + KG review 的占位入口。',
    icon: <ReadOutlined />,
    requiredPermissions: ['rag:read', 'kg:read'],
    navVisibility: 'primary',
    defaultLandingWeight: 80,
    testId: 'workspace-link-knowledge-ops',
    component: KnowledgeOpsPage,
  },
  {
    key: 'mentor-safety',
    path: '/mentor/audits',
    title: 'Mentor & Safety',
    description: 'incident-first 审计队列与 rate-limit 上下文。',
    icon: <SafetyCertificateOutlined />,
    requiredPermissions: ['mentor:audit'],
    navVisibility: 'primary',
    defaultLandingWeight: 70,
    testId: 'workspace-link-mentor-audit',
    component: MentorAuditPage,
  },
  {
    key: 'distribution-stats',
    path: '/distribution/stats',
    title: 'Distribution Stats',
    description: 'release/share funnel、trend 与 detail rows。',
    icon: <BarChartOutlined />,
    requiredPermissions: ['distribution:read'],
    navVisibility: 'primary',
    defaultLandingWeight: 60,
    testId: 'workspace-link-distribution-stats',
    component: DistributionStatsPage,
  },
] as const);

export function findAdminWorkspaceRouteByPath(pathname: string): AdminWorkspaceRouteDefinition | undefined {
  return adminWorkspaceRoutes.find((route) => route.path === pathname);
}

function defineAdminWorkspaceRoutes(
  routes: readonly AdminWorkspaceRouteDefinition[],
): readonly AdminWorkspaceRouteDefinition[] {
  const seenKeys = new Set<string>();
  const seenPaths = new Set<string>();

  for (const route of routes) {
    if (!route.key.trim()) {
      throw new Error('admin route key 不能为空。');
    }
    if (!route.path.startsWith('/')) {
      throw new Error(`admin route ${route.key} 的 path 必须是绝对路径。`);
    }
    if (!route.title.trim()) {
      throw new Error(`admin route ${route.key} 缺少 title。`);
    }
    if (!route.icon) {
      throw new Error(`admin route ${route.key} 缺少 icon。`);
    }
    if (!Array.isArray(route.requiredPermissions)) {
      throw new Error(`admin route ${route.key} 缺少 requiredPermissions。`);
    }
    if (route.requiredPermissions.some((permission) => typeof permission !== 'string' || !permission.trim())) {
      throw new Error(`admin route ${route.key} 的 requiredPermissions 含无效值。`);
    }
    if (route.navVisibility !== 'primary' && route.navVisibility !== 'hidden') {
      throw new Error(`admin route ${route.key} 的 navVisibility 不合法。`);
    }
    if (!Number.isFinite(route.defaultLandingWeight)) {
      throw new Error(`admin route ${route.key} 的 defaultLandingWeight 不合法。`);
    }
    if (seenKeys.has(route.key)) {
      throw new Error(`发现重复的 admin route key：${route.key}`);
    }
    if (seenPaths.has(route.path)) {
      throw new Error(`发现重复的 admin route path：${route.path}`);
    }
    seenKeys.add(route.key);
    seenPaths.add(route.path);
  }

  return routes;
}
