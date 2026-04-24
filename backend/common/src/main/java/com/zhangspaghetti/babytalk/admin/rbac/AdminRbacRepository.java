package com.zhangspaghetti.babytalk.admin.rbac;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
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

    public void insertRoleIfMissing(String roleCode, String description, Instant createdAt) {
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

    public void grantPermissions(String roleCode, Collection<String> permissionCodes, Instant grantedAt) {
        if (permissionCodes == null || permissionCodes.isEmpty()) {
            return;
        }
        Timestamp grantedAtTimestamp = Timestamp.from(grantedAt);
        for (String permissionCode : new LinkedHashSet<>(permissionCodes)) {
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

    private PermissionAssignmentRow mapPermissionAssignment(ResultSet resultSet, int rowNum) throws SQLException {
        return new PermissionAssignmentRow(
                resultSet.getString("role_code"),
                resultSet.getString("permission_code"),
                resultSet.getString("description"),
                mapInstant(resultSet, "granted_at")
        );
    }

    private Instant mapInstant(ResultSet resultSet, String column) throws SQLException {
        Timestamp value = resultSet.getTimestamp(column);
        return value == null ? null : value.toInstant();
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
}
