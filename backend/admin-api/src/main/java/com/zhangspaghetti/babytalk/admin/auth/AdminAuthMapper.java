package com.zhangspaghetti.babytalk.admin.auth;

import java.time.Instant;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface AdminAuthMapper {

    AdminAuthRepository.AdminPrincipalRow findPrincipalByUsername(@Param("username") String username);

    AdminAuthRepository.AdminPrincipalRow findPrincipalById(@Param("principalId") String principalId);

    void insertPrincipal(@Param("principal") AdminAuthRepository.AdminPrincipalRow principal);

    int insertRoleIfMissing(
            @Param("roleCode") String roleCode,
            @Param("description") String description,
            @Param("createdAt") Instant createdAt
    );

    int grantRole(
            @Param("principalId") String principalId,
            @Param("roleCode") String roleCode,
            @Param("grantedAt") Instant grantedAt
    );

    List<String> findRoleCodes(@Param("principalId") String principalId);

    void insertRefreshToken(@Param("refreshToken") AdminAuthRepository.RefreshTokenRow refreshToken);

    AdminAuthRepository.RefreshTokenRow findRefreshToken(@Param("refreshTokenId") String refreshTokenId);

    AdminAuthRepository.RefreshTokenRow lockRefreshToken(@Param("refreshTokenId") String refreshTokenId);

    int rotateRefreshToken(
            @Param("refreshTokenId") String refreshTokenId,
            @Param("replacementTokenId") String replacementTokenId,
            @Param("rotatedAt") Instant rotatedAt
    );

    int revokeRefreshToken(
            @Param("refreshTokenId") String refreshTokenId,
            @Param("revokedAt") Instant revokedAt
    );

    int expireRefreshToken(
            @Param("refreshTokenId") String refreshTokenId,
            @Param("expiredAt") Instant expiredAt
    );
}
