package com.zhangspaghetti.babytalk.admin.users;

import java.time.Instant;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminUsersService {

    private final AdminUserReadRepository adminUserReadRepository;

    public AdminUsersService(AdminUserReadRepository adminUserReadRepository) {
        this.adminUserReadRepository = adminUserReadRepository;
    }

    @Transactional(readOnly = true)
    public List<UserView> listUsers() {
        return adminUserReadRepository.listUsers().stream()
                .map(row -> new UserView(
                        row.accountId(),
                        row.phoneNumber(),
                        row.status(),
                        row.latestConsentStatus(),
                        row.createdAt()))
                .toList();
    }

    public record UserView(
            String accountId,
            String phoneNumber,
            String status,
            String latestConsentStatus,
            Instant createdAt
    ) {
    }
}
