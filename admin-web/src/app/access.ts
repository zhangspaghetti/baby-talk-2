import type { AdminIdentity } from '../lib/authClient';
import {
  adminWorkspaceRoutes,
  type AdminRoutePermissionCode,
  type AdminWorkspaceRouteDefinition,
} from './routes';

export type AdminRouteAccessSnapshot = {
  accessibleRoutes: readonly AdminWorkspaceRouteDefinition[];
  visibleRoutes: readonly AdminWorkspaceRouteDefinition[];
  domainRoutes: readonly AdminWorkspaceRouteDefinition[];
  permissionCodes: readonly AdminRoutePermissionCode[];
  showOverview: boolean;
};

export function canAccessAdminRoute(
  identity: Pick<AdminIdentity, 'roles' | 'permissions'> | null | undefined,
  route: AdminWorkspaceRouteDefinition,
): boolean {
  if (!identity) {
    return false;
  }

  if (isSuperAdmin(identity)) {
    return true;
  }

  if (route.requiredPermissions.length === 0) {
    return true;
  }

  const permissionSet = readPermissionSet(identity);
  return route.requiredPermissions.some((permissionCode) => permissionSet.has(permissionCode));
}

export function resolveAdminRouteAccess(
  identity: Pick<AdminIdentity, 'roles' | 'permissions'> | null | undefined,
  routes: readonly AdminWorkspaceRouteDefinition[] = adminWorkspaceRoutes,
): AdminRouteAccessSnapshot {
  const accessibleRoutes = sortRoutesByLanding(routes.filter((route) => canAccessAdminRoute(identity, route)));
  const domainRoutes = accessibleRoutes.filter((route) => route.key !== 'overview');
  const showOverview = shouldShowOverview(identity, domainRoutes);
  const visibleRoutes = accessibleRoutes.filter(
    (route) => route.navVisibility === 'primary' && (route.key !== 'overview' || showOverview),
  );

  return {
    accessibleRoutes,
    visibleRoutes,
    domainRoutes,
    permissionCodes: Array.from(readPermissionSet(identity)).sort(),
    showOverview,
  };
}

export function sortRoutesByLanding(
  routes: readonly AdminWorkspaceRouteDefinition[],
): AdminWorkspaceRouteDefinition[] {
  return [...routes].sort((left, right) => right.defaultLandingWeight - left.defaultLandingWeight);
}

export function isSuperAdmin(identity: Pick<AdminIdentity, 'roles'> | null | undefined): boolean {
  return readStringList(identity?.roles).includes('super_admin');
}

function shouldShowOverview(
  identity: Pick<AdminIdentity, 'roles'> | null | undefined,
  domainRoutes: readonly AdminWorkspaceRouteDefinition[],
): boolean {
  return isSuperAdmin(identity) || domainRoutes.length > 1;
}

function readPermissionSet(
  identity: Pick<AdminIdentity, 'permissions'> | null | undefined,
): Set<AdminRoutePermissionCode> {
  const set = new Set<AdminRoutePermissionCode>();
  for (const permissionCode of readStringList(identity?.permissions)) {
    if (isKnownPermissionCode(permissionCode)) {
      set.add(permissionCode);
    }
  }
  return set;
}

function readStringList(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const seen = new Set<string>();
  const items: string[] = [];

  for (const entry of value) {
    if (typeof entry !== 'string') {
      continue;
    }
    const trimmed = entry.trim();
    if (!trimmed || seen.has(trimmed)) {
      continue;
    }
    seen.add(trimmed);
    items.push(trimmed);
  }

  return items;
}

function isKnownPermissionCode(value: string): value is AdminRoutePermissionCode {
  return adminWorkspaceRoutes.some((route) => route.requiredPermissions.includes(value as AdminRoutePermissionCode));
}
