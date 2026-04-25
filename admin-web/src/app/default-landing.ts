import type { AdminIdentity } from '../lib/authClient';
import {
  adminWorkspaceRoutes,
  type AdminWorkspaceRouteDefinition,
} from './routes';
import { isSuperAdmin, resolveAdminRouteAccess, type AdminRouteAccessSnapshot } from './access';

export type DefaultLandingResolution =
  | {
      kind: 'route';
      route: AdminWorkspaceRouteDefinition;
      reason:
        | 'super-admin-overview'
        | 'multi-domain-overview'
        | 'single-domain-route'
        | 'overview-only-route';
    }
  | {
      kind: 'none';
      reason: 'no-accessible-route';
    };

export function resolveDefaultAdminLanding(
  identity: Pick<AdminIdentity, 'roles' | 'permissions'> | null | undefined,
  routes: readonly AdminWorkspaceRouteDefinition[] = adminWorkspaceRoutes,
): DefaultLandingResolution {
  return resolveDefaultAdminLandingFromAccess(identity, resolveAdminRouteAccess(identity, routes));
}

export function resolveDefaultAdminLandingFromAccess(
  identity: Pick<AdminIdentity, 'roles' | 'permissions'> | null | undefined,
  access: AdminRouteAccessSnapshot,
): DefaultLandingResolution {
  const overviewRoute = access.accessibleRoutes.find((route) => route.key === 'overview');

  if (access.accessibleRoutes.length === 0) {
    return {
      kind: 'none',
      reason: 'no-accessible-route',
    };
  }

  if (overviewRoute && isSuperAdmin(identity)) {
    return {
      kind: 'route',
      route: overviewRoute,
      reason: 'super-admin-overview',
    };
  }

  if (overviewRoute && access.domainRoutes.length > 1) {
    return {
      kind: 'route',
      route: overviewRoute,
      reason: 'multi-domain-overview',
    };
  }

  if (access.domainRoutes.length > 0) {
    return {
      kind: 'route',
      route: access.domainRoutes[0],
      reason: 'single-domain-route',
    };
  }

  return {
    kind: 'route',
    route: access.accessibleRoutes[0],
    reason: 'overview-only-route',
  };
}

export function resolvePostLoginPath(
  identity: Pick<AdminIdentity, 'roles' | 'permissions'> | null | undefined,
  returnTo?: string,
): string {
  const safeReturnTo = normalizeReturnPath(returnTo);
  if (safeReturnTo && safeReturnTo !== '/protected') {
    return safeReturnTo;
  }

  const landing = resolveDefaultAdminLanding(identity);
  if (landing.kind === 'route') {
    return landing.route.path;
  }

  return '/protected';
}

function normalizeReturnPath(value: string | undefined): string | undefined {
  if (!value || !value.startsWith('/')) {
    return undefined;
  }
  return value;
}
