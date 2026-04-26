package com.zhangspaghetti.babytalk.admin.rbac;

import java.time.Instant;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;

public class AdminRbacRepository {

    private final AdminRbacMapper adminRbacMapper;

    public AdminRbacRepository(AdminRbacMapper adminRbacMapper) {
        this.adminRbacMapper = adminRbacMapper;
    }

    public AuthoritySnapshot findAuthoritySnapshot(String principalId) {
        if (principalId == null || principalId.isBlank()) {
            return AuthoritySnapshot.empty();
        }

        var roleCodes = new LinkedHashSet<String>();
        var permissionCodes = new LinkedHashSet<String>();
        for (AuthorityAssignmentRow assignment : adminRbacMapper.findAuthorityAssignments(principalId)) {
            roleCodes.add(assignment.roleCode());
            var permissionCode = assignment.permissionCode();
            if (permissionCode != null && !permissionCode.isBlank()) {
                permissionCodes.add(permissionCode);
            }
        }
        return new AuthoritySnapshot(List.copyOf(roleCodes), List.copyOf(permissionCodes));
    }

    public List<String> findRoleCodes(String principalId) {
        return adminRbacMapper.findRoleCodes(principalId);
    }

    public List<String> findPermissionCodes(String principalId) {
        return adminRbacMapper.findPermissionCodes(principalId);
    }

    public List<PermissionAssignmentRow> findPermissionsByRole(String roleCode) {
        return adminRbacMapper.findPermissionsByRole(roleCode);
    }

    public List<AdminPermissionCatalog.PermissionDefinition> findPermissionCatalog() {
        return adminRbacMapper.findPermissionCatalog();
    }

    public List<RoleSummaryRow> findRoles() {
        Map<String, MutableRoleSummary> roles = new LinkedHashMap<>();
        for (RolePermissionAggregateRow row : adminRbacMapper.findRolePermissionRows()) {
            var summary = roles.computeIfAbsent(
                    row.roleCode(),
                    ignored -> new MutableRoleSummary(row.roleCode(), row.description(), row.createdAt())
            );
            var permissionCode = row.permissionCode();
            if (permissionCode != null && !permissionCode.isBlank()) {
                summary.permissionCodes.add(permissionCode);
            }
        }
        return roles.values().stream()
                .map(MutableRoleSummary::toRow)
                .toList();
    }

    public List<String> findExistingRoleCodes(Collection<String> roleCodes) {
        var distinctRoleCodes = distinctNonBlank(roleCodes);
        if (distinctRoleCodes.isEmpty()) {
            return List.of();
        }
        return adminRbacMapper.findExistingRoleCodes(distinctRoleCodes);
    }

    public Optional<AdminPrincipalRow> findPrincipalById(String principalId) {
        return Optional.ofNullable(adminRbacMapper.findPrincipalById(principalId));
    }

    public Optional<AdminPrincipalRow> findPrincipalByUsername(String username) {
        return Optional.ofNullable(adminRbacMapper.findPrincipalByUsername(username));
    }

    public List<AdminPrincipalSummaryRow> findPrincipals() {
        Map<String, MutablePrincipalSummary> principals = new LinkedHashMap<>();
        for (PrincipalRoleAggregateRow row : adminRbacMapper.findPrincipalRoleRows()) {
            var summary = principals.computeIfAbsent(
                    row.principalId(),
                    ignored -> new MutablePrincipalSummary(
                            row.principalId(),
                            row.username(),
                            row.displayName(),
                            row.status(),
                            row.createdAt(),
                            row.updatedAt())
            );
            var roleCode = row.roleCode();
            if (roleCode != null && !roleCode.isBlank()) {
                summary.roleCodes.add(roleCode);
            }
        }
        return principals.values().stream()
                .map(MutablePrincipalSummary::toRow)
                .toList();
    }

    public void insertPrincipal(AdminPrincipalRow principal) {
        adminRbacMapper.insertPrincipal(principal);
    }

    public int insertRole(String roleCode, String description, Instant createdAt) {
        return adminRbacMapper.insertRole(roleCode, description, createdAt);
    }

    public void insertRoleIfMissing(String roleCode, String description, Instant createdAt) {
        insertRole(roleCode, description, createdAt);
    }

    public void grantRole(String principalId, String roleCode, Instant grantedAt) {
        adminRbacMapper.grantRole(principalId, roleCode, grantedAt);
    }

    public void grantRoles(String principalId, Collection<String> roleCodes, Instant grantedAt) {
        if (roleCodes == null || roleCodes.isEmpty()) {
            return;
        }
        for (String roleCode : distinctNonBlank(roleCodes)) {
            adminRbacMapper.grantRole(principalId, roleCode, grantedAt);
        }
    }

    public void grantPermissions(String roleCode, Collection<String> permissionCodes, Instant grantedAt) {
        if (permissionCodes == null || permissionCodes.isEmpty()) {
            return;
        }
        for (String permissionCode : distinctNonBlank(permissionCodes)) {
            adminRbacMapper.grantPermission(roleCode, permissionCode, grantedAt);
        }
    }

    public int disablePrincipal(String principalId, Instant updatedAt) {
        return adminRbacMapper.disablePrincipal(principalId, updatedAt);
    }

    private List<String> distinctNonBlank(Collection<String> values) {
        if (values == null || values.isEmpty()) {
            return List.of();
        }
        var normalized = new LinkedHashSet<String>();
        for (String value : values) {
            if (value != null && !value.isBlank()) {
                normalized.add(value);
            }
        }
        return List.copyOf(normalized);
    }

    public record PermissionAssignmentRow(
            String roleCode,
            String permissionCode,
            String description,
            Instant grantedAt
    ) {
    }

    public record AuthoritySnapshot(List<String> roleCodes, List<String> permissionCodes) {

        public static AuthoritySnapshot empty() {
            return new AuthoritySnapshot(List.of(), List.of());
        }
    }

    public record RoleSummaryRow(
            String roleCode,
            String description,
            Instant createdAt,
            List<String> permissionCodes
    ) {
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

    public record AdminPrincipalSummaryRow(
            String principalId,
            String username,
            String displayName,
            String status,
            Instant createdAt,
            Instant updatedAt,
            List<String> roleCodes
    ) {
    }

    record AuthorityAssignmentRow(String roleCode, String permissionCode) {
    }

    record RolePermissionAggregateRow(
            String roleCode,
            String description,
            Instant createdAt,
            String permissionCode
    ) {
    }

    public record PrincipalRoleAggregateRow(
            String principalId,
            String username,
            String displayName,
            String status,
            Instant createdAt,
            Instant updatedAt,
            String roleCode
    ) {
    }

    private static final class MutableRoleSummary {

        private final String roleCode;
        private final String description;
        private final Instant createdAt;
        private final LinkedHashSet<String> permissionCodes = new LinkedHashSet<>();

        private MutableRoleSummary(String roleCode, String description, Instant createdAt) {
            this.roleCode = roleCode;
            this.description = description;
            this.createdAt = createdAt;
        }

        private RoleSummaryRow toRow() {
            return new RoleSummaryRow(roleCode, description, createdAt, List.copyOf(permissionCodes));
        }
    }

    private static final class MutablePrincipalSummary {

        private final String principalId;
        private final String username;
        private final String displayName;
        private final String status;
        private final Instant createdAt;
        private final Instant updatedAt;
        private final LinkedHashSet<String> roleCodes = new LinkedHashSet<>();

        private MutablePrincipalSummary(
                String principalId,
                String username,
                String displayName,
                String status,
                Instant createdAt,
                Instant updatedAt
        ) {
            this.principalId = principalId;
            this.username = username;
            this.displayName = displayName;
            this.status = status;
            this.createdAt = createdAt;
            this.updatedAt = updatedAt;
        }

        private AdminPrincipalSummaryRow toRow() {
            return new AdminPrincipalSummaryRow(
                    principalId,
                    username,
                    displayName,
                    status,
                    createdAt,
                    updatedAt,
                    List.copyOf(roleCodes)
            );
        }
    }
}
