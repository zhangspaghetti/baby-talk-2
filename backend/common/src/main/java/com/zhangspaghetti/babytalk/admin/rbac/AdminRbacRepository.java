package com.zhangspaghetti.babytalk.admin.rbac;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;

public class AdminRbacRepository {

    private final JdbcTemplate jdbcTemplate;

    public AdminRbacRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public AuthoritySnapshot findAuthoritySnapshot(String principalId) {
        if (principalId == null || principalId.isBlank()) {
            return AuthoritySnapshot.empty();
        }

        var roleCodes = new LinkedHashSet<String>();
        var permissionCodes = new LinkedHashSet<String>();
        jdbcTemplate.query(
                """
                select apr.role_code, arp.permission_code
                from admin_principal_roles apr
                left join admin_role_permissions arp on arp.role_code = apr.role_code
                where apr.principal_id = ?
                order by apr.role_code asc, arp.permission_code asc
                """,
                resultSet -> {
                    roleCodes.add(resultSet.getString("role_code"));
                    var permissionCode = resultSet.getString("permission_code");
                    if (permissionCode != null && !permissionCode.isBlank()) {
                        permissionCodes.add(permissionCode);
                    }
                },
                principalId
        );
        return new AuthoritySnapshot(List.copyOf(roleCodes), List.copyOf(permissionCodes));
    }

    public List<String> findRoleCodes(String principalId) {
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

    public List<String> findPermissionCodes(String principalId) {
        return jdbcTemplate.queryForList(
                """
                select distinct arp.permission_code
                from admin_principal_roles apr
                join admin_role_permissions arp on arp.role_code = apr.role_code
                where apr.principal_id = ?
                order by arp.permission_code asc
                """,
                String.class,
                principalId
        );
    }

    public List<PermissionAssignmentRow> findPermissionsByRole(String roleCode) {
        return jdbcTemplate.query(
                """
                select arp.role_code, arp.permission_code, ap.description, arp.granted_at
                from admin_role_permissions arp
                join admin_permissions ap on ap.permission_code = arp.permission_code
                where arp.role_code = ?
                order by arp.permission_code asc
                """,
                this::mapPermissionAssignment,
                roleCode
        );
    }

    public List<AdminPermissionCatalog.PermissionDefinition> findPermissionCatalog() {
        return jdbcTemplate.query(
                """
                select permission_code, description
                from admin_permissions
                order by permission_code asc
                """,
                (resultSet, rowNum) -> new AdminPermissionCatalog.PermissionDefinition(
                        resultSet.getString("permission_code"),
                        resultSet.getString("description"))
        );
    }

    public List<RoleSummaryRow> findRoles() {
        Map<String, MutableRoleSummary> roles = new LinkedHashMap<>();
        jdbcTemplate.query(
                """
                select r.role_code, r.description, r.created_at, arp.permission_code
                from admin_roles r
                left join admin_role_permissions arp on arp.role_code = r.role_code
                order by r.role_code asc, arp.permission_code asc
                """,
                resultSet -> {
                    var roleCode = resultSet.getString("role_code");
                    var description = resultSet.getString("description");
                    var createdAt = mapInstant(resultSet, "created_at");
                    var summary = roles.computeIfAbsent(
                            roleCode,
                            ignored -> new MutableRoleSummary(roleCode, description, createdAt)
                    );
                    var permissionCode = resultSet.getString("permission_code");
                    if (permissionCode != null && !permissionCode.isBlank()) {
                        summary.permissionCodes.add(permissionCode);
                    }
                }
        );
        return roles.values().stream()
                .map(MutableRoleSummary::toRow)
                .toList();
    }

    public List<String> findExistingRoleCodes(Collection<String> roleCodes) {
        var distinctRoleCodes = distinctNonBlank(roleCodes);
        if (distinctRoleCodes.isEmpty()) {
            return List.of();
        }
        var placeholders = String.join(", ", Collections.nCopies(distinctRoleCodes.size(), "?"));
        return jdbcTemplate.queryForList(
                "select role_code from admin_roles where role_code in (" + placeholders + ") order by role_code asc",
                String.class,
                distinctRoleCodes.toArray()
        );
    }

    public Optional<AdminPrincipalRow> findPrincipalById(String principalId) {
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

    public Optional<AdminPrincipalRow> findPrincipalByUsername(String username) {
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

    public List<AdminPrincipalSummaryRow> findPrincipals() {
        Map<String, MutablePrincipalSummary> principals = new LinkedHashMap<>();
        jdbcTemplate.query(
                """
                select p.principal_id, p.username, p.display_name, p.status, p.created_at, p.updated_at, apr.role_code
                from admin_principals p
                left join admin_principal_roles apr on apr.principal_id = p.principal_id
                order by p.created_at asc, p.principal_id asc, apr.role_code asc
                """,
                resultSet -> {
                    var principalId = resultSet.getString("principal_id");
                    var username = resultSet.getString("username");
                    var displayName = resultSet.getString("display_name");
                    var status = resultSet.getString("status");
                    var createdAt = mapInstant(resultSet, "created_at");
                    var updatedAt = mapInstant(resultSet, "updated_at");
                    var summary = principals.computeIfAbsent(
                            principalId,
                            ignored -> new MutablePrincipalSummary(
                                    principalId,
                                    username,
                                    displayName,
                                    status,
                                    createdAt,
                                    updatedAt)
                    );
                    var roleCode = resultSet.getString("role_code");
                    if (roleCode != null && !roleCode.isBlank()) {
                        summary.roleCodes.add(roleCode);
                    }
                }
        );
        return principals.values().stream()
                .map(MutablePrincipalSummary::toRow)
                .toList();
    }

    public void insertPrincipal(AdminPrincipalRow principal) {
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

    public int insertRole(String roleCode, String description, Instant createdAt) {
        return jdbcTemplate.update(
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

    public void insertRoleIfMissing(String roleCode, String description, Instant createdAt) {
        insertRole(roleCode, description, createdAt);
    }

    public void grantRole(String principalId, String roleCode, Instant grantedAt) {
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

    public void grantRoles(String principalId, Collection<String> roleCodes, Instant grantedAt) {
        if (roleCodes == null || roleCodes.isEmpty()) {
            return;
        }
        var grantedAtTimestamp = Timestamp.from(grantedAt);
        for (String roleCode : distinctNonBlank(roleCodes)) {
            jdbcTemplate.update(
                    """
                    insert into admin_principal_roles (principal_id, role_code, granted_at)
                    values (?, ?, ?)
                    on conflict (principal_id, role_code) do nothing
                    """,
                    principalId,
                    roleCode,
                    grantedAtTimestamp
            );
        }
    }

    public void grantPermissions(String roleCode, Collection<String> permissionCodes, Instant grantedAt) {
        if (permissionCodes == null || permissionCodes.isEmpty()) {
            return;
        }
        Timestamp grantedAtTimestamp = Timestamp.from(grantedAt);
        for (String permissionCode : distinctNonBlank(permissionCodes)) {
            jdbcTemplate.update(
                    """
                    insert into admin_role_permissions (role_code, permission_code, granted_at)
                    values (?, ?, ?)
                    on conflict (role_code, permission_code) do nothing
                    """,
                    roleCode,
                    permissionCode,
                    grantedAtTimestamp
            );
        }
    }

    public int disablePrincipal(String principalId, Instant updatedAt) {
        return jdbcTemplate.update(
                """
                update admin_principals
                set status = 'disabled', updated_at = ?
                where principal_id = ? and status <> 'disabled'
                """,
                Timestamp.from(updatedAt),
                principalId
        );
    }

    private PermissionAssignmentRow mapPermissionAssignment(ResultSet resultSet, int rowNum) throws SQLException {
        return new PermissionAssignmentRow(
                resultSet.getString("role_code"),
                resultSet.getString("permission_code"),
                resultSet.getString("description"),
                mapInstant(resultSet, "granted_at")
        );
    }

    private AdminPrincipalRow mapPrincipal(ResultSet resultSet, int rowNum) throws SQLException {
        return new AdminPrincipalRow(
                resultSet.getString("principal_id"),
                resultSet.getString("username"),
                resultSet.getString("password_hash"),
                resultSet.getString("display_name"),
                resultSet.getString("status"),
                mapInstant(resultSet, "created_at"),
                mapInstant(resultSet, "updated_at")
        );
    }

    private Instant mapInstant(ResultSet resultSet, String column) throws SQLException {
        return mapInstant(resultSet.getTimestamp(column));
    }

    private Instant mapInstant(Timestamp timestamp) {
        return timestamp == null ? null : timestamp.toInstant();
    }

    private <T> Optional<T> findOne(String sql, org.springframework.jdbc.core.RowMapper<T> rowMapper, Object... args) {
        var results = jdbcTemplate.query(sql, rowMapper, args);
        return results.isEmpty() ? Optional.empty() : Optional.of(results.get(0));
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
