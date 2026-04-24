package com.zhangspaghetti.babytalk.admin.users;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Validated
@RequestMapping("/api/admin/users")
public class AdminUsersController {

    private final AdminUsersService adminUsersService;

    public AdminUsersController(AdminUsersService adminUsersService) {
        this.adminUsersService = adminUsersService;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('users:read')")
    public AdminUsersService.UserListView listUsers(
            @RequestParam(defaultValue = "1") @Min(value = 1, message = "page 至少为 1。") int page,
            @RequestParam(defaultValue = "20") @Min(value = 1, message = "pageSize 至少为 1。")
            @Max(value = 100, message = "pageSize 不能超过 100。") int pageSize,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String query
    ) {
        return adminUsersService.listUsers(page, pageSize, status, query);
    }

    @GetMapping("/{accountId}")
    @PreAuthorize("hasAuthority('users:read')")
    public AdminUsersService.UserDetailView getUser(@PathVariable String accountId) {
        return adminUsersService.getUser(accountId);
    }

    @PatchMapping("/{accountId}/disable")
    @PreAuthorize("hasAuthority('users:write')")
    public AdminUsersService.DisableUserView disableUser(
            @PathVariable String accountId,
            @Valid @RequestBody DisableUserRequest request
    ) {
        return adminUsersService.disableUser(accountId, request.reason());
    }

    record DisableUserRequest(
            @NotBlank(message = "reason 不能为空。")
            @Size(max = 240, message = "reason 过长。")
            String reason
    ) {
    }
}
