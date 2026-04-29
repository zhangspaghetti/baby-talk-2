package com.zhangspaghetti.babytalk.admin.knowledge;

import java.util.List;
import java.util.UUID;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface PalaceProjectionMapper {

    void upsertRoom(
            @Param("wing") String wing,
            @Param("room") String room,
            @Param("hall") String hall
    );

    Integer countCurrentProjectionVersion();

    int countAllRooms();

    void insertProjectionVersion(
            @Param("jobId") UUID jobId,
            @Param("roomCount") int roomCount
    );

    void updateCurrentProjectionVersion(
            @Param("jobId") UUID jobId,
            @Param("roomCount") int roomCount
    );

    String findRoomIdByWingAndRoom(
            @Param("wing") String wing,
            @Param("room") String room
    );

    List<RoomRow> listRoomsExcludingWing(@Param("wing") String wing);

    int insertBridgeEdgeIfAbsent(
            @Param("roomAId") UUID roomAId,
            @Param("roomBId") UUID roomBId,
            @Param("confidence") double confidence,
            @Param("sourceBookA") String sourceBookA,
            @Param("sourceBookB") String sourceBookB
    );

    record RoomRow(UUID id, String wing, String room) {
    }
}
