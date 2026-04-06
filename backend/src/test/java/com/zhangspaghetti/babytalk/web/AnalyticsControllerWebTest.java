package com.zhangspaghetti.babytalk.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@AutoConfigureMockMvc
class AnalyticsControllerWebTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void clearAnalyticsTables() {
      jdbcTemplate.update("delete from analytics_events");
      jdbcTemplate.update("delete from app_sessions");
    }

    @Test
    void analyticsEventsAreStoredIdempotently() throws Exception {
        String sessionId = createSession();

        mockMvc.perform(post("/api/v1/analytics/events")
                .header("X-App-Version", "1.0.0+1")
                .header("X-Session-Id", sessionId)
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {
                          "events": [
                            {
                              "eventId": "evt-1",
                              "eventName": "app_opened",
                              "screenName": "home",
                              "occurredAt": "2026-04-01T12:00:00Z",
                              "properties": {
                                "source": "widget_test"
                              }
                            },
                            {
                              "eventId": "evt-1",
                              "eventName": "app_opened",
                              "screenName": "home",
                              "occurredAt": "2026-04-01T12:00:00Z",
                              "properties": {
                                "source": "retry"
                              }
                            }
                          ]
                        }
                        """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.acceptedCount").value(1));

        Integer storedCount = jdbcTemplate.queryForObject(
                "select count(*) from analytics_events where session_id = ?",
                Integer.class,
                sessionId
        );

        assertThat(storedCount).isEqualTo(1);
    }

    @Test
    void retentionSummaryReportsD1D7AndD30Windows() throws Exception {
        String sessionA = createSession();
        String sessionB = createSession();
        String sessionC = createSession();

        postAnalyticsEvents(sessionA, """
                {
                  "events": [
                    {
                      "eventId": "session-a-open",
                      "eventName": "app_opened",
                      "occurredAt": "%s",
                      "properties": {}
                    },
                    {
                      "eventId": "session-a-day1",
                      "eventName": "screen_view",
                      "screenName": "home",
                      "occurredAt": "%s",
                      "properties": {}
                    },
                    {
                      "eventId": "session-a-day7",
                      "eventName": "quick_ask_tapped",
                      "occurredAt": "%s",
                      "properties": {
                        "source": "mentor"
                      }
                    },
                    {
                      "eventId": "session-a-day30",
                      "eventName": "screen_view",
                      "screenName": "growth",
                      "occurredAt": "%s",
                      "properties": {}
                    }
                  ]
                }
                """.formatted(isoDaysAgo(40), isoDaysAgo(39), isoDaysAgo(33), isoDaysAgo(10)));

        postAnalyticsEvents(sessionB, """
                {
                  "events": [
                    {
                      "eventId": "session-b-open",
                      "eventName": "app_opened",
                      "occurredAt": "%s",
                      "properties": {}
                    },
                    {
                      "eventId": "session-b-day1",
                      "eventName": "screen_view",
                      "screenName": "discover",
                      "occurredAt": "%s",
                      "properties": {}
                    }
                  ]
                }
                """.formatted(isoDaysAgo(40), isoDaysAgo(39)));

        postAnalyticsEvents(sessionC, """
                {
                  "events": [
                    {
                      "eventId": "session-c-open",
                      "eventName": "app_opened",
                      "occurredAt": "%s",
                      "properties": {}
                    },
                    {
                      "eventId": "session-c-day1",
                      "eventName": "screen_view",
                      "screenName": "home",
                      "occurredAt": "%s",
                      "properties": {}
                    },
                    {
                      "eventId": "session-c-day7",
                      "eventName": "screen_view",
                      "screenName": "garden",
                      "occurredAt": "%s",
                      "properties": {}
                    }
                  ]
                }
                """.formatted(isoDaysAgo(8), isoDaysAgo(7), isoDaysAgo(1)));

        mockMvc.perform(get("/api/v1/analytics/retention")
                .header("X-App-Version", "1.0.0+1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.windows[0].days").value(1))
                .andExpect(jsonPath("$.windows[0].cohortUsers").value(3))
                .andExpect(jsonPath("$.windows[0].retainedUsers").value(3))
                .andExpect(jsonPath("$.windows[0].retentionRate").value(1.0))
                .andExpect(jsonPath("$.windows[1].days").value(7))
                .andExpect(jsonPath("$.windows[1].cohortUsers").value(3))
                .andExpect(jsonPath("$.windows[1].retainedUsers").value(2))
                .andExpect(jsonPath("$.windows[1].retentionRate").value(0.6666666666666666))
                .andExpect(jsonPath("$.windows[2].days").value(30))
                .andExpect(jsonPath("$.windows[2].cohortUsers").value(2))
                .andExpect(jsonPath("$.windows[2].retainedUsers").value(1))
                .andExpect(jsonPath("$.windows[2].retentionRate").value(0.5));
    }

    private void postAnalyticsEvents(String sessionId, String body) throws Exception {
        mockMvc.perform(post("/api/v1/analytics/events")
                .header("X-App-Version", "1.0.0+1")
                .header("X-Session-Id", sessionId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(body))
                .andExpect(status().isOk());
    }

    private String createSession() throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/auth/session"))
                .andExpect(status().isOk())
                .andReturn();

        String body = result.getResponse().getContentAsString();
        return body.replace("{\"sessionId\":\"", "").replace("\"}", "");
    }

    private String isoDaysAgo(int daysAgo) {
        return OffsetDateTime.now(ZoneOffset.UTC)
                .minusDays(daysAgo)
                .withHour(12)
                .withMinute(0)
                .withSecond(0)
                .withNano(0)
                .toInstant()
                .toString();
    }
}