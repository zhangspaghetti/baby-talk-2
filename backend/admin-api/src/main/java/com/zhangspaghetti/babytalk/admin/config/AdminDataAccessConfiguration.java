package com.zhangspaghetti.babytalk.admin.config;

import com.zhangspaghetti.babytalk.admin.mentor.AdminMentorAuditReadRepository;
import com.zhangspaghetti.babytalk.admin.rbac.AdminPermissionCatalog;
import com.zhangspaghetti.babytalk.admin.rbac.AdminRbacRepository;
import com.zhangspaghetti.babytalk.admin.users.AdminUserReadRepository;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

@Configuration
public class AdminDataAccessConfiguration {

    @Bean
    AdminPermissionCatalog adminPermissionCatalog() {
        return new AdminPermissionCatalog();
    }

    @Bean
    AdminRbacRepository adminRbacRepository(JdbcTemplate jdbcTemplate) {
        return new AdminRbacRepository(jdbcTemplate);
    }

    @Bean
    AdminUserReadRepository adminUserReadRepository(JdbcTemplate jdbcTemplate) {
        return new AdminUserReadRepository(jdbcTemplate);
    }

    @Bean
    AdminMentorAuditReadRepository adminMentorAuditReadRepository(JdbcTemplate jdbcTemplate) {
        return new AdminMentorAuditReadRepository(jdbcTemplate);
    }
}
