import { expect, test } from '@playwright/test';
import { resolveAdminRouteAccess } from '../src/app/access';
import { resolveDefaultAdminLanding } from '../src/app/default-landing';
import {
  ADMIN_FORBIDDEN_PATH,
  ADMIN_LOGIN_PATH,
  adminWorkspaceRoutes,
  buildAdminForbiddenPath,
  buildAdminLoginPath,
  defineAdminWorkspaceRoutes,
  findAdminWorkspaceRouteByKey,
  findAdminWorkspaceRouteByPath,
} from '../src/app/routes';
import type { AdminIdentity } from '../src/lib/authClient';

test.describe('admin access and default landing', () => {
  test('single-domain admins land on their only module and keep overview hidden', () => {
    const identity = makeIdentity({
      roles: ['distribution_reader'],
      permissions: ['distribution:read'],
    });

    const access = resolveAdminRouteAccess(identity);
    const landing = resolveDefaultAdminLanding(identity);

    expect(access.visibleRoutes.map((route) => route.key)).toEqual(['distribution-stats']);
    expect(landing).toMatchObject({
      kind: 'route',
      reason: 'single-domain-route',
      route: { key: 'distribution-stats', path: '/distribution/stats' },
    });
  });

  test('multi-domain admins reuse the same route metadata for overview nav and landing', () => {
    const identity = makeIdentity({
      roles: ['ops_admin'],
      permissions: ['mentor:audit', 'distribution:read'],
    });

    const access = resolveAdminRouteAccess(identity);
    const landing = resolveDefaultAdminLanding(identity);

    expect(access.visibleRoutes.map((route) => route.key)).toEqual([
      'overview',
      'mentor-safety',
      'distribution-stats',
    ]);
    expect(landing).toMatchObject({
      kind: 'route',
      reason: 'multi-domain-overview',
      route: { key: 'overview', path: '/overview' },
    });
  });

  test('empty or unknown permissions fail closed instead of exposing every module', () => {
    const identity = makeIdentity({
      roles: ['limited_admin'],
      permissions: ['unknown:permission'],
    });

    const access = resolveAdminRouteAccess(identity);
    const landing = resolveDefaultAdminLanding(identity);

    expect(access.permissionCodes).toEqual([]);
    expect(access.accessibleRoutes).toEqual([]);
    expect(access.visibleRoutes).toEqual([]);
    expect(landing).toEqual({
      kind: 'none',
      reason: 'no-accessible-route',
    });
  });

  test('login/forbidden helpers only keep path-prefixed context', () => {
    expect(buildAdminLoginPath('/users?tab=all')).toBe(`${ADMIN_LOGIN_PATH}?returnTo=%2Fusers%3Ftab%3Dall`);
    expect(buildAdminLoginPath('https://evil.example')).toBe(ADMIN_LOGIN_PATH);
    expect(
      buildAdminForbiddenPath({
        from: '/mentor/audits?flag=provider_timeout',
        reason: 'missing-permission',
        route: adminWorkspaceRoutes.find((route) => route.key === 'mentor-safety')!,
      }),
    ).toBe(
      `${ADMIN_FORBIDDEN_PATH}?from=%2Fmentor%2Faudits%3Fflag%3Dprovider_timeout&reason=missing-permission&routeKey=mentor-safety&required=mentor%3Aaudit`,
    );
  });

  test('route catalog rejects duplicate landing weights so default landing stays deterministic', () => {
    expect(() =>
      defineAdminWorkspaceRoutes([
        adminWorkspaceRoutes[0],
        {
          ...adminWorkspaceRoutes[1],
          defaultLandingWeight: adminWorkspaceRoutes[0].defaultLandingWeight,
        },
      ]),
    ).toThrow(/defaultLandingWeight/);
  });

  test('unknown route lookups fail safely', () => {
    expect(findAdminWorkspaceRouteByKey('missing-route')).toBeUndefined();
    expect(findAdminWorkspaceRouteByPath('/missing-route')).toBeUndefined();
  });
});

function makeIdentity(overrides: Partial<AdminIdentity> = {}): AdminIdentity {
  return {
    principalId: overrides.principalId ?? 'admin_test',
    username: overrides.username ?? 'admin_test',
    displayName: overrides.displayName ?? 'Admin Test',
    roles: overrides.roles ?? [],
    permissions: overrides.permissions ?? [],
  };
}
