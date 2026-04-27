package com.zhangspaghetti.babytalk.palace.projection;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "palace_query_traces")
public class PalaceQueryTrace {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "entry_rooms", nullable = false, columnDefinition = "jsonb")
    private JsonNode entryRooms;

    @Column(name = "temporal_rule_applied", nullable = false, length = 240)
    private String temporalRuleApplied;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "candidates_json", nullable = false, columnDefinition = "jsonb")
    private JsonNode candidatesJson;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "bridge_edges_crossed", nullable = false, columnDefinition = "jsonb")
    private JsonNode bridgeEdgesCrossed;

    @Column(name = "projection_version_used")
    private Long projectionVersionUsed;

    @Column(name = "queried_at", nullable = false)
    private Instant queriedAt;

    @Column(name = "installation_id")
    private String installationId;

    protected PalaceQueryTrace() {
    }

    public PalaceQueryTrace(
            UUID id,
            JsonNode entryRooms,
            String temporalRuleApplied,
            JsonNode candidatesJson,
            JsonNode bridgeEdgesCrossed,
            Long projectionVersionUsed,
            Instant queriedAt,
            String installationId) {
        this.id = id;
        this.entryRooms = entryRooms;
        this.temporalRuleApplied = temporalRuleApplied;
        this.candidatesJson = candidatesJson;
        this.bridgeEdgesCrossed = bridgeEdgesCrossed;
        this.projectionVersionUsed = projectionVersionUsed;
        this.queriedAt = queriedAt;
        this.installationId = installationId;
    }

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public JsonNode getEntryRooms() {
        return entryRooms;
    }

    public void setEntryRooms(JsonNode entryRooms) {
        this.entryRooms = entryRooms;
    }

    public String getTemporalRuleApplied() {
        return temporalRuleApplied;
    }

    public void setTemporalRuleApplied(String temporalRuleApplied) {
        this.temporalRuleApplied = temporalRuleApplied;
    }

    public JsonNode getCandidatesJson() {
        return candidatesJson;
    }

    public void setCandidatesJson(JsonNode candidatesJson) {
        this.candidatesJson = candidatesJson;
    }

    public JsonNode getBridgeEdgesCrossed() {
        return bridgeEdgesCrossed;
    }

    public void setBridgeEdgesCrossed(JsonNode bridgeEdgesCrossed) {
        this.bridgeEdgesCrossed = bridgeEdgesCrossed;
    }

    public Long getProjectionVersionUsed() {
        return projectionVersionUsed;
    }

    public void setProjectionVersionUsed(Long projectionVersionUsed) {
        this.projectionVersionUsed = projectionVersionUsed;
    }

    public Instant getQueriedAt() {
        return queriedAt;
    }

    public void setQueriedAt(Instant queriedAt) {
        this.queriedAt = queriedAt;
    }

    public String getInstallationId() {
        return installationId;
    }

    public void setInstallationId(String installationId) {
        this.installationId = installationId;
    }
}
