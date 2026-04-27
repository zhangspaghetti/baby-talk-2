package com.zhangspaghetti.babytalk.palace.projection;

import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PalaceBridgeEdgeRepository extends JpaRepository<PalaceBridgeEdge, UUID> {

    @Query("""
            select edge from PalaceBridgeEdge edge
            where edge.status = :status
              and (edge.roomAId = :roomAId or edge.roomBId = :roomBId)
            """)
    List<PalaceBridgeEdge> findByStatusAndRoomAIdOrRoomBId(
            @Param("status") String status,
            @Param("roomAId") UUID roomAId,
            @Param("roomBId") UUID roomBId);

    @Query("""
            select edge from PalaceBridgeEdge edge
            where edge.status = 'approved'
              and (edge.roomAId in :roomIds or edge.roomBId in :roomIds)
            """)
    List<PalaceBridgeEdge> findApprovedEdgesForRooms(@Param("roomIds") Collection<UUID> roomIds);
}
