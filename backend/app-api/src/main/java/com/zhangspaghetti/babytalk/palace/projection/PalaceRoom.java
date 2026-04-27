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
@Table(name = "palace_rooms")
public class PalaceRoom {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, length = 120)
    private String wing;

    @Column(nullable = false, length = 120)
    private String room;

    @Column(length = 120)
    private String hall;

    @Column(name = "last_updated", nullable = false)
    private Instant lastUpdated;

    @Column(name = "source_book_count", nullable = false)
    private int sourceBookCount;

    protected PalaceRoom() {
    }

    public PalaceRoom(UUID id, String wing, String room, String hall, Instant lastUpdated, int sourceBookCount) {
        this.id = id;
        this.wing = wing;
        this.room = room;
        this.hall = hall;
        this.lastUpdated = lastUpdated;
        this.sourceBookCount = sourceBookCount;
    }

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public String getWing() {
        return wing;
    }

    public void setWing(String wing) {
        this.wing = wing;
    }

    public String getRoom() {
        return room;
    }

    public void setRoom(String room) {
        this.room = room;
    }

    public String getHall() {
        return hall;
    }

    public void setHall(String hall) {
        this.hall = hall;
    }

    public Instant getLastUpdated() {
        return lastUpdated;
    }

    public void setLastUpdated(Instant lastUpdated) {
        this.lastUpdated = lastUpdated;
    }

    public int getSourceBookCount() {
        return sourceBookCount;
    }

    public void setSourceBookCount(int sourceBookCount) {
        this.sourceBookCount = sourceBookCount;
    }
}
