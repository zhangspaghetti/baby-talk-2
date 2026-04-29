package com.zhangspaghetti.babytalk.admin.knowledge;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.admin.auth.AdminApiContractException;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

@ExtendWith(MockitoExtension.class)
class AdminPalaceRagServiceTest {

    @Mock
    PalaceRagMapper palaceRagMapper;

    AdminPalaceRagService service;

    @BeforeEach
    void setUp() {
        service = new AdminPalaceRagService(palaceRagMapper);
    }

    // ── getProjectionStatus ──────────────────────────────────────────────────

    @Test
    void getProjectionStatus_returnsNotReadyWhenNoRowExists() {
        when(palaceRagMapper.findCurrentProjectionStatus()).thenReturn(List.of());

        AdminPalaceRagService.PalaceProjectionStatusView result = service.getProjectionStatus();

        assertThat(result.notReady()).isTrue();
        assertThat(result.versionNum()).isNull();
        assertThat(result.status()).isNull();
    }

    @Test
    void getProjectionStatus_returnsMappedViewWhenRowExists() {
        UUID batchId = UUID.randomUUID();
        PalaceRagMapper.ProjectionVersionRow row = new PalaceRagMapper.ProjectionVersionRow(
                3L, 12L, batchId, "current", Instant.parse("2026-04-29T10:00:00Z")
        );
        when(palaceRagMapper.findCurrentProjectionStatus()).thenReturn(List.of(row));

        AdminPalaceRagService.PalaceProjectionStatusView result = service.getProjectionStatus();

        assertThat(result.notReady()).isFalse();
        assertThat(result.versionNum()).isEqualTo(3L);
        assertThat(result.roomCount()).isEqualTo(12L);
        assertThat(result.lastIngestionBatchId()).isEqualTo(batchId.toString());
        assertThat(result.status()).isEqualTo("current");
        assertThat(result.createdAt()).isNotNull();
    }

    @Test
    void getProjectionStatus_handlesNullBatchIdAndCreatedAt() {
        PalaceRagMapper.ProjectionVersionRow row = new PalaceRagMapper.ProjectionVersionRow(
                1L, 5L, null, "current", null
        );
        when(palaceRagMapper.findCurrentProjectionStatus()).thenReturn(List.of(row));

        AdminPalaceRagService.PalaceProjectionStatusView result = service.getProjectionStatus();

        assertThat(result.notReady()).isFalse();
        assertThat(result.lastIngestionBatchId()).isNull();
        assertThat(result.createdAt()).isNull();
    }

    // ── listBridgeEdges ──────────────────────────────────────────────────────

    @Test
    void listBridgeEdges_callsUnfilteredQueryWhenStatusIsNull() {
        when(palaceRagMapper.listBridgeEdges(10)).thenReturn(List.of());

        service.listBridgeEdges(null, 10);

        verify(palaceRagMapper).listBridgeEdges(10);
        verify(palaceRagMapper, never()).listBridgeEdgesByStatus(anyString(), anyInt());
    }

    @Test
    void listBridgeEdges_callsUnfilteredQueryWhenStatusIsBlank() {
        when(palaceRagMapper.listBridgeEdges(5)).thenReturn(List.of());

        service.listBridgeEdges("  ", 5);

        verify(palaceRagMapper).listBridgeEdges(5);
        verify(palaceRagMapper, never()).listBridgeEdgesByStatus(anyString(), anyInt());
    }

    @Test
    void listBridgeEdges_callsFilteredQueryWhenStatusProvided() {
        when(palaceRagMapper.listBridgeEdgesByStatus("proposed", 20)).thenReturn(List.of());

        service.listBridgeEdges("PROPOSED", 20);

        verify(palaceRagMapper).listBridgeEdgesByStatus("proposed", 20);
        verify(palaceRagMapper, never()).listBridgeEdges(anyInt());
    }

    @Test
    void listBridgeEdges_returnsMappedViews() {
        UUID edgeId = UUID.randomUUID();
        PalaceRagMapper.BridgeEdgeRow row = new PalaceRagMapper.BridgeEdgeRow(
                edgeId, 0.85, "proposed", "Book A", "Book B",
                Instant.now(), null, null,
                "LANGUAGE_DEVELOPMENT", "EARLY_COMMUNICATION",
                "PHYSICAL", "MOTOR_DEVELOPMENT"
        );
        when(palaceRagMapper.listBridgeEdges(5)).thenReturn(List.of(row));

        List<AdminPalaceRagService.PalaceBridgeEdgeView> result = service.listBridgeEdges(null, 5);

        assertThat(result).hasSize(1);
        assertThat(result.get(0).id()).isEqualTo(edgeId.toString());
        assertThat(result.get(0).confidence()).isEqualTo(0.85);
        assertThat(result.get(0).status()).isEqualTo("proposed");
    }

    // ── getBridgeEdge ────────────────────────────────────────────────────────

    @Test
    void getBridgeEdge_returnsViewWhenFound() {
        UUID id = UUID.randomUUID();
        PalaceRagMapper.BridgeEdgeRow row = new PalaceRagMapper.BridgeEdgeRow(
                id, 0.6, "approved", "Book A", "Book B",
                Instant.now(), "admin", Instant.now(),
                "COGNITIVE", "BRAIN_SCIENCE",
                "PHYSICAL", "MOTOR_DEVELOPMENT"
        );
        when(palaceRagMapper.findBridgeEdgeById(id)).thenReturn(List.of(row));

        AdminPalaceRagService.PalaceBridgeEdgeView result = service.getBridgeEdge(id);

        assertThat(result.id()).isEqualTo(id.toString());
        assertThat(result.status()).isEqualTo("approved");
        assertThat(result.reviewedBy()).isEqualTo("admin");
    }

    @Test
    void getBridgeEdge_throwsNotFoundWhenAbsent() {
        UUID id = UUID.randomUUID();
        when(palaceRagMapper.findBridgeEdgeById(id)).thenReturn(List.of());

        assertThatThrownBy(() -> service.getBridgeEdge(id))
                .isInstanceOf(AdminApiContractException.class)
                .satisfies(ex -> assertThat(((AdminApiContractException) ex).status())
                        .isEqualTo(HttpStatus.NOT_FOUND));
    }

    // ── approveBridgeEdge / rejectBridgeEdge ─────────────────────────────────

    @Test
    void approveBridgeEdge_updatesStatusAndReturnsView() {
        UUID id = UUID.randomUUID();
        PalaceRagMapper.BridgeEdgeRow row = new PalaceRagMapper.BridgeEdgeRow(
                id, 0.7, "approved", "Book A", "Book B",
                Instant.now(), "reviewer1", Instant.now(),
                "COGNITIVE", "BRAIN_SCIENCE",
                "LANGUAGE_DEVELOPMENT", "EARLY_COMMUNICATION"
        );
        when(palaceRagMapper.updateBridgeEdgeStatus(id, "approved", "reviewer1")).thenReturn(1);
        when(palaceRagMapper.findBridgeEdgeById(id)).thenReturn(List.of(row));

        AdminPalaceRagService.PalaceBridgeEdgeView result = service.approveBridgeEdge(id, "reviewer1");

        assertThat(result.status()).isEqualTo("approved");
        verify(palaceRagMapper).updateBridgeEdgeStatus(eq(id), eq("approved"), eq("reviewer1"));
    }

    @Test
    void approveBridgeEdge_throwsNotFoundWhenNoRowUpdated() {
        UUID id = UUID.randomUUID();
        when(palaceRagMapper.updateBridgeEdgeStatus(id, "approved", "reviewer1")).thenReturn(0);

        assertThatThrownBy(() -> service.approveBridgeEdge(id, "reviewer1"))
                .isInstanceOf(AdminApiContractException.class)
                .satisfies(ex -> assertThat(((AdminApiContractException) ex).status())
                        .isEqualTo(HttpStatus.NOT_FOUND));
    }

    @Test
    void rejectBridgeEdge_throwsNotFoundWhenNoRowUpdated() {
        UUID id = UUID.randomUUID();
        when(palaceRagMapper.updateBridgeEdgeStatus(id, "rejected", "reviewer2")).thenReturn(0);

        assertThatThrownBy(() -> service.rejectBridgeEdge(id, "reviewer2"))
                .isInstanceOf(AdminApiContractException.class)
                .satisfies(ex -> assertThat(((AdminApiContractException) ex).status())
                        .isEqualTo(HttpStatus.NOT_FOUND));
    }

    // ── listTraceSamples ─────────────────────────────────────────────────────

    @Test
    void listTraceSamples_returnsMappedViews() {
        UUID sampleId = UUID.randomUUID();
        PalaceRagMapper.TraceSampleRow row = new PalaceRagMapper.TraceSampleRow(
                sampleId, "[\"LANGUAGE_DEVELOPMENT/EARLY_COMMUNICATION\"]",
                "0-3m", "{\"candidates\":[]}", "2", 3L, Instant.now()
        );
        when(palaceRagMapper.listTraceSamples(10)).thenReturn(List.of(row));

        List<AdminPalaceRagService.PalaceQueryTraceSampleView> result = service.listTraceSamples(10);

        assertThat(result).hasSize(1);
        assertThat(result.get(0).id()).isEqualTo(sampleId.toString());
        assertThat(result.get(0).projectionVersionUsed()).isEqualTo(3L);
    }

    @Test
    void listTraceSamples_handlesNullIdAndTimestamp() {
        PalaceRagMapper.TraceSampleRow row = new PalaceRagMapper.TraceSampleRow(
                null, "[]", null, null, null, null, null
        );
        when(palaceRagMapper.listTraceSamples(5)).thenReturn(List.of(row));

        List<AdminPalaceRagService.PalaceQueryTraceSampleView> result = service.listTraceSamples(5);

        assertThat(result).hasSize(1);
        assertThat(result.get(0).id()).isNull();
        assertThat(result.get(0).queriedAt()).isNull();
    }
}
