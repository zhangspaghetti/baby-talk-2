package com.zhangspaghetti.babytalk.palace.projection;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "palace_bridge_edges")
public class PalaceBridgeEdge {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "room_a_id", nullable = false)
    private UUID roomAId;

    @Column(name = "room_b_id", nullable = false)
    private UUID roomBId;

    @Column(nullable = false, precision = 5, scale = 4)
    private BigDecimal confidence;

    @Column(nullable = false, length = 20)
    private String status;

    @Column(name = "source_book_a", nullable = false)
    private String sourceBookA;

    @Column(name = "source_book_b", nullable = false)
    private String sourceBookB;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "reviewed_by")
    private String reviewedBy;

    @Column(name = "reviewed_at")
    private Instant reviewedAt;

    protected PalaceBridgeEdge() {
    }

    public PalaceBridgeEdge(
            UUID id,
            UUID roomAId,
            UUID roomBId,
            BigDecimal confidence,
            String status,
            String sourceBookA,
            String sourceBookB,
            Instant createdAt,
            String reviewedBy,
            Instant reviewedAt) {
        this.id = id;
        this.roomAId = roomAId;
        this.roomBId = roomBId;
        this.confidence = confidence;
        this.status = status;
        this.sourceBookA = sourceBookA;
        this.sourceBookB = sourceBookB;
        this.createdAt = createdAt;
        this.reviewedBy = reviewedBy;
        this.reviewedAt = reviewedAt;
    }

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public UUID getRoomAId() {
        return roomAId;
    }

    public void setRoomAId(UUID roomAId) {
        this.roomAId = roomAId;
    }

    public UUID getRoomBId() {
        return roomBId;
    }

    public void setRoomBId(UUID roomBId) {
        this.roomBId = roomBId;
    }

    public BigDecimal getConfidence() {
        return confidence;
    }

    public void setConfidence(BigDecimal confidence) {
        this.confidence = confidence;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getSourceBookA() {
        return sourceBookA;
    }

    public void setSourceBookA(String sourceBookA) {
        this.sourceBookA = sourceBookA;
    }

    public String getSourceBookB() {
        return sourceBookB;
    }

    public void setSourceBookB(String sourceBookB) {
        this.sourceBookB = sourceBookB;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public String getReviewedBy() {
        return reviewedBy;
    }

    public void setReviewedBy(String reviewedBy) {
        this.reviewedBy = reviewedBy;
    }

    public Instant getReviewedAt() {
        return reviewedAt;
    }

    public void setReviewedAt(Instant reviewedAt) {
        this.reviewedAt = reviewedAt;
    }
}
