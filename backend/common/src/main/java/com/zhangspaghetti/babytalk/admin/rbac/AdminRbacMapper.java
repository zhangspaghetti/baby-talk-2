package com.zhangspaghetti.babytalk.admin.rbac;

import java.time.Instant;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface AdminRbacMapper {

    List<AdminRbacRepository.AuthorityAssignmentRow> findAuthorityAssignments(@Param("principalId") String principalId);

    List<String> findRoleCodes(@Param("principalId") String principalId);

    List<String> findPermissionCodes(@Param("principalId") String principalId);

    List<AdminRbacRepository.PermissionAssignmentRow> findPermissionsByRole(@Param("roleCode") String roleCode);

    List<AdminPermissionCatalog.PermissionDefinition> findPermissionCatalog();

    List<AdminRbacRepository.RolePermissionAggregateRow> findRolePermissionRows();

    List<String> findExistingRoleCodes(@Param("roleCodes") List<String> roleCodes);

    AdminRbacRepository.AdminPrincipalRow findPrincipalById(@Param("principalId") String principalId);

    AdminRbacRepository.AdminPrincipalRow findPrincipalByUsername(@Param("username") String username);

    List<AdminRbacRepository.PrincipalRoleAggregateRow> findPrincipalRoleRows();

    void insertPrincipal(@Param("principal") AdminRbacRepository.AdminPrincipalRow principal);

    int insertRole(
            @Param("roleCode") String roleCode,
            @Param("description") String description,
            @Param("createdAt") Instant createdAt
    );

    int grantRole(
            @Param("principalId") String principalId,
            @Param("roleCode") String roleCode,
            @Param("grantedAt") Instant grantedAt
    );

    int grantPermission(
            @Param("roleCode") String roleCode,
            @Param("permissionCode") String permissionCode,
            @Param("grantedAt") Instant grantedAt
    );

    int disablePrincipal(
            @Param("principalId") String principalId,
            @Param("updatedAt") Instant updatedAt
    );
}
