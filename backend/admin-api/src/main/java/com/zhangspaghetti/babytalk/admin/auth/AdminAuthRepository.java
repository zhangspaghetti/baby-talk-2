package com.zhangspaghetti.babytalk.admin.auth;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Repository;

@Repository
public class AdminAuthRepository {

    private final AdminAuthMapper adminAuthMapper;

    public AdminAuthRepository(AdminAuthMapper adminAuthMapper) {
        this.adminAuthMapper = adminAuthMapper;
    }

    public Optional<AdminPrincipalRow> findPrincipalByUsername(String username) {
        return Optional.ofNullable(adminAuthMapper.findPrincipalByUsername(username));
    }

    public Optional<AdminPrincipalRow> findPrincipalById(String principalId) {
        return Optional.ofNullable(adminAuthMapper.findPrincipalById(principalId));
    }

    public void insertPrincipal(AdminPrincipalRow principal) {
        adminAuthMapper.insertPrincipal(principal);
    }

    public void insertRoleIfMissing(String roleCode, String description, Instant createdAt) {
        adminAuthMapper.insertRoleIfMissing(roleCode, description, createdAt);
    }

    public void grantRole(String principalId, String roleCode, Instant grantedAt) {
        adminAuthMapper.grantRole(principalId, roleCode, grantedAt);
    }

    public List<String> findRoleCodes(String principalId) {
        return adminAuthMapper.findRoleCodes(principalId);
    }

    public void insertRefreshToken(RefreshTokenRow refreshToken) {
        adminAuthMapper.insertRefreshToken(refreshToken);
    }

    public Optional<RefreshTokenRow> findRefreshToken(String refreshTokenId) {
        return Optional.ofNullable(adminAuthMapper.findRefreshToken(refreshTokenId));
    }

    public Optional<RefreshTokenRow> findRefreshTokenForUpdate(String refreshTokenId) {
        return Optional.ofNullable(adminAuthMapper.lockRefreshToken(refreshTokenId));
    }

    public int rotateRefreshToken(String refreshTokenId, String replacementTokenId, Instant rotatedAt) {
        return adminAuthMapper.rotateRefreshToken(refreshTokenId, replacementTokenId, rotatedAt);
    }

    public int revokeRefreshToken(String refreshTokenId, Instant revokedAt) {
        return adminAuthMapper.revokeRefreshToken(refreshTokenId, revokedAt);
    }

    public int expireRefreshToken(String refreshTokenId, Instant expiredAt) {
        return adminAuthMapper.expireRefreshToken(refreshTokenId, expiredAt);
    }

    public record AdminPrincipalRow(
            String principalId,
            String username,
            String passwordHash,
            String displayName,
            String status,
            Instant createdAt,
            Instant updatedAt
    ) {
    }

    public record RefreshTokenRow(
            String refreshTokenId,
            String principalId,
            String status,
            Instant issuedAt,
            Instant expiresAt,
            Instant updatedAt,
            Instant rotatedAt,
            Instant revokedAt,
            String replacementTokenId
    ) {
    }
}
