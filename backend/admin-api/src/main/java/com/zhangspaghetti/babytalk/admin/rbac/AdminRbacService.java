package com.zhangspaghetti.babytalk.admin.rbac;

import com.zhangspaghetti.babytalk.admin.auth.AdminApiContractException;
import java.time.Clock;
import java.time.Instant;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminRbacService {

    private final AdminRbacRepository adminRbacRepository;
    private final AdminPermissionCatalog adminPermissionCatalog;
    private final PasswordEncoder passwordEncoder;
    private final Clock clock;

    public AdminRbacService(
            AdminRbacRepository adminRbacRepository,
            AdminPermissionCatalog adminPermissionCatalog,
            PasswordEncoder passwordEncoder,
            Clock clock
    ) {
        this.adminRbacRepository = adminRbacRepository;
        this.adminPermissionCatalog = adminPermissionCatalog;
        this.passwordEncoder = passwordEncoder;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<PermissionView> listPermissions() {
        return adminRbacRepository.findPermissionCatalog().stream()
                .map(permission -> new PermissionView(permission.code(), permission.description()))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<RoleView> listRoles() {
        return adminRbacRepository.findRoles().stream()
                .map(this::toRoleView)
                .toList();
    }

    @Transactional
    public RoleView createRole(CreateRoleCommand command) {
        var roleCode = normalizeRoleCode(command.roleCode());
        var description = normalizeRoleDescription(command.description());
        var permissionCodes = normalizePermissionCodes(command.permissionCodes());
        validatePermissionCodes(permissionCodes);

        var createdAt = Instant.now(clock);
        if (adminRbacRepository.insertRole(roleCode, description, createdAt) == 0) {
            throw new AdminApiContractException(
                    HttpStatus.CONFLICT,
                    "admin_role_conflict",
                    "roleCode 已存在。",
                    Map.of("roleCode", roleCode));
        }
        adminRbacRepository.grantPermissions(roleCode, permissionCodes, createdAt);
        return new RoleView(roleCode, description, createdAt, permissionCodes);
    }

    @Transactional(readOnly = true)
    public List<AdminView> listAdmins() {
        return adminRbacRepository.findPrincipals().stream()
                .map(this::toAdminView)
                .toList();
    }

    @Transactional
    public AdminView createAdmin(CreateAdminCommand command) {
        var username = normalizeUsername(command.username());
        var displayName = normalizeDisplayName(command.displayName(), username);
        var password = requirePassword(command.password());
        var roleCodes = normalizeRoleCodes(command.roleCodes());
        validateRoleCodes(roleCodes);

        if (adminRbacRepository.findPrincipalByUsername(username).isPresent()) {
            throw new AdminApiContractException(
                    HttpStatus.CONFLICT,
                    "admin_username_conflict",
                    "username 已存在。",
                    Map.of("username", username));
        }

        var now = Instant.now(clock);
        var principalId = "admin_" + UUID.randomUUID();
        try {
            adminRbacRepository.insertPrincipal(new AdminRbacRepository.AdminPrincipalRow(
                    principalId,
                    username,
                    passwordEncoder.encode(password),
                    displayName,
                    "active",
                    now,
                    now
            ));
        } catch (DuplicateKeyException exception) {
            throw new AdminApiContractException(
                    HttpStatus.CONFLICT,
                    "admin_username_conflict",
                    "username 已存在。",
                    Map.of("username", username));
        }
        adminRbacRepository.grantRoles(principalId, roleCodes, now);
        return new AdminView(principalId, username, displayName, "active", now, now, roleCodes);
    }

    @Transactional
    public AdminView disableAdmin(String principalId) {
        var normalizedPrincipalId = requirePrincipalId(principalId);
        var principal = adminRbacRepository.findPrincipalById(normalizedPrincipalId)
                .orElseThrow(() -> new AdminApiContractException(
                        HttpStatus.NOT_FOUND,
                        "admin_principal_not_found",
                        "管理员不存在。",
                        Map.of("principalId", normalizedPrincipalId)));
        var roleCodes = adminRbacRepository.findRoleCodes(normalizedPrincipalId);
        if ("disabled".equals(principal.status())) {
            return new AdminView(
                    principal.principalId(),
                    principal.username(),
                    principal.displayName(),
                    principal.status(),
                    principal.createdAt(),
                    principal.updatedAt(),
                    roleCodes
            );
        }

        var updatedAt = Instant.now(clock);
        adminRbacRepository.disablePrincipal(normalizedPrincipalId, updatedAt);
        return new AdminView(
                principal.principalId(),
                principal.username(),
                principal.displayName(),
                "disabled",
                principal.createdAt(),
                updatedAt,
                roleCodes
        );
    }

    private RoleView toRoleView(AdminRbacRepository.RoleSummaryRow row) {
        return new RoleView(row.roleCode(), row.description(), row.createdAt(), row.permissionCodes());
    }

    private AdminView toAdminView(AdminRbacRepository.AdminPrincipalSummaryRow row) {
        return new AdminView(
                row.principalId(),
                row.username(),
                row.displayName(),
                row.status(),
                row.createdAt(),
                row.updatedAt(),
                row.roleCodes()
        );
    }

    private void validatePermissionCodes(List<String> permissionCodes) {
        var unknown = permissionCodes.stream()
                .filter(permissionCode -> !adminPermissionCatalog.contains(permissionCode))
                .toList();
        if (!unknown.isEmpty()) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    "unknown_admin_permission",
                    "包含未知 permissionCode。",
                    Map.of("permissionCodes", unknown));
        }
    }

    private void validateRoleCodes(List<String> roleCodes) {
        var existingRoleCodes = adminRbacRepository.findExistingRoleCodes(roleCodes);
        var unknown = roleCodes.stream()
                .filter(roleCode -> !existingRoleCodes.contains(roleCode))
                .toList();
        if (!unknown.isEmpty()) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    "unknown_admin_role",
                    "包含未知 roleCode。",
                    Map.of("roleCodes", unknown));
        }
    }

    private String normalizeRoleCode(String roleCode) {
        if (roleCode == null || roleCode.isBlank()) {
            throw new AdminApiContractException(HttpStatus.BAD_REQUEST, "invalid_admin_role_code", "roleCode 不能为空。", Map.of());
        }
        var normalized = roleCode.trim().toLowerCase(Locale.ROOT);
        if (!normalized.matches("[a-z0-9_-]{3,64}")) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_admin_role_code",
                    "roleCode 只支持 3-64 位小写字母、数字、下划线和中划线。",
                    Map.of());
        }
        return normalized;
    }

    private String normalizeRoleDescription(String description) {
        if (description == null || description.isBlank()) {
            throw new AdminApiContractException(HttpStatus.BAD_REQUEST, "invalid_admin_role_description", "description 不能为空。", Map.of());
        }
        var normalized = description.trim();
        if (normalized.length() > 240) {
            throw new AdminApiContractException(HttpStatus.BAD_REQUEST, "invalid_admin_role_description", "description 过长。", Map.of());
        }
        return normalized;
    }

    private String normalizeUsername(String username) {
        if (username == null || username.isBlank()) {
            throw new AdminApiContractException(HttpStatus.BAD_REQUEST, "invalid_admin_username", "username 不能为空。", Map.of());
        }
        var normalized = username.trim().toLowerCase(Locale.ROOT);
        if (!normalized.matches("[a-z0-9._-]{3,64}")) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_admin_username",
                    "username 只支持 3-64 位小写字母、数字、点、下划线和中划线。",
                    Map.of());
        }
        return normalized;
    }

    private String normalizeDisplayName(String displayName, String fallbackUsername) {
        if (displayName == null || displayName.isBlank()) {
            throw new AdminApiContractException(HttpStatus.BAD_REQUEST, "invalid_admin_display_name", "displayName 不能为空。", Map.of());
        }
        var normalized = displayName.trim();
        if (normalized.length() > 120) {
            throw new AdminApiContractException(HttpStatus.BAD_REQUEST, "invalid_admin_display_name", "displayName 过长。", Map.of());
        }
        return normalized.isEmpty() ? fallbackUsername : normalized;
    }

    private String requirePassword(String password) {
        if (password == null || password.isBlank()) {
            throw new AdminApiContractException(HttpStatus.BAD_REQUEST, "invalid_admin_password", "password 不能为空。", Map.of());
        }
        if (password.length() > 128) {
            throw new AdminApiContractException(HttpStatus.BAD_REQUEST, "invalid_admin_password", "password 过长。", Map.of());
        }
        return password;
    }

    private String requirePrincipalId(String principalId) {
        if (principalId == null || principalId.isBlank()) {
            throw new AdminApiContractException(HttpStatus.BAD_REQUEST, "invalid_admin_principal_id", "principalId 不能为空。", Map.of());
        }
        return principalId.trim();
    }

    private List<String> normalizePermissionCodes(Collection<String> permissionCodes) {
        if (permissionCodes == null || permissionCodes.isEmpty()) {
            return List.of();
        }
        var normalized = new LinkedHashSet<String>();
        for (String permissionCode : permissionCodes) {
            if (permissionCode != null && !permissionCode.isBlank()) {
                normalized.add(permissionCode.trim().toLowerCase(Locale.ROOT));
            }
        }
        return List.copyOf(normalized);
    }

    private List<String> normalizeRoleCodes(Collection<String> roleCodes) {
        if (roleCodes == null || roleCodes.isEmpty()) {
            throw new AdminApiContractException(HttpStatus.BAD_REQUEST, "invalid_admin_role_codes", "roleCodes 不能为空。", Map.of());
        }
        var normalized = new LinkedHashSet<String>();
        for (String roleCode : roleCodes) {
            if (roleCode != null && !roleCode.isBlank()) {
                normalized.add(roleCode.trim().toLowerCase(Locale.ROOT));
            }
        }
        if (normalized.isEmpty()) {
            throw new AdminApiContractException(HttpStatus.BAD_REQUEST, "invalid_admin_role_codes", "roleCodes 不能为空。", Map.of());
        }
        return List.copyOf(normalized);
    }

    public record CreateRoleCommand(String roleCode, String description, List<String> permissionCodes) {
    }

    public record CreateAdminCommand(String username, String displayName, String password, List<String> roleCodes) {
    }

    public record PermissionView(String permissionCode, String description) {
    }

    public record RoleView(String roleCode, String description, Instant createdAt, List<String> permissionCodes) {
    }

    public record AdminView(
            String principalId,
            String username,
            String displayName,
            String status,
            Instant createdAt,
            Instant updatedAt,
            List<String> roleCodes
    ) {
    }
}
