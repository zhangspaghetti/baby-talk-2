package com.zhangspaghetti.babytalk.web;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import com.zhangspaghetti.babytalk.service.AuthConsentSyncService;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810"
})
@AutoConfigureMockMvc
class GrowthSummaryControllerTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private AuthConsentSyncService authConsentSyncService;

    @Test
    void shouldReturnSummaryForAllowedPeriods() throws Exception {
        var installationId = "growth-install-1";
        var session = createAcceptedSession("13800139000", installationId);
        authConsentSyncService.ingestEvents(
                session.sessionId(),
            installationId,
                java.util.List.of(new AuthConsentSyncService.SyncEventRequest(
                installationId + ":evt-1",
                        "evt-1",
                installationId,
                        "daily_care",
                        "bath_time",
                        "bath_time_warm_water",
                        "calm",
                        Instant.now()
                ))
        );

        var accessToken = session.accessToken();
            for (var period : java.util.List.of("week", "month", "year")) {
                mockMvc.perform(get("/api/v1/growth/summary")
                        .param("period", period)
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.period").value(period));
            }
    }

            @Test
            void shouldReturn400WhenPeriodMissing() throws Exception {
            var installationId = "growth-install-2";
            var session = createAcceptedSession("13800139001", installationId);

            mockMvc.perform(get("/api/v1/growth/summary")
                    .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                    .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_period"));
            }

            @Test
            void shouldReturn400WhenPeriodInvalid() throws Exception {
            var installationId = "growth-install-3";
            var session = createAcceptedSession("13800139002", installationId);

            mockMvc.perform(get("/api/v1/growth/summary")
                    .param("period", "quarter")
                    .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                    .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_period"));
            }

    private AuthConsentSyncService.SessionResponse createAcceptedSession(String phoneNumber, String installationId) {
        var challenge = authConsentSyncService.createChallenge(phoneNumber);
        var session = authConsentSyncService.verifyChallenge(challenge.challengeId(), "246810", installationId);
        authConsentSyncService.acceptConsent(session.sessionId(), "pipl-v1");
        return session;
    }

    private String bearer(String accessToken) {
        return "Bearer " + accessToken;
    }
}