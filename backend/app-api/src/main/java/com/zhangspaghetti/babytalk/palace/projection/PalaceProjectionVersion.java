package com.zhangspaghetti.babytalk.palace.projection;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "palace_projection_version")
public class PalaceProjectionVersion {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "version_num", nullable = false)
    private Long versionNum;

    @Column(name = "last_ingestion_batch_id")
    private UUID lastIngestionBatchId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(nullable = false, length = 20)
    private String status;

    @Column(name = "room_count", nullable = false)
    private int roomCount;

    protected PalaceProjectionVersion() {
    }

    public PalaceProjectionVersion(
            UUID id,
            Long versionNum,
            UUID lastIngestionBatchId,
            Instant createdAt,
            String status,
            int roomCount) {
        this.id = id;
        this.versionNum = versionNum;
        this.lastIngestionBatchId = lastIngestionBatchId;
        this.createdAt = createdAt;
        this.status = status;
        this.roomCount = roomCount;
    }

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public Long getVersionNum() {
        return versionNum;
    }

    public void setVersionNum(Long versionNum) {
        this.versionNum = versionNum;
    }

    public UUID getLastIngestionBatchId() {
        return lastIngestionBatchId;
    }

    public void setLastIngestionBatchId(UUID lastIngestionBatchId) {
        this.lastIngestionBatchId = lastIngestionBatchId;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public int getRoomCount() {
        return roomCount;
    }

    public void setRoomCount(int roomCount) {
        this.roomCount = roomCount;
    }
}
