package com.zhangspaghetti.babytalk.palace.projection;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PalaceRoomRepository extends JpaRepository<PalaceRoom, UUID> {

    Optional<PalaceRoom> findByWingAndRoom(String wing, String room);

    List<PalaceRoom> findByWing(String wing);
}
