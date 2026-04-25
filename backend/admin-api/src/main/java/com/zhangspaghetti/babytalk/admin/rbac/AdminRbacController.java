package com.zhangspaghetti.babytalk.admin.rbac;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin")
public class AdminRbacController {

    private final AdminRbacService adminRbacService;

    public AdminRbacController(AdminRbacService adminRbacService) {
        this.adminRbacService = adminRbacService;
    }

    @GetMapping("/permissions")
    @PreAuthorize("hasAuthority('rbac:read')")
    public List<AdminRbacService.PermissionView> listPermissions() {
        return adminRbacService.listPermissions();
    }

    @GetMapping("/roles")
    @PreAuthorize("hasAuthority('rbac:read')")
    public List<AdminRbacService.RoleView> listRoles() {
        return adminRbacService.listRoles();
    }

    @PostMapping("/roles")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('rbac:write')")
    public AdminRbacService.RoleView createRole(@Valid @RequestBody CreateRoleRequest request) {
        return adminRbacService.createRole(new AdminRbacService.CreateRoleCommand(
                request.roleCode(),
                request.description(),
                request.permissionCodes()));
    }

    @GetMapping("/admins")
    @PreAuthorize("hasAuthority('admins:read')")
    public List<AdminRbacService.AdminView> listAdmins() {
        return adminRbacService.listAdmins();
    }

    @PostMapping("/admins")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('admins:write')")
    public AdminRbacService.AdminView createAdmin(@Valid @RequestBody CreateAdminRequest request) {
        return adminRbacService.createAdmin(new AdminRbacService.CreateAdminCommand(
                request.username(),
                request.displayName(),
                request.password(),
                request.roleCodes()));
    }

    @PatchMapping("/admins/{principalId}/disable")
    @PreAuthorize("hasAuthority('admins:write')")
    public AdminRbacService.AdminView disableAdmin(@PathVariable String principalId) {
        return adminRbacService.disableAdmin(principalId);
    }

    record CreateRoleRequest(
            @NotBlank(message = "roleCode 不能为空。") @Size(max = 64, message = "roleCode 过长。") String roleCode,
            @NotBlank(message = "description 不能为空。") @Size(max = 240, message = "description 过长。") String description,
            List<@NotBlank(message = "permissionCode 不能为空。") @Size(max = 64, message = "permissionCode 过长。") String> permissionCodes
    ) {
    }

    record CreateAdminRequest(
            @NotBlank(message = "username 不能为空。") @Size(max = 64, message = "username 过长。") String username,
            @NotBlank(message = "displayName 不能为空。") @Size(max = 120, message = "displayName 过长。") String displayName,
            @NotBlank(message = "password 不能为空。") @Size(max = 128, message = "password 过长。") String password,
            @NotEmpty(message = "roleCodes 不能为空。")
            List<@NotBlank(message = "roleCode 不能为空。") @Size(max = 64, message = "roleCode 过长。") String> roleCodes
    ) {
    }
}
