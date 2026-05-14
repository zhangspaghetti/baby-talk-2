import { describe, expect, it } from 'vitest';
import {
  canAccessAdminRoute,
  hasKnownAdminPermission,
  isSuperAdmin,
  resolveAdminRouteAccess,
  resolveAdminRouteAuthorization,
  sortRoutesByLanding,
} from '../../src/app/access';
import type { AdminWorkspaceRouteDefinition } from '../../src/app/routes';

const routes = [
  createRoute('overview', 100, ['rag:read', 'kg:read']),
  createRoute('users', 80, ['users:read']),
  createRoute('mentor-safety', 60, ['mentor:audit']),
] as const;

const reader = {
  roles: ['operator'],
  permissions: ['users:read', 'unknown:permission', 'users:read'],
};

describe('admin route access', () => {
  it('allows super admins to access every route', () => {
    const identity = { roles: ['super_admin'], permissions: [] };

    expect(routes.every((route) => canAccessAdminRoute(identity, route))).toBe(true);
    expect(isSuperAdmin(identity)).toBe(true);
  });

  it('matches known permissions and reports missing permissions', () => {
    const authorization = resolveAdminRouteAuthorization(reader, routes[0]);

    expect(authorization.allowed).toBe(false);
    expect(authorization.missingPermissions).toEqual(['rag:read', 'kg:read']);
    expect(hasKnownAdminPermission(reader, 'users:read')).toBe(true);
  });

  it('builds visible route snapshots from accessible routes', () => {
    const snapshot = resolveAdminRouteAccess(reader, routes);

    expect(snapshot.accessibleRoutes.map((route) => route.key)).toEqual(['users']);
    expect(snapshot.visibleRoutes.map((route) => route.key)).toEqual(['users']);
    expect(snapshot.permissionCodes).toEqual(['users:read']);
    expect(snapshot.showOverview).toBe(false);
  });

  it('sorts landing routes by weight descending', () => {
    expect(sortRoutesByLanding([routes[2], routes[0], routes[1]]).map((route) => route.key)).toEqual([
      'overview',
      'users',
      'mentor-safety',
    ]);
  });
});

function createRoute(
  key: AdminWorkspaceRouteDefinition['key'],
  defaultLandingWeight: number,
  requiredPermissions: AdminWorkspaceRouteDefinition['requiredPermissions'],
): AdminWorkspaceRouteDefinition {
  return {
    key,
    path: `/${key}`,
    title: key,
    description: key,
    icon: null,
    requiredPermissions,
    navVisibility: 'primary',
    defaultLandingWeight,
    testId: key,
    component: () => null,
  };
}
