package com.zhangspaghetti.babytalk.service;

import static org.junit.jupiter.api.Assertions.assertThrows;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;

@SpringBootTest
class GardenFertilizerServiceTest extends AbstractIntegrationTest {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void shouldRejectDuplicateClaimByUserAndEventKey() {
        String userId = "u_task1";

        jdbcTemplate.update(
                "insert into garden_fertilizer_claim_log(user_id, event_key, request_id) values (?, ?, ?)",
                userId,
                "event-1",
                "req-1"
        );

        assertThrows(DataIntegrityViolationException.class, () -> jdbcTemplate.update(
                "insert into garden_fertilizer_claim_log(user_id, event_key, request_id) values (?, ?, ?)",
                userId,
                "event-1",
                "req-2"
        ));
    }

    @Test
    void shouldRejectDuplicateClaimByUserAndRequestId() {
        String userId = "u_task1_req";

        jdbcTemplate.update(
                "insert into garden_fertilizer_claim_log(user_id, event_key, request_id) values (?, ?, ?)",
                userId,
                "event-1",
                "req-1"
        );

        assertThrows(DataIntegrityViolationException.class, () -> jdbcTemplate.update(
                "insert into garden_fertilizer_claim_log(user_id, event_key, request_id) values (?, ?, ?)",
                userId,
                "event-2",
                "req-1"
        ));
    }
}
