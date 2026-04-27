package com.zhangspaghetti.babytalk.admin.knowledge;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.within;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.ArgumentMatchers.eq;
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
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.jdbc.core.JdbcTemplate;

@ExtendWith(MockitoExtension.class)
public class PalaceProjectionSyncServiceTest {

    @Mock
    private JdbcTemplate jdbcTemplate;

    private PalaceProjectionSyncService service;

    @BeforeEach
    void setUp() {
        service = new PalaceProjectionSyncService(jdbcTemplate);
    }

    @Test
    void onIngestionCompletedUpsertsRoomVersionAndBridgeProposal() {
        var event = new IngestionCompletedEvent(
                UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
                "Baby Talk",
                12
        );
        var newRoomId = UUID.fromString("00000000-0000-0000-0000-000000000002");
        var existingRoomId = UUID.fromString("00000000-0000-0000-0000-000000000001");

        when(jdbcTemplate.queryForObject(
                "SELECT count(*) FROM palace_projection_version WHERE status = 'current'",
                Integer.class
        )).thenReturn(0);
        when(jdbcTemplate.queryForObject("SELECT count(*) FROM palace_rooms", Integer.class)).thenReturn(2);
        when(jdbcTemplate.queryForObject(
                eq("SELECT id FROM palace_rooms WHERE wing = ? AND room = ?"),
                eq(UUID.class),
                eq("LANGUAGE_DEVELOPMENT"),
                eq("EARLY_COMMUNICATION")
        )).thenReturn(newRoomId);
        when(jdbcTemplate.queryForList(
                eq("SELECT id, wing, room FROM palace_rooms WHERE wing != ?"),
                eq("LANGUAGE_DEVELOPMENT")
        )).thenReturn(List.of(Map.of(
                "id", existingRoomId,
                "wing", "COGNITIVE",
                "room", "BRAIN_SCIENCE"
        )));
        when(jdbcTemplate.update(
                contains("INSERT INTO palace_bridge_edges"),
                eq(existingRoomId),
                eq(newRoomId),
                eq(1.0d),
                eq("Brain Rules for Baby"),
                eq("Baby Talk")
        )).thenReturn(1);

        service.onIngestionCompleted(event);

        verify(jdbcTemplate).update(
                contains("INSERT INTO palace_rooms"),
                eq("LANGUAGE_DEVELOPMENT"),
                eq("EARLY_COMMUNICATION"),
                eq("BABBLING_HALL")
        );
        verify(jdbcTemplate).update(
                contains("INSERT INTO palace_projection_version"),
                eq(event.jobId()),
                eq(2)
        );
        verify(jdbcTemplate).update(
                contains("INSERT INTO palace_bridge_edges"),
                eq(existingRoomId),
                eq(newRoomId),
                eq(1.0d),
                eq("Brain Rules for Baby"),
                eq("Baby Talk")
        );
    }

    @Test
    void onIngestionCompletedKeepsRoomAndVersionUpsertsWhenBridgeScanFails() {
        var event = new IngestionCompletedEvent(
                UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"),
                "Baby Talk",
                6
        );

        when(jdbcTemplate.queryForObject(
                "SELECT count(*) FROM palace_projection_version WHERE status = 'current'",
                Integer.class
        )).thenReturn(1);
        when(jdbcTemplate.queryForObject("SELECT count(*) FROM palace_rooms", Integer.class)).thenReturn(1);
        when(jdbcTemplate.queryForObject(
                eq("SELECT id FROM palace_rooms WHERE wing = ? AND room = ?"),
                eq(UUID.class),
                eq("LANGUAGE_DEVELOPMENT"),
                eq("EARLY_COMMUNICATION")
        )).thenThrow(new DataAccessResourceFailureException("bridge read failed"));

        assertThatCode(() -> service.onIngestionCompleted(event)).doesNotThrowAnyException();

        verify(jdbcTemplate).update(
                contains("INSERT INTO palace_rooms"),
                eq("LANGUAGE_DEVELOPMENT"),
                eq("EARLY_COMMUNICATION"),
                eq("BABBLING_HALL")
        );
        verify(jdbcTemplate).update(
                contains("UPDATE palace_projection_version"),
                eq(event.jobId()),
                eq(1)
        );
    }

    @Test
    void computeAgeOverlapFractionAndCatalogFallbacksStayDeterministic() {
        assertThat(PalaceProjectionSyncService.computeAgeOverlapFraction("0-3", "2-6"))
                .isCloseTo(1.0d / 3.0d, within(0.0001d));
        assertThat(PalaceProjectionSyncService.computeAgeOverlapFraction("0-1", "2-3"))
                .isEqualTo(0.0d);
        assertThat(service.resolveAgeRange("UNKNOWN", "ROOM")).isEqualTo("0-6");
        assertThat(service.resolveSourceBook("UNKNOWN", "ROOM")).isEqualTo("unknown");
    }
}
