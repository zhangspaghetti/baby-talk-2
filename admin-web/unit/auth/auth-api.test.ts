import { describe, expect, it } from 'vitest';
import {
  ApiError,
  hasPermission,
  parseAdminIdentity,
  parseAuthSession,
  parseLogoutResponse,
  parseStoredSessionPayload,
  sameIdentity,
} from '../../src/auth/auth-api';

const adminPayload = {
  principalId: 'admin-1',
  username: 'super_admin',
  displayName: 'Super Admin',
  roles: ['super_admin'],
  permissions: ['rag:read'],
};

describe('auth-api parsing', () => {
  it('parses cookie-backed login responses with admin identity only', () => {
    expect(parseAuthSession({ admin: adminPayload })).toEqual({ admin: adminPayload });
  });

  it('parses legacy token responses without retaining tokens in AuthSession', () => {
    expect(
      parseAuthSession({
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        tokenType: 'Bearer',
        accessTokenExpiresAt: '2026-01-01T00:00:00Z',
        refreshTokenExpiresAt: '2026-01-02T00:00:00Z',
        admin: adminPayload,
      }),
    ).toEqual({ admin: adminPayload });
  });

  it('allows stored profile cache without permissions', () => {
    const stored = parseStoredSessionPayload({
      admin: {
        principalId: 'admin-1',
        username: 'super_admin',
        displayName: 'Super Admin',
        roles: ['super_admin'],
      },
    });

    expect(stored.admin.permissions).toEqual([]);
  });

  it('rejects malformed admin identities with ApiError', () => {
    expect(() => parseAdminIdentity({ username: 'missing-principal' })).toThrow(ApiError);
  });

  it('parses logout responses', () => {
    expect(parseLogoutResponse({ loggedOut: true, loggedOutAt: '2026-05-13T00:00:00Z' })).toEqual({
      loggedOut: true,
      loggedOutAt: '2026-05-13T00:00:00Z',
    });
  });

  it('rejects invalid string arrays and booleans', () => {
    expect(() => parseAuthSession({ admin: { ...adminPayload, permissions: [42] } })).toThrow(ApiError);
    expect(() => parseLogoutResponse({ loggedOut: 'yes', loggedOutAt: '2026-05-13T00:00:00Z' })).toThrow(ApiError);
  });

  it('checks permission and identity equality helpers', () => {
    expect(hasPermission(adminPayload, 'rag:read')).toBe(true);
    expect(hasPermission(null, 'rag:read')).toBe(false);
    expect(sameIdentity(adminPayload, { ...adminPayload })).toBe(true);
    expect(sameIdentity(adminPayload, { ...adminPayload, permissions: [] })).toBe(false);
  });
});
