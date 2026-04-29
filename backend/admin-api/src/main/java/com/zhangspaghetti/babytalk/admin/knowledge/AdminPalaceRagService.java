package com.zhangspaghetti.babytalk.admin.knowledge;

import com.zhangspaghetti.babytalk.admin.auth.AdminApiContractException;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminPalaceRagService {

    private static final Logger log = LoggerFactory.getLogger(AdminPalaceRagService.class);

    private final PalaceRagMapper palaceRagMapper;

    public AdminPalaceRagService(PalaceRagMapper palaceRagMapper) {
        this.palaceRagMapper = palaceRagMapper;
    }

    @Transactional(readOnly = true)
    public PalaceProjectionStatusView getProjectionStatus() {
        return palaceRagMapper.findCurrentProjectionStatus()
                .stream()
                .findFirst()
                .map(row -> new PalaceProjectionStatusView(
                        false,
                        row.versionNum(),
                        row.roomCount(),
                        row.lastIngestionBatchId() == null ? null : row.lastIngestionBatchId().toString(),
                        row.status(),
                        row.createdAt() == null ? null : row.createdAt().toString()
                ))
                .orElse(new PalaceProjectionStatusView(true, null, null, null, null, null));
    }

    @Transactional(readOnly = true)
    public List<PalaceBridgeEdgeView> listBridgeEdges(String status, int limit) {
        var normalizedStatus = normalizeBridgeStatus(status);
        List<PalaceRagMapper.BridgeEdgeRow> rows = normalizedStatus == null
                ? palaceRagMapper.listBridgeEdges(limit)
                : palaceRagMapper.listBridgeEdgesByStatus(normalizedStatus, limit);
        return rows.stream().map(AdminPalaceRagService::toBridgeEdgeView).toList();
    }

    @Transactional(readOnly = true)
    public PalaceBridgeEdgeView getBridgeEdge(UUID id) {
        return palaceRagMapper.findBridgeEdgeById(id)
                .stream()
                .findFirst()
                .map(AdminPalaceRagService::toBridgeEdgeView)
                .orElseThrow(() -> bridgeEdgeNotFound(id));
    }

    @Transactional
    public PalaceBridgeEdgeView approveBridgeEdge(UUID id, String reviewedBy) {
        return updateBridgeEdgeStatus(id, "approved", reviewedBy);
    }

    @Transactional
    public PalaceBridgeEdgeView rejectBridgeEdge(UUID id, String reviewedBy) {
        return updateBridgeEdgeStatus(id, "rejected", reviewedBy);
    }

    @Transactional(readOnly = true)
    public List<PalaceQueryTraceSampleView> listTraceSamples(int limit) {
        return palaceRagMapper.listTraceSamples(limit)
                .stream()
                .map(row -> new PalaceQueryTraceSampleView(
                        row.id() == null ? null : row.id().toString(),
                        row.entryRooms(),
                        row.temporalRuleApplied(),
                        row.candidatesJson(),
                        row.bridgeEdgesCrossed(),
                        row.projectionVersionUsed(),
                        row.queriedAt() == null ? null : row.queriedAt().toString()
                ))
                .toList();
    }

    private PalaceBridgeEdgeView updateBridgeEdgeStatus(UUID id, String status, String reviewedBy) {
        int updatedRows = palaceRagMapper.updateBridgeEdgeStatus(id, status, reviewedBy);
        if (updatedRows != 1) {
            throw bridgeEdgeNotFound(id);
        }
        return getBridgeEdge(id);
    }

    private String normalizeBridgeStatus(String status) {
        if (status == null || status.isBlank()) {
            return null;
        }
        return status.trim().toLowerCase(Locale.ROOT);
    }

    private static PalaceBridgeEdgeView toBridgeEdgeView(PalaceRagMapper.BridgeEdgeRow row) {
        return new PalaceBridgeEdgeView(
                row.id() == null ? null : row.id().toString(),
                row.confidence(),
                row.status(),
                row.sourceBookA(),
                row.sourceBookB(),
                row.createdAt() == null ? null : row.createdAt().toString(),
                row.reviewedBy(),
                row.reviewedAt() == null ? null : row.reviewedAt().toString(),
                row.roomAWing(),
                row.roomAName(),
                row.roomBWing(),
                row.roomBName()
        );
    }

    private AdminApiContractException bridgeEdgeNotFound(UUID id) {
        log.warn("palace bridge edge not found. edgeId={}", id);
        return new AdminApiContractException(
                HttpStatus.NOT_FOUND,
                "palace_bridge_edge_not_found",
                "未找到对应的 palace bridge edge。",
                Map.of("edgeId", id.toString())
        );
    }

    public record PalaceProjectionStatusView(
            boolean notReady,
            Long versionNum,
            Long roomCount,
            String lastIngestionBatchId,
            String status,
            String createdAt
    ) {
    }

    public record PalaceBridgeEdgeView(
            String id,
            double confidence,
            String status,
            String sourceBookA,
            String sourceBookB,
            String createdAt,
            String reviewedBy,
            String reviewedAt,
            String roomAWing,
            String roomAName,
            String roomBWing,
            String roomBName
    ) {
    }

    public record PalaceQueryTraceSampleView(
            String id,
            String entryRooms,
            String temporalRuleApplied,
            String candidatesJson,
            String bridgeEdgesCrossed,
            Long projectionVersionUsed,
            String queriedAt
    ) {
    }
}
