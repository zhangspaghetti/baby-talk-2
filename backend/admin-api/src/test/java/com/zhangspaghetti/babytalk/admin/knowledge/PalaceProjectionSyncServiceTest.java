package com.zhangspaghetti.babytalk.admin.knowledge;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.ingestion.IngestionCompletedEvent;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;

@ExtendWith(MockitoExtension.class)
class PalaceProjectionSyncServiceTest {

    @Mock
    JdbcTemplate jdbcTemplate;

    PalaceProjectionSyncService service;

    @BeforeEach
    void setUp() {
        service = new PalaceProjectionSyncService(jdbcTemplate);
    }

    @Test
    void computeAgeOverlapFraction_fullOverlap() {
        assertThat(PalaceProjectionSyncService.computeAgeOverlapFraction("0-1", "0-3"))
                .isEqualTo(1.0);
    }

    @Test
    void computeAgeOverlapFraction_noOverlap() {
        assertThat(PalaceProjectionSyncService.computeAgeOverlapFraction("3-6", "0-1"))
                .isEqualTo(0.0);
    }

    @Test
    void computeAgeOverlapFraction_partialOverlap() {
        assertThat(PalaceProjectionSyncService.computeAgeOverlapFraction("1-3", "2-6"))
                .isEqualTo(0.5);
    }

    @Test
    void proposeBridges_emittedWhenCrossWingOverlapMeetsThreshold() {
        UUID newRoomId = UUID.fromString("22222222-2222-2222-2222-222222222222");
        UUID existingRoomId = UUID.fromString("11111111-1111-1111-1111-111111111111");
        IngestionCompletedEvent event = new IngestionCompletedEvent(
                UUID.randomUUID(),
                "Baby Talk",
                10
        );

        when(jdbcTemplate.queryForObject(
                contains("palace_projection_version"),
                eq(Integer.class)
        )).thenReturn(0);
        when(jdbcTemplate.queryForObject(
                eq("SELECT count(*) FROM palace_rooms"),
                eq(Integer.class)
        )).thenReturn(2);
        when(jdbcTemplate.queryForObject(
                contains("FROM palace_rooms WHERE wing = ? AND room = ?"),
                eq(UUID.class),
                eq("LANGUAGE_DEVELOPMENT"),
                eq("EARLY_COMMUNICATION")
        )).thenReturn(newRoomId);
        when(jdbcTemplate.queryForList(
                contains("FROM palace_rooms WHERE wing != ?"),
                eq("LANGUAGE_DEVELOPMENT")
        )).thenReturn(List.of(Map.of(
                "id", existingRoomId,
                "wing", "PHYSICAL",
                "room", "MOTOR_DEVELOPMENT"
        )));

        service.onIngestionCompleted(event);

        verify(jdbcTemplate, atLeastOnce()).update(
                contains("palace_bridge_edges"),
                any(),
                any(),
                any(Double.class),
                any(),
                any()
        );
    }

    @Test
    void proposeBridges_skippedWhenNoCrossWingRoomsExist() {
        IngestionCompletedEvent event = new IngestionCompletedEvent(
                UUID.randomUUID(),
                "Brain Rules for Baby",
                5
        );

        when(jdbcTemplate.queryForObject(
                contains("palace_projection_version"),
                eq(Integer.class)
        )).thenReturn(0);
        when(jdbcTemplate.queryForObject(
                eq("SELECT count(*) FROM palace_rooms"),
                eq(Integer.class)
        )).thenReturn(1);
        when(jdbcTemplate.queryForObject(
                contains("FROM palace_rooms WHERE wing = ? AND room = ?"),
                eq(UUID.class),
                eq("COGNITIVE"),
                eq("BRAIN_SCIENCE")
        )).thenReturn(UUID.randomUUID());
        when(jdbcTemplate.queryForList(
                contains("FROM palace_rooms WHERE wing != ?"),
                eq("COGNITIVE")
        )).thenReturn(List.of());

        service.onIngestionCompleted(event);

        verify(jdbcTemplate, never()).update(
                contains("palace_bridge_edges"),
                any(),
                any(),
                any(),
                any(),
                any()
        );
    }
}
