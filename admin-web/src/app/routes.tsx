import { lazy, type ComponentType, type LazyExoticComponent, type ReactNode } from 'react';
import {
  BarChartOutlined,
  HomeOutlined,
  ReadOutlined,
  SafetyCertificateOutlined,
  TeamOutlined,
} from '@ant-design/icons';

export const ADMIN_LOGIN_PATH = '/login';
export const ADMIN_FORBIDDEN_PATH = '/403';
export const ADMIN_PROTECTED_ALIAS_PATH = '/protected';

export const ADMIN_ROUTE_PERMISSION_CODES = [
  'users:read',
  'users:write',
  'admins:read',
  'admins:write',
  'rbac:read',
  'rag:read',
  'rag:write',
  'kg:read',
  'kg:review',
  'mentor:audit',
  'distribution:read',
] as const;

export type AdminRoutePermissionCode = (typeof ADMIN_ROUTE_PERMISSION_CODES)[number];
export type AdminWorkspaceRouteKey =
  | 'overview'
  | 'users'
  | 'admin-accounts'
  | 'knowledge-ops'
  | 'mentor-safety'
  | 'distribution-stats';
export type AdminWorkspaceNavVisibility = 'primary' | 'hidden';
export type AdminForbiddenReason = 'missing-permission' | 'no-accessible-route';

type AdminRouteComponent = ComponentType<Record<string, never>>;
type AdminRouteRenderableComponent = AdminRouteComponent | LazyExoticComponent<AdminRouteComponent>;

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
  component: AdminRouteRenderableComponent;
};

const OverviewPage = lazy(() => import('../pages/OverviewPage'));
const UsersPage = lazy(() => import('../pages/UsersPage'));
const AdminAccountsPage = lazy(() => import('../pages/AdminAccountsPage'));
const KnowledgeOpsPage = lazy(() => import('../pages/KnowledgeOpsPage'));
const MentorAuditPage = lazy(() => import('../pages/MentorAuditPage'));
const DistributionStatsPage = lazy(() => import('../pages/DistributionStatsPage'));

export const adminWorkspaceRoutes = defineAdminWorkspaceRoutes([
  {
    key: 'overview',
    path: '/overview',
    title: 'Overview',
    description: '多域 freshness、transport fallback 与 next-action 的统一 control plane。',
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
    description: 'consumer account list、detail evidence 与 disable action 的真实工作面。',
    icon: <TeamOutlined />,
    requiredPermissions: ['users:read'],
    navVisibility: 'primary',
    defaultLandingWeight: 90,
    testId: 'workspace-link-users',
    component: UsersPage,
  },
  {
    key: 'admin-accounts',
    path: '/users/admins',
    title: 'Admin Accounts',
    description: '隐藏的管理员账号工作面，复用现有 /api/admin/admins + /api/admin/roles contract。',
    icon: <TeamOutlined />,
    requiredPermissions: ['admins:read'],
    navVisibility: 'hidden',
    defaultLandingWeight: 85,
    testId: 'workspace-link-admin-accounts',
    component: AdminAccountsPage,
  },
  {
    key: 'knowledge-ops',
    path: '/knowledge-ops',
    title: 'Knowledge Ops',
    description: 'ingestion queue、upload/retry、KG contradiction review 与通知处理的真实工作面。',
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
    title: 'Mentor Audit',
    description: 'incident-first 审计证据与 live rate-limit 上下文，不是完整 transcript。',
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
    description: 'release/share bounded stats；channel 只作用于 release-side data。',
    icon: <BarChartOutlined />,
    requiredPermissions: ['distribution:read'],
    navVisibility: 'primary',
    defaultLandingWeight: 60,
    testId: 'workspace-link-distribution-stats',
    component: DistributionStatsPage,
  },
] as const);

const routesByPath = new Map(adminWorkspaceRoutes.map((route) => [route.path, route] as const));
const routesByKey = new Map(adminWorkspaceRoutes.map((route) => [route.key, route] as const));

export function findAdminWorkspaceRouteByPath(pathname: string): AdminWorkspaceRouteDefinition | undefined {
  return routesByPath.get(pathname as `/${string}`);
}

export function findAdminWorkspaceRouteByKey(key: string): AdminWorkspaceRouteDefinition | undefined {
  return routesByKey.get(key as AdminWorkspaceRouteKey);
}

export function normalizeAdminReturnTo(value: string | null | undefined): string | undefined {
  if (!value || !value.startsWith('/') || value.startsWith('//')) {
    return undefined;
  }
  return value;
}

export function buildAdminLoginPath(returnTo?: string): string {
  const safeReturnTo = normalizeAdminReturnTo(returnTo);
  if (!safeReturnTo) {
    return ADMIN_LOGIN_PATH;
  }

  const params = new URLSearchParams();
  params.set('returnTo', safeReturnTo);
  return `${ADMIN_LOGIN_PATH}?${params.toString()}`;
}

export function buildAdminForbiddenPath(input: {
  from?: string;
  reason: AdminForbiddenReason;
  route?: AdminWorkspaceRouteDefinition | null;
  requiredPermissions?: readonly AdminRoutePermissionCode[];
}): string {
  const params = new URLSearchParams();
  const from = normalizeAdminReturnTo(input.from);
  const requiredPermissions = input.requiredPermissions ?? input.route?.requiredPermissions ?? [];

  if (from) {
    params.set('from', from);
  }
  params.set('reason', input.reason);
  if (input.route) {
    params.set('routeKey', input.route.key);
  }
  if (requiredPermissions.length > 0) {
    params.set('required', requiredPermissions.join(','));
  }

  const rendered = params.toString();
  return rendered ? `${ADMIN_FORBIDDEN_PATH}?${rendered}` : ADMIN_FORBIDDEN_PATH;
}

export function defineAdminWorkspaceRoutes(
  routes: readonly AdminWorkspaceRouteDefinition[],
): readonly AdminWorkspaceRouteDefinition[] {
  const seenKeys = new Set<string>();
  const seenPaths = new Set<string>();
  const seenLandingWeights = new Map<number, string>();

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
    if (typeof route.testId !== 'string' || !route.testId.trim()) {
      throw new Error(`admin route ${route.key} 缺少 testId。`);
    }
    if (seenKeys.has(route.key)) {
      throw new Error(`发现重复的 admin route key：${route.key}`);
    }
    if (seenPaths.has(route.path)) {
      throw new Error(`发现重复的 admin route path：${route.path}`);
    }
    const duplicateLandingRoute = seenLandingWeights.get(route.defaultLandingWeight);
    if (duplicateLandingRoute) {
      throw new Error(
        `admin route ${route.key} 与 ${duplicateLandingRoute} 使用了重复的 defaultLandingWeight：${route.defaultLandingWeight}`,
      );
    }

    seenKeys.add(route.key);
    seenPaths.add(route.path);
    seenLandingWeights.set(route.defaultLandingWeight, route.key);
  }

  return routes;
}
