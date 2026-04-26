package com.zhangspaghetti.babytalk.admin.auth;

import com.zhangspaghetti.babytalk.admin.rbac.AdminPermissionCatalog;
import com.zhangspaghetti.babytalk.admin.rbac.AdminRbacRepository;
import com.zhangspaghetti.babytalk.security.JwtTokenService;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminAuthService {

    private static final Logger log = LoggerFactory.getLogger(AdminAuthService.class);
    private static final String SUPER_ADMIN_ROLE = "super_admin";

    private final AdminAuthRepository repository;
    private final AdminRbacRepository adminRbacRepository;
    private final AdminPermissionCatalog adminPermissionCatalog;
    private final AdminAuthorityService adminAuthorityService;
    private final JwtTokenService jwtTokenService;
    private final PasswordEncoder passwordEncoder;
    private final Clock clock;
    private final AdminSecurityConfig.AdminAuthProperties properties;

    public AdminAuthService(
            AdminAuthRepository repository,
            AdminRbacRepository adminRbacRepository,
            AdminPermissionCatalog adminPermissionCatalog,
            AdminAuthorityService adminAuthorityService,
            JwtTokenService jwtTokenService,
            PasswordEncoder passwordEncoder,
            Clock clock,
            AdminSecurityConfig.AdminAuthProperties properties
    ) {
        this.repository = repository;
        this.adminRbacRepository = adminRbacRepository;
        this.adminPermissionCatalog = adminPermissionCatalog;
        this.adminAuthorityService = adminAuthorityService;
        this.jwtTokenService = jwtTokenService;
        this.passwordEncoder = passwordEncoder;
        this.clock = clock;
        this.properties = properties;
    }

    @Transactional
    public TokenResponse login(String username, String password) {
        var normalizedUsername = normalizeUsername(username);
        var principal = repository.findPrincipalByUsername(normalizedUsername)
                .filter(candidate -> "active".equals(candidate.status()))
                .filter(candidate -> passwordEncoder.matches(password, candidate.passwordHash()))
                .orElseThrow(() -> invalidCredentials(normalizedUsername));

        var refreshTokenId = newRefreshTokenId();
        var now = Instant.now(clock);
        var refreshExpiresAt = now.plus(properties.refreshTokenTtl());
        repository.insertRefreshToken(new AdminAuthRepository.RefreshTokenRow(
                refreshTokenId,
                principal.principalId(),
                "active",
                now,
                refreshExpiresAt,
                now,
                null,
                null,
                null
        ));

        var authoritySnapshot = currentAuthoritySnapshot(principal.principalId());
        log.info("admin-auth login success. username={} roles={}", principal.username(), authoritySnapshot.roleCodes());
        return buildTokenResponse(principal, authoritySnapshot, refreshTokenId);
    }

    @Transactional
    public TokenResponse refresh(String rawRefreshToken) {
        var decodedRefreshToken = decodeRefreshToken(rawRefreshToken);
        var refreshToken = repository.findRefreshTokenForUpdate(decodedRefreshToken.tokenId())
                .orElseThrow(() -> invalidRefreshToken("not_found"));
        var now = Instant.now(clock);
        var status = resolveRefreshTokenStatus(refreshToken, now);
        if (status != RefreshTokenStatus.ACTIVE) {
            log.warn("admin-auth refresh rejected. username={} reason={}", decodedRefreshToken.username(), status.name().toLowerCase(Locale.ROOT));
            throw refreshTokenException(status);
        }
        var principal = repository.findPrincipalById(refreshToken.principalId())
                .orElseThrow(() -> invalidRefreshToken("principal_missing"));
        if (!"active".equals(principal.status())) {
            log.warn("admin-auth refresh rejected. username={} reason=principal_disabled", principal.username());
            throw new AdminApiContractException(HttpStatus.UNAUTHORIZED, "admin_account_disabled", "管理员账号已停用。", Map.of());
        }

        var replacementTokenId = newRefreshTokenId();
        repository.insertRefreshToken(new AdminAuthRepository.RefreshTokenRow(
                replacementTokenId,
                principal.principalId(),
                "active",
                now,
                now.plus(properties.refreshTokenTtl()),
                now,
                null,
                null,
                null
        ));
        var rotatedCount = repository.rotateRefreshToken(refreshToken.refreshTokenId(), replacementTokenId, now);
        if (rotatedCount != 1) {
            log.warn("admin-auth refresh rejected. username={} reason=refresh_token_rotated", decodedRefreshToken.username());
            throw refreshTokenException(RefreshTokenStatus.ROTATED);
        }
        var authoritySnapshot = currentAuthoritySnapshot(principal.principalId());
        log.info("admin-auth refresh success. username={} roles={}", principal.username(), authoritySnapshot.roleCodes());
        return buildTokenResponse(principal, authoritySnapshot, replacementTokenId);
    }

    @Transactional
    public LogoutResponse logout(String rawRefreshToken) {
        var decodedRefreshToken = decodeRefreshToken(rawRefreshToken);
        var refreshToken = repository.findRefreshTokenForUpdate(decodedRefreshToken.tokenId())
                .orElseThrow(() -> invalidRefreshToken("not_found"));
        var status = resolveRefreshTokenStatus(refreshToken, Instant.now(clock));
        if (status != RefreshTokenStatus.ACTIVE) {
            log.warn("admin-auth logout rejected. username={} reason={}", decodedRefreshToken.username(), status.name().toLowerCase(Locale.ROOT));
            throw refreshTokenException(status);
        }

        var loggedOutAt = Instant.now(clock);
        repository.revokeRefreshToken(refreshToken.refreshTokenId(), loggedOutAt);
        log.info("admin-auth logout success. username={}", decodedRefreshToken.username());
        return new LogoutResponse(true, loggedOutAt);
    }

    @Transactional(readOnly = true)
    public MeResponse me(Authentication authentication) {
        var principalId = currentPrincipalId(authentication);
        var principal = repository.findPrincipalById(principalId)
                .orElseThrow(() -> new AdminApiContractException(
                        HttpStatus.UNAUTHORIZED,
                        "admin_authentication_required",
                        "请先登录管理员账号。",
                        Map.of()));
        if (!"active".equals(principal.status())) {
            throw new AdminApiContractException(HttpStatus.UNAUTHORIZED, "admin_account_disabled", "管理员账号已停用。", Map.of());
        }
        var authoritySnapshot = currentAuthoritySnapshot(principal.principalId());
        return new MeResponse(
                principal.principalId(),
                principal.username(),
                principal.displayName(),
                authoritySnapshot.roleCodes(),
                authoritySnapshot.permissionCodes()
        );
    }

    @Transactional
    public AccessValidationResult validateAccessToken(String principalId, String refreshTokenId) {
        if (principalId == null || principalId.isBlank() || refreshTokenId == null || refreshTokenId.isBlank()) {
            return AccessValidationResult.SESSION_INVALID;
        }
        var refreshToken = repository.findRefreshToken(refreshTokenId).orElse(null);
        if (refreshToken == null || !principalId.equals(refreshToken.principalId())) {
            return AccessValidationResult.SESSION_INVALID;
        }
        var status = resolveRefreshTokenStatus(refreshToken, Instant.now(clock));
        if (status != RefreshTokenStatus.ACTIVE) {
            return AccessValidationResult.SESSION_INVALID;
        }
        var principal = repository.findPrincipalById(principalId).orElse(null);
        if (principal == null || !"active".equals(principal.status())) {
            return AccessValidationResult.ACCOUNT_DISABLED;
        }
        return AccessValidationResult.ACTIVE;
    }

    @Transactional
    public void seedBootstrapPrincipalIfMissing() {
        var bootstrap = properties.bootstrap();
        if (bootstrap == null || !bootstrap.enabled()) {
            return;
        }
        var normalizedUsername = normalizeUsername(bootstrap.username());
        var now = Instant.now(clock);
        repository.insertRoleIfMissing(SUPER_ADMIN_ROLE, "Built-in super admin role", now);
        adminRbacRepository.grantPermissions(SUPER_ADMIN_ROLE, adminPermissionCatalog.codes(), now);
        var existing = repository.findPrincipalByUsername(normalizedUsername);
        if (existing.isPresent()) {
            repository.grantRole(existing.get().principalId(), SUPER_ADMIN_ROLE, now);
            log.info("admin-auth bootstrap principal already present. username={}", normalizedUsername);
            return;
        }

        var principal = new AdminAuthRepository.AdminPrincipalRow(
                "admin_" + UUID.randomUUID(),
                normalizedUsername,
                passwordEncoder.encode(bootstrap.password()),
                normalizeDisplayName(bootstrap.displayName(), normalizedUsername),
                "active",
                now,
                now
        );
        repository.insertPrincipal(principal);
        repository.grantRole(principal.principalId(), SUPER_ADMIN_ROLE, now);
        log.info("admin-auth bootstrap principal created. username={} role={}", normalizedUsername, SUPER_ADMIN_ROLE);
    }

    private TokenResponse buildTokenResponse(
            AdminAuthRepository.AdminPrincipalRow principal,
            AdminAuthorityService.AuthoritySnapshot authoritySnapshot,
            String refreshTokenId
    ) {
        var accessToken = jwtTokenService.issueAccessToken(
                properties.issuer(),
                principal.principalId(),
                principal.username(),
                refreshTokenId,
                authoritySnapshot.roleCodes(),
                properties.accessTokenTtl()
        );
        var refreshToken = jwtTokenService.issueRefreshToken(
                properties.issuer(),
                principal.principalId(),
                principal.username(),
                refreshTokenId,
                properties.refreshTokenTtl()
        );
        return new TokenResponse(
                accessToken.tokenValue(),
                refreshToken.tokenValue(),
                "Bearer",
                accessToken.expiresAt(),
                refreshToken.expiresAt(),
                new MeResponse(
                        principal.principalId(),
                        principal.username(),
                        principal.displayName(),
                        authoritySnapshot.roleCodes(),
                        authoritySnapshot.permissionCodes())
        );
    }

    private AdminAuthorityService.AuthoritySnapshot currentAuthoritySnapshot(String principalId) {
        return adminAuthorityService.loadCurrentAuthorities(principalId);
    }

    private JwtTokenService.DecodedToken decodeRefreshToken(String rawRefreshToken) {
        try {
            var decoded = jwtTokenService.decode(requireToken(rawRefreshToken));
            if (decoded.tokenType() != JwtTokenService.TokenType.REFRESH) {
                throw invalidRefreshToken("wrong_type");
            }
            return decoded;
        } catch (AdminApiContractException exception) {
            throw exception;
        } catch (JwtException | IllegalArgumentException exception) {
            throw invalidRefreshToken("decode_failed");
        }
    }

    private RefreshTokenStatus resolveRefreshTokenStatus(AdminAuthRepository.RefreshTokenRow refreshToken, Instant now) {
        if (refreshToken.expiresAt().isBefore(now) && "active".equals(refreshToken.status())) {
            repository.expireRefreshToken(refreshToken.refreshTokenId(), now);
            return RefreshTokenStatus.EXPIRED;
        }
        return switch (refreshToken.status()) {
            case "active" -> RefreshTokenStatus.ACTIVE;
            case "revoked" -> RefreshTokenStatus.REVOKED;
            case "rotated" -> RefreshTokenStatus.ROTATED;
            case "expired" -> RefreshTokenStatus.EXPIRED;
            default -> RefreshTokenStatus.INVALID;
        };
    }

    private String currentPrincipalId(Authentication authentication) {
        if (authentication instanceof JwtAuthenticationToken jwtAuthenticationToken) {
            return jwtAuthenticationToken.getToken().getSubject();
        }
        throw new AdminApiContractException(HttpStatus.UNAUTHORIZED, "admin_authentication_required", "请先登录管理员账号。", Map.of());
    }

    private String normalizeUsername(String username) {
        if (username == null || username.isBlank()) {
            throw new AdminApiContractException(HttpStatus.BAD_REQUEST, "invalid_admin_username", "username 不能为空。", Map.of());
        }
        var normalized = username.trim().toLowerCase(Locale.ROOT);
        if (!normalized.matches("[a-z0-9._-]{3,64}")) {
            throw new AdminApiContractException(HttpStatus.BAD_REQUEST, "invalid_admin_username", "username 只支持 3-64 位小写字母、数字、点、下划线和中划线。", Map.of());
        }
        return normalized;
    }

    private String normalizeDisplayName(String displayName, String fallbackUsername) {
        if (displayName == null || displayName.isBlank()) {
            return fallbackUsername;
        }
        var normalized = displayName.trim();
        if (normalized.length() > 120) {
            throw new AdminApiContractException(HttpStatus.BAD_REQUEST, "invalid_admin_display_name", "displayName 过长。", Map.of());
        }
        return normalized;
    }

    private String requireToken(String rawRefreshToken) {
        if (rawRefreshToken == null || rawRefreshToken.isBlank()) {
            throw invalidRefreshToken("missing");
        }
        return rawRefreshToken.trim();
    }

    private AdminApiContractException invalidCredentials(String username) {
        log.warn("admin-auth login rejected. username={} reason=invalid_credentials", username);
        return new AdminApiContractException(HttpStatus.UNAUTHORIZED, "invalid_admin_credentials", "用户名或密码错误。", Map.of());
    }

    private AdminApiContractException invalidRefreshToken(String reason) {
        return new AdminApiContractException(HttpStatus.UNAUTHORIZED, "invalid_admin_refresh_token", "refresh token 无效。", Map.of("reason", reason));
    }

    private AdminApiContractException refreshTokenException(RefreshTokenStatus status) {
        return switch (status) {
            case REVOKED -> new AdminApiContractException(HttpStatus.UNAUTHORIZED, "refresh_token_revoked", "refresh token 已失效，请重新登录。", Map.of());
            case ROTATED -> new AdminApiContractException(HttpStatus.UNAUTHORIZED, "refresh_token_rotated", "refresh token 已被轮换，请使用新的 token。", Map.of());
            case EXPIRED -> new AdminApiContractException(HttpStatus.UNAUTHORIZED, "refresh_token_expired", "refresh token 已过期，请重新登录。", Map.of());
            default -> invalidRefreshToken(status.name().toLowerCase(Locale.ROOT));
        };
    }

    private String newRefreshTokenId() {
        return "art_" + UUID.randomUUID();
    }

    public enum AccessValidationResult {
        ACTIVE,
        SESSION_INVALID,
        ACCOUNT_DISABLED
    }

    private enum RefreshTokenStatus {
        ACTIVE,
        REVOKED,
        ROTATED,
        EXPIRED,
        INVALID
    }

    public record TokenResponse(
            String accessToken,
            String refreshToken,
            String tokenType,
            Instant accessTokenExpiresAt,
            Instant refreshTokenExpiresAt,
            MeResponse admin
    ) {
    }

    public record LogoutResponse(boolean loggedOut, Instant loggedOutAt) {
    }

    public record MeResponse(
            String principalId,
            String username,
            String displayName,
            List<String> roles,
            List<String> permissions
    ) {
    }
}
