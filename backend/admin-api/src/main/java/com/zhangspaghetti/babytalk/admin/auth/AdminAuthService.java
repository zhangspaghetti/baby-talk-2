package com.zhangspaghetti.babytalk.admin.auth;

import com.zhangspaghetti.babytalk.admin.rbac.AdminPermissionCatalog;
import com.zhangspaghetti.babytalk.admin.rbac.AdminRbacRepository;
import com.zhangspaghetti.babytalk.security.JwtTokenService;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Repository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminAuthService {

    private static final Logger log = LoggerFactory.getLogger(AdminAuthService.class);
    private static final String SUPER_ADMIN_ROLE = "super_admin";

    private final AdminAuthRepository repository;
    private final AdminRbacRepository adminRbacRepository;
    private final AdminPermissionCatalog adminPermissionCatalog;
    private final JwtTokenService jwtTokenService;
    private final PasswordEncoder passwordEncoder;
    private final Clock clock;
    private final AdminSecurityConfig.AdminAuthProperties properties;

    public AdminAuthService(
            AdminAuthRepository repository,
            AdminRbacRepository adminRbacRepository,
            AdminPermissionCatalog adminPermissionCatalog,
            JwtTokenService jwtTokenService,
            PasswordEncoder passwordEncoder,
            Clock clock,
            AdminSecurityConfig.AdminAuthProperties properties
    ) {
        this.repository = repository;
        this.adminRbacRepository = adminRbacRepository;
        this.adminPermissionCatalog = adminPermissionCatalog;
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

        var roleCodes = repository.findRoleCodes(principal.principalId());
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

        log.info("admin-auth login success. username={} roles={}", principal.username(), roleCodes);
        return buildTokenResponse(principal, roleCodes, refreshTokenId);
    }

    @Transactional
    public TokenResponse refresh(String rawRefreshToken) {
        var decodedRefreshToken = decodeRefreshToken(rawRefreshToken);
        var refreshToken = repository.findRefreshToken(decodedRefreshToken.tokenId())
                .orElseThrow(() -> invalidRefreshToken("not_found"));
        var status = resolveRefreshTokenStatus(refreshToken, Instant.now(clock));
        if (status != RefreshTokenStatus.ACTIVE) {
            log.warn("admin-auth refresh rejected. username={} reason={}", decodedRefreshToken.username(), status.name().toLowerCase(Locale.ROOT));
            throw refreshTokenException(status);
        }
        var principal = repository.findPrincipalById(refreshToken.principalId())
                .orElseThrow(() -> invalidRefreshToken("principal_missing"));
        if (!"active".equals(principal.status())) {
            log.warn("admin-auth refresh rejected. username={} reason=principal_disabled", principal.username());
            throw new AdminAuthContractException(HttpStatus.UNAUTHORIZED, "admin_account_disabled", "管理员账号已停用。", Map.of());
        }

        var replacementTokenId = newRefreshTokenId();
        var now = Instant.now(clock);
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
        repository.rotateRefreshToken(refreshToken.refreshTokenId(), replacementTokenId, now);
        var roleCodes = repository.findRoleCodes(principal.principalId());
        log.info("admin-auth refresh success. username={} roles={}", principal.username(), roleCodes);
        return buildTokenResponse(principal, roleCodes, replacementTokenId);
    }

    @Transactional
    public LogoutResponse logout(String rawRefreshToken) {
        var decodedRefreshToken = decodeRefreshToken(rawRefreshToken);
        var refreshToken = repository.findRefreshToken(decodedRefreshToken.tokenId())
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
                .orElseThrow(() -> new AdminAuthContractException(
                        HttpStatus.UNAUTHORIZED,
                        "admin_authentication_required",
                        "请先登录管理员账号。",
                        Map.of()));
        if (!"active".equals(principal.status())) {
            throw new AdminAuthContractException(HttpStatus.UNAUTHORIZED, "admin_account_disabled", "管理员账号已停用。", Map.of());
        }
        return new MeResponse(
                principal.principalId(),
                principal.username(),
                principal.displayName(),
                repository.findRoleCodes(principal.principalId())
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
            List<String> roleCodes,
            String refreshTokenId
    ) {
        var accessToken = jwtTokenService.issueAccessToken(
                properties.issuer(),
                principal.principalId(),
                principal.username(),
                refreshTokenId,
                roleCodes,
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
                new MeResponse(principal.principalId(), principal.username(), principal.displayName(), roleCodes)
        );
    }

    private JwtTokenService.DecodedToken decodeRefreshToken(String rawRefreshToken) {
        try {
            var decoded = jwtTokenService.decode(requireToken(rawRefreshToken));
            if (decoded.tokenType() != JwtTokenService.TokenType.REFRESH) {
                throw invalidRefreshToken("wrong_type");
            }
            return decoded;
        } catch (AdminAuthContractException exception) {
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
        throw new AdminAuthContractException(HttpStatus.UNAUTHORIZED, "admin_authentication_required", "请先登录管理员账号。", Map.of());
    }

    private String normalizeUsername(String username) {
        if (username == null || username.isBlank()) {
            throw new AdminAuthContractException(HttpStatus.BAD_REQUEST, "invalid_admin_username", "username 不能为空。", Map.of());
        }
        var normalized = username.trim().toLowerCase(Locale.ROOT);
        if (!normalized.matches("[a-z0-9._-]{3,64}")) {
            throw new AdminAuthContractException(HttpStatus.BAD_REQUEST, "invalid_admin_username", "username 只支持 3-64 位小写字母、数字、点、下划线和中划线。", Map.of());
        }
        return normalized;
    }

    private String normalizeDisplayName(String displayName, String fallbackUsername) {
        if (displayName == null || displayName.isBlank()) {
            return fallbackUsername;
        }
        var normalized = displayName.trim();
        if (normalized.length() > 120) {
            throw new AdminAuthContractException(HttpStatus.BAD_REQUEST, "invalid_admin_display_name", "displayName 过长。", Map.of());
        }
        return normalized;
    }

    private String requireToken(String rawRefreshToken) {
        if (rawRefreshToken == null || rawRefreshToken.isBlank()) {
            throw invalidRefreshToken("missing");
        }
        return rawRefreshToken.trim();
    }

    private AdminAuthContractException invalidCredentials(String username) {
        log.warn("admin-auth login rejected. username={} reason=invalid_credentials", username);
        return new AdminAuthContractException(HttpStatus.UNAUTHORIZED, "invalid_admin_credentials", "用户名或密码错误。", Map.of());
    }

    private AdminAuthContractException invalidRefreshToken(String reason) {
        return new AdminAuthContractException(HttpStatus.UNAUTHORIZED, "invalid_admin_refresh_token", "refresh token 无效。", Map.of("reason", reason));
    }

    private AdminAuthContractException refreshTokenException(RefreshTokenStatus status) {
        return switch (status) {
            case REVOKED -> new AdminAuthContractException(HttpStatus.UNAUTHORIZED, "refresh_token_revoked", "refresh token 已失效，请重新登录。", Map.of());
            case ROTATED -> new AdminAuthContractException(HttpStatus.UNAUTHORIZED, "refresh_token_rotated", "refresh token 已被轮换，请使用新的 token。", Map.of());
            case EXPIRED -> new AdminAuthContractException(HttpStatus.UNAUTHORIZED, "refresh_token_expired", "refresh token 已过期，请重新登录。", Map.of());
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

    public record MeResponse(String principalId, String username, String displayName, List<String> roles) {
    }
}

class AdminAuthContractException extends RuntimeException {

    private final HttpStatus status;
    private final String code;
    private final Map<String, Object> details;

    AdminAuthContractException(HttpStatus status, String code, String message, Map<String, Object> details) {
        super(message);
        this.status = status;
        this.code = code;
        this.details = details == null ? Map.of() : Map.copyOf(details);
    }

    HttpStatus status() {
        return status;
    }

    String code() {
        return code;
    }

    Map<String, Object> details() {
        return details;
    }
}

@Repository
class AdminAuthRepository {

    private final JdbcTemplate jdbcTemplate;

    AdminAuthRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    Optional<AdminPrincipalRow> findPrincipalByUsername(String username) {
        return findOne(
                """
                select principal_id, username, password_hash, display_name, status, created_at, updated_at
                from admin_principals
                where username = ?
                """,
                this::mapPrincipal,
                username
        );
    }

    Optional<AdminPrincipalRow> findPrincipalById(String principalId) {
        return findOne(
                """
                select principal_id, username, password_hash, display_name, status, created_at, updated_at
                from admin_principals
                where principal_id = ?
                """,
                this::mapPrincipal,
                principalId
        );
    }

    void insertPrincipal(AdminPrincipalRow principal) {
        jdbcTemplate.update(
                """
                insert into admin_principals (
                    principal_id,
                    username,
                    password_hash,
                    display_name,
                    status,
                    created_at,
                    updated_at
                ) values (?, ?, ?, ?, ?, ?, ?)
                """,
                principal.principalId(),
                principal.username(),
                principal.passwordHash(),
                principal.displayName(),
                principal.status(),
                Timestamp.from(principal.createdAt()),
                Timestamp.from(principal.updatedAt())
        );
    }

    void insertRoleIfMissing(String roleCode, String description, Instant createdAt) {
        jdbcTemplate.update(
                """
                insert into admin_roles (role_code, description, created_at)
                values (?, ?, ?)
                on conflict (role_code) do nothing
                """,
                roleCode,
                description,
                Timestamp.from(createdAt)
        );
    }

    void grantRole(String principalId, String roleCode, Instant grantedAt) {
        jdbcTemplate.update(
                """
                insert into admin_principal_roles (principal_id, role_code, granted_at)
                values (?, ?, ?)
                on conflict (principal_id, role_code) do nothing
                """,
                principalId,
                roleCode,
                Timestamp.from(grantedAt)
        );
    }

    List<String> findRoleCodes(String principalId) {
        return jdbcTemplate.queryForList(
                """
                select role_code
                from admin_principal_roles
                where principal_id = ?
                order by role_code asc
                """,
                String.class,
                principalId
        );
    }

    void insertRefreshToken(RefreshTokenRow refreshToken) {
        jdbcTemplate.update(
                """
                insert into admin_refresh_tokens (
                    refresh_token_id,
                    principal_id,
                    status,
                    issued_at,
                    expires_at,
                    updated_at,
                    rotated_at,
                    revoked_at,
                    replacement_token_id
                ) values (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                refreshToken.refreshTokenId(),
                refreshToken.principalId(),
                refreshToken.status(),
                Timestamp.from(refreshToken.issuedAt()),
                Timestamp.from(refreshToken.expiresAt()),
                Timestamp.from(refreshToken.updatedAt()),
                toTimestamp(refreshToken.rotatedAt()),
                toTimestamp(refreshToken.revokedAt()),
                refreshToken.replacementTokenId()
        );
    }

    Optional<RefreshTokenRow> findRefreshToken(String refreshTokenId) {
        return findOne(
                """
                select refresh_token_id, principal_id, status, issued_at, expires_at, updated_at, rotated_at, revoked_at, replacement_token_id
                from admin_refresh_tokens
                where refresh_token_id = ?
                """,
                this::mapRefreshToken,
                refreshTokenId
        );
    }

    int rotateRefreshToken(String refreshTokenId, String replacementTokenId, Instant rotatedAt) {
        return jdbcTemplate.update(
                """
                update admin_refresh_tokens
                set status = 'rotated', rotated_at = ?, updated_at = ?, replacement_token_id = ?
                where refresh_token_id = ? and status = 'active'
                """,
                Timestamp.from(rotatedAt),
                Timestamp.from(rotatedAt),
                replacementTokenId,
                refreshTokenId
        );
    }

    int revokeRefreshToken(String refreshTokenId, Instant revokedAt) {
        return jdbcTemplate.update(
                """
                update admin_refresh_tokens
                set status = 'revoked', revoked_at = ?, updated_at = ?
                where refresh_token_id = ? and status = 'active'
                """,
                Timestamp.from(revokedAt),
                Timestamp.from(revokedAt),
                refreshTokenId
        );
    }

    int expireRefreshToken(String refreshTokenId, Instant expiredAt) {
        return jdbcTemplate.update(
                """
                update admin_refresh_tokens
                set status = 'expired', updated_at = ?
                where refresh_token_id = ? and status = 'active'
                """,
                Timestamp.from(expiredAt),
                refreshTokenId
        );
    }

    private <T> Optional<T> findOne(String sql, RowMapper<T> rowMapper, Object... args) {
        var results = jdbcTemplate.query(sql, rowMapper, args);
        return results.isEmpty() ? Optional.empty() : Optional.of(results.get(0));
    }

    private AdminPrincipalRow mapPrincipal(ResultSet resultSet, int rowNum) throws SQLException {
        return new AdminPrincipalRow(
                resultSet.getString("principal_id"),
                resultSet.getString("username"),
                resultSet.getString("password_hash"),
                resultSet.getString("display_name"),
                resultSet.getString("status"),
                resultSet.getTimestamp("created_at").toInstant(),
                resultSet.getTimestamp("updated_at").toInstant()
        );
    }

    private RefreshTokenRow mapRefreshToken(ResultSet resultSet, int rowNum) throws SQLException {
        return new RefreshTokenRow(
                resultSet.getString("refresh_token_id"),
                resultSet.getString("principal_id"),
                resultSet.getString("status"),
                resultSet.getTimestamp("issued_at").toInstant(),
                resultSet.getTimestamp("expires_at").toInstant(),
                resultSet.getTimestamp("updated_at").toInstant(),
                toInstant(resultSet.getTimestamp("rotated_at")),
                toInstant(resultSet.getTimestamp("revoked_at")),
                resultSet.getString("replacement_token_id")
        );
    }

    private Instant toInstant(Timestamp timestamp) {
        return timestamp == null ? null : timestamp.toInstant();
    }

    private Timestamp toTimestamp(Instant instant) {
        return instant == null ? null : Timestamp.from(instant);
    }

    record AdminPrincipalRow(
            String principalId,
            String username,
            String passwordHash,
            String displayName,
            String status,
            Instant createdAt,
            Instant updatedAt
    ) {
    }

    record RefreshTokenRow(
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
