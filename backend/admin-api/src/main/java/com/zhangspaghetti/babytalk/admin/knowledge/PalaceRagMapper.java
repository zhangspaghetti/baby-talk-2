package com.zhangspaghetti.babytalk.admin.knowledge;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface PalaceRagMapper {

    List<ProjectionVersionRow> findCurrentProjectionStatus();

    List<BridgeEdgeRow> listBridgeEdges(@Param("limit") int limit);

    List<BridgeEdgeRow> listBridgeEdgesByStatus(@Param("status") String status, @Param("limit") int limit);

    List<BridgeEdgeRow> findBridgeEdgeById(@Param("id") UUID id);

    int updateBridgeEdgeStatus(
            @Param("id") UUID id,
            @Param("status") String status,
            @Param("reviewedBy") String reviewedBy
    );

    List<TraceSampleRow> listTraceSamples(@Param("limit") int limit);

    record ProjectionVersionRow(
            Long versionNum,
            Long roomCount,
            UUID lastIngestionBatchId,
            String status,
            Instant createdAt
    ) {
    }

    record BridgeEdgeRow(
            UUID id,
            Double confidence,
            String status,
            String sourceBookA,
            String sourceBookB,
            Instant createdAt,
            String reviewedBy,
            Instant reviewedAt,
            String roomAWing,
            String roomAName,
            String roomBWing,
            String roomBName
    ) {
    }

    record TraceSampleRow(
            UUID id,
            String entryRooms,
            String temporalRuleApplied,
            String candidatesJson,
            String bridgeEdgesCrossed,
            Long projectionVersionUsed,
            Instant queriedAt
    ) {
    }
}
