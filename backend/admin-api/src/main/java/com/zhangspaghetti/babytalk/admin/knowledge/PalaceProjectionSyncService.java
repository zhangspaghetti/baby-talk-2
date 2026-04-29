package com.zhangspaghetti.babytalk.admin.knowledge;

import com.zhangspaghetti.babytalk.ingestion.IngestionCompletedEvent;
import com.zhangspaghetti.babytalk.palace.MemPalaceTaxonomy;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;

@Service
public class PalaceProjectionSyncService {

    private static final Logger log = LoggerFactory.getLogger(PalaceProjectionSyncService.class);
    static final double BRIDGE_CONFIDENCE_THRESHOLD = 0.30;

    private final PalaceProjectionMapper palaceProjectionMapper;

    public PalaceProjectionSyncService(PalaceProjectionMapper palaceProjectionMapper) {
        this.palaceProjectionMapper = palaceProjectionMapper;
    }

    @EventListener
    public void onIngestionCompleted(IngestionCompletedEvent event) {
        String bookTitle = event.bookTitle() == null ? "" : event.bookTitle();
        MemPalaceTaxonomy.BookMapping mapping = MemPalaceTaxonomy.resolve(bookTitle);
        String wing = mapping.wing().name();
        String room = mapping.room().name();
        String hall = mapping.hall().name();
        String ageRange = mapping.ageRange();

        palaceProjectionMapper.upsertRoom(wing, room, hall);
        log.info("palace_rooms upserted: jobId={}, wing={}, room={}", event.jobId(), wing, room);

        Integer existingCount = palaceProjectionMapper.countCurrentProjectionVersion();
        int roomCount = palaceProjectionMapper.countAllRooms();
        if (existingCount == null || existingCount == 0) {
            palaceProjectionMapper.insertProjectionVersion(event.jobId(), roomCount);
        } else {
            palaceProjectionMapper.updateCurrentProjectionVersion(event.jobId(), roomCount);
        }
        log.info("palace_projection_version upserted: jobId={}, roomCount={}", event.jobId(), roomCount);

        try {
            proposeBridges(event, bookTitle, wing, room, ageRange);
        } catch (Exception exception) {
            log.warn(
                    "Bridge proposal scan failed (non-fatal): jobId={}, error={}",
                    event.jobId(),
                    exception.getMessage(),
                    exception
            );
        }
    }

    private void proposeBridges(IngestionCompletedEvent event, String sourceBookTitle, String newWing, String newRoom,
                                String newAgeRange) {
        UUID newRoomId = UUID.fromString(palaceProjectionMapper.findRoomIdByWingAndRoom(newWing, newRoom));

        List<PalaceProjectionMapper.RoomRow> otherRooms = palaceProjectionMapper.listRoomsExcludingWing(newWing);

        int proposalCount = 0;
        for (PalaceProjectionMapper.RoomRow existingRoom : otherRooms) {
            String existingWing = existingRoom.wing();
            String existingRoomName = existingRoom.room();
            UUID existingRoomId = existingRoom.id();

            String existingAgeRange = resolveAgeRange(existingWing, existingRoomName);
            double confidence = computeAgeOverlapFraction(newAgeRange, existingAgeRange);
            if (confidence < BRIDGE_CONFIDENCE_THRESHOLD) {
                continue;
            }

            UUID roomAId = newRoomId.compareTo(existingRoomId) < 0 ? newRoomId : existingRoomId;
            UUID roomBId = newRoomId.compareTo(existingRoomId) < 0 ? existingRoomId : newRoomId;
            String existingSourceBook = resolveSourceBook(existingWing, existingRoomName);
            String sourceBookA = newRoomId.equals(roomAId) ? sourceBookTitle : existingSourceBook;
            String sourceBookB = newRoomId.equals(roomAId) ? existingSourceBook : sourceBookTitle;

            proposalCount += palaceProjectionMapper.insertBridgeEdgeIfAbsent(
                    roomAId, roomBId, confidence, sourceBookA, sourceBookB);
        }
        log.info("Bridge proposals created: jobId={}, count={}", event.jobId(), proposalCount);
    }

    String resolveAgeRange(String wing, String room) {
        return MemPalaceTaxonomy.catalog().values().stream()
                .filter(mapping -> mapping.wing().name().equals(wing) && mapping.room().name().equals(room))
                .map(MemPalaceTaxonomy.BookMapping::ageRange)
                .findFirst()
                .orElse("0-6");
    }

    String resolveSourceBook(String wing, String room) {
        return MemPalaceTaxonomy.catalog().entrySet().stream()
                .filter(entry -> entry.getValue().wing().name().equals(wing) && entry.getValue().room().name().equals(room))
                .map(java.util.Map.Entry::getKey)
                .findFirst()
                .orElse("unknown");
    }

    static double computeAgeOverlapFraction(String ageRange1, String ageRange2) {
        int[] range1 = parseAgeRangeMonths(ageRange1);
        int[] range2 = parseAgeRangeMonths(ageRange2);
        int intersectionStart = Math.max(range1[0], range2[0]);
        int intersectionEnd = Math.min(range1[1], range2[1]);
        int intersection = Math.max(0, intersectionEnd - intersectionStart);
        int span1 = range1[1] - range1[0];
        int span2 = range2[1] - range2[0];
        int minSpan = Math.min(span1, span2);
        if (minSpan <= 0) {
            return 0.0;
        }
        return (double) intersection / minSpan;
    }

    private static int[] parseAgeRangeMonths(String ageRange) {
        String[] parts = ageRange.split("-");
        int startMonths = Integer.parseInt(parts[0].trim()) * 12;
        int endMonths = Integer.parseInt(parts[1].trim()) * 12;
        return new int[]{startMonths, endMonths};
    }
}
