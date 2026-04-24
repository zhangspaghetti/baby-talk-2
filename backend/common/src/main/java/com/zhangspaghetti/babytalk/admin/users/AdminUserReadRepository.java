package com.zhangspaghetti.babytalk.admin.users;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;

public class AdminUserReadRepository {

    private final JdbcTemplate jdbcTemplate;

    public AdminUserReadRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<AdminUserRow> listUsers() {
        return jdbcTemplate.query(
                """
                select account_id, phone_number, status, latest_consent_status, created_at
                from accounts
                order by account_id asc
                """,
                this::mapUser
        );
    }

    private AdminUserRow mapUser(ResultSet resultSet, int rowNum) throws SQLException {
        return new AdminUserRow(
                resultSet.getString("account_id"),
                resultSet.getString("phone_number"),
                resultSet.getString("status"),
                resultSet.getString("latest_consent_status"),
                mapInstant(resultSet.getTimestamp("created_at"))
        );
    }

    private Instant mapInstant(Timestamp timestamp) {
        return timestamp == null ? null : timestamp.toInstant();
    }

    public record AdminUserRow(
            String accountId,
            String phoneNumber,
            String status,
            String latestConsentStatus,
            Instant createdAt
    ) {
    }
}
