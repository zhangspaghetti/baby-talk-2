package com.zhangspaghetti.babytalk.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.web.BabyTalkPayloads;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.format.DateTimeParseException;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AnalyticsService {

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    public AnalyticsService(JdbcTemplate jdbcTemplate, ObjectMapper objectMapper) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper;
    }

    @Transactional
    public BabyTalkPayloads.AnalyticsIngestResponse ingestEvents(
            String sessionId,
            BabyTalkPayloads.AnalyticsBatchRequest request
    ) {
        requireSession(sessionId);

        List<BabyTalkPayloads.AnalyticsEventRequest> events = request.events();
        if (events == null || events.isEmpty()) {
            return new BabyTalkPayloads.AnalyticsIngestResponse(0);
        }

        int acceptedCount = 0;
        for (BabyTalkPayloads.AnalyticsEventRequest event : events) {
            acceptedCount += insertEvent(sessionId, event);
        }

        return new BabyTalkPayloads.AnalyticsIngestResponse(acceptedCount);
    }

    public BabyTalkPayloads.RetentionSummaryResponse retentionSummary() {
        Map<String, LocalDate> firstOpenedDates = loadFirstOpenedDates();
        Map<String, Set<LocalDate>> activeDates = loadActiveDates();
        LocalDate today = LocalDate.now(ZoneOffset.UTC);

        List<BabyTalkPayloads.RetentionWindowResponse> windows = List.of(
                buildRetentionWindow(1, today, firstOpenedDates, activeDates),
                buildRetentionWindow(7, today, firstOpenedDates, activeDates),
                buildRetentionWindow(30, today, firstOpenedDates, activeDates)
        );

        return new BabyTalkPayloads.RetentionSummaryResponse(windows);
    }

    private int insertEvent(String sessionId, BabyTalkPayloads.AnalyticsEventRequest event) {
        if (event == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Analytics event cannot be null");
        }
        if (event.eventId() == null || event.eventId().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Analytics eventId is required");
        }
        if (event.eventName() == null || event.eventName().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Analytics eventName is required");
        }
        if (event.occurredAt() == null || event.occurredAt().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Analytics occurredAt is required");
        }

        Instant occurredAt;
        try {
            occurredAt = Instant.parse(event.occurredAt());
        } catch (DateTimeParseException error) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Analytics occurredAt must be an ISO-8601 instant", error);
        }

        try {
            return jdbcTemplate.update(
                    "insert into analytics_events (event_id, session_id, event_name, screen_name, occurred_at, properties_json, uploaded_at) values (?, ?, ?, ?, ?, ?, ?)",
                    event.eventId(),
                    sessionId,
                    event.eventName(),
                    event.screenName(),
                    Timestamp.from(occurredAt),
                    objectMapper.writeValueAsString(event.properties() == null ? Map.of() : event.properties()),
                    Timestamp.from(Instant.now())
            );
        } catch (DuplicateKeyException error) {
            return 0;
        } catch (JsonProcessingException error) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Analytics properties must be serializable", error);
        }
    }

    private void requireSession(String sessionId) {
        if (sessionId == null || sessionId.isBlank()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Missing X-Session-Id header");
        }

        Integer count = jdbcTemplate.queryForObject(
                "select count(*) from app_sessions where session_id = ?",
                Integer.class,
                sessionId
        );
        if (count == null || count == 0) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Unknown session: " + sessionId);
        }
    }

    private Map<String, LocalDate> loadFirstOpenedDates() {
        Map<String, LocalDate> firstOpenedDates = new HashMap<>();
        jdbcTemplate.query(
                "select session_id, min(occurred_at) as first_opened_at from analytics_events where event_name = 'app_opened' group by session_id",
            (resultSet, rowNum) -> {
                firstOpenedDates.put(
                    resultSet.getString("session_id"),
                    resultSet.getTimestamp("first_opened_at").toInstant().atZone(ZoneOffset.UTC).toLocalDate()
                );
                return null;
            }
        );
        return firstOpenedDates;
    }

    private Map<String, Set<LocalDate>> loadActiveDates() {
        Map<String, Set<LocalDate>> activeDates = new HashMap<>();
        jdbcTemplate.query(
                "select session_id, occurred_at from analytics_events order by occurred_at asc",
            (resultSet, rowNum) -> {
                    String sessionId = resultSet.getString("session_id");
                    LocalDate activeDate = resultSet.getTimestamp("occurred_at")
                            .toInstant()
                            .atZone(ZoneOffset.UTC)
                            .toLocalDate();
                    activeDates.computeIfAbsent(sessionId, ignored -> new HashSet<>()).add(activeDate);
                return null;
                }
        );
        return activeDates;
    }

    private BabyTalkPayloads.RetentionWindowResponse buildRetentionWindow(
            int days,
            LocalDate today,
            Map<String, LocalDate> firstOpenedDates,
            Map<String, Set<LocalDate>> activeDates
    ) {
        int cohortUsers = 0;
        int retainedUsers = 0;

        for (Map.Entry<String, LocalDate> entry : firstOpenedDates.entrySet()) {
            LocalDate firstOpenedDate = entry.getValue();
            LocalDate retentionDate = firstOpenedDate.plusDays(days);
            if (retentionDate.isAfter(today)) {
                continue;
            }

            cohortUsers += 1;
            Set<LocalDate> userActiveDates = activeDates.getOrDefault(entry.getKey(), Set.of());
            if (userActiveDates.contains(retentionDate)) {
                retainedUsers += 1;
            }
        }

        double retentionRate = cohortUsers == 0 ? 0.0 : (double) retainedUsers / cohortUsers;
        return new BabyTalkPayloads.RetentionWindowResponse(days, cohortUsers, retainedUsers, retentionRate);
    }
}