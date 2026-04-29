package com.zhangspaghetti.babytalk.admin.knowledge;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyDouble;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.ingestion.IngestionCompletedEvent;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class PalaceProjectionSyncServiceTest {

    @Mock
    PalaceProjectionMapper palaceProjectionMapper;

    PalaceProjectionSyncService service;

    @BeforeEach
    void setUp() {
        service = new PalaceProjectionSyncService(palaceProjectionMapper);
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

        when(palaceProjectionMapper.countCurrentProjectionVersion()).thenReturn(0);
        when(palaceProjectionMapper.countAllRooms()).thenReturn(2);
        when(palaceProjectionMapper.findRoomIdByWingAndRoom("LANGUAGE_DEVELOPMENT", "EARLY_COMMUNICATION"))
                .thenReturn(newRoomId.toString());
        when(palaceProjectionMapper.listRoomsExcludingWing("LANGUAGE_DEVELOPMENT"))
                .thenReturn(List.of(new PalaceProjectionMapper.RoomRow(existingRoomId, "PHYSICAL", "MOTOR_DEVELOPMENT")));

        service.onIngestionCompleted(event);

        verify(palaceProjectionMapper, atLeastOnce()).insertBridgeEdgeIfAbsent(
                any(UUID.class),
                any(UUID.class),
                anyDouble(),
                anyString(),
                anyString()
        );
    }

    @Test
    void proposeBridges_skippedWhenNoCrossWingRoomsExist() {
        IngestionCompletedEvent event = new IngestionCompletedEvent(
                UUID.randomUUID(),
                "Brain Rules for Baby",
                5
        );

        when(palaceProjectionMapper.countCurrentProjectionVersion()).thenReturn(0);
        when(palaceProjectionMapper.countAllRooms()).thenReturn(1);
        when(palaceProjectionMapper.findRoomIdByWingAndRoom(eq("COGNITIVE"), eq("BRAIN_SCIENCE")))
                .thenReturn(UUID.randomUUID().toString());
        when(palaceProjectionMapper.listRoomsExcludingWing("COGNITIVE")).thenReturn(List.of());

        service.onIngestionCompleted(event);

        verify(palaceProjectionMapper, never()).insertBridgeEdgeIfAbsent(
                any(), any(), anyDouble(), any(), any()
        );
    }
}
