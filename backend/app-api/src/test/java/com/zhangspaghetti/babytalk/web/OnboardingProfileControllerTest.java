package com.zhangspaghetti.babytalk.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import com.zhangspaghetti.babytalk.service.AuthConsentSyncService;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810"
})
@AutoConfigureMockMvc
class OnboardingProfileControllerTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private AuthConsentSyncService authConsentSyncService;

    @Test
    void getAndPutRequireJwt() throws Exception {
        mockMvc.perform(get("/api/v1/onboarding/profile")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("consumer_authentication_required"));

        mockMvc.perform(put("/api/v1/onboarding/profile")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(draftJson(null, "小满")))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("consumer_authentication_required"));
    }

    @Test
    void acceptedSessionWithNoProfileReturns404() throws Exception {
        var session = createAcceptedSession("13800138100", "install-onboarding-1");

        mockMvc.perform(get("/api/v1/onboarding/profile")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken())))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("onboarding_profile_not_found"));
    }

    @Test
    void nonAcceptedSessionReturnsConsentRequiredForGetAndPut() throws Exception {
        var session = createSignedInSession("13800138101", "install-onboarding-2");

        mockMvc.perform(get("/api/v1/onboarding/profile")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken())))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("consent_required"));

        mockMvc.perform(put("/api/v1/onboarding/profile")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(draftJson(null, "小满")))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("consent_required"));
    }

    @Test
    void putDraftCreatesProfileAndGetReturnsIt() throws Exception {
        var session = createAcceptedSession("13800138102", "install-onboarding-3");

        mockMvc.perform(put("/api/v1/onboarding/profile")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(draftJson(null, "小满")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.babyProfileId").isNotEmpty())
                .andExpect(jsonPath("$.babyName").value("小满"))
                .andExpect(jsonPath("$.ageRange").value("m7_11"))
                .andExpect(jsonPath("$.onboardingState").value("draft"))
                .andExpect(jsonPath("$.version").value(1));

        mockMvc.perform(get("/api/v1/onboarding/profile")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.babyName").value("小满"))
                .andExpect(jsonPath("$.version").value(1));
    }

    @Test
    void putCompletedCreatesProfileWithStarterFields() throws Exception {
        var session = createAcceptedSession("13800138103", "install-onboarding-4");
        var completedAt = completedAtNow();

        mockMvc.perform(put("/api/v1/onboarding/profile")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(completedJson(null, "小满", completedAt)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.parentGoal").value("calmer_care"))
                .andExpect(jsonPath("$.starter.sceneId").value("daily_care"))
                .andExpect(jsonPath("$.starter.source").value("catalog"))
                .andExpect(jsonPath("$.onboardingState").value("completed"))
                .andExpect(jsonPath("$.onboardingCompletedAt").value(completedAt));
    }

    @Test
    void updateRequiresExpectedVersionAndIncrementsOnMatch() throws Exception {
        var session = createAcceptedSession("13800138104", "install-onboarding-5");
        createDraft(session.accessToken(), "小满");

        mockMvc.perform(put("/api/v1/onboarding/profile")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(draftJson(null, "小满二号")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("expected_version_required"));

        mockMvc.perform(put("/api/v1/onboarding/profile")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(completedJson(1, "小满二号", completedAtNow())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.babyName").value("小满二号"))
                .andExpect(jsonPath("$.version").value(2));
    }

    @Test
    void staleExpectedVersionReturnsConflictWithoutBabyNameInError() throws Exception {
        var session = createAcceptedSession("13800138105", "install-onboarding-6");
        createDraft(session.accessToken(), "小满");

        var result = mockMvc.perform(put("/api/v1/onboarding/profile")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(draftJson(2, "秘密宝宝")))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("version_conflict"))
                .andExpect(jsonPath("$.details.expectedVersion").value(2))
                .andExpect(jsonPath("$.details.currentVersion").value(1))
                .andReturn();

        assertThat(result.getResponse().getContentAsString()).doesNotContain("秘密宝宝");
    }

    @Test
    void validationFailuresReturnStableCodes() throws Exception {
        var session = createAcceptedSession("13800138106", "install-onboarding-7");

        mockMvc.perform(put("/api/v1/onboarding/profile")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "babyName":"小满",
                                  "parentGoal":"calmer_care",
                                  "onboardingState":"draft"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("validation_failed"));

        mockMvc.perform(put("/api/v1/onboarding/profile")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "babyName":"小满",
                                  "ageRange":"m7_11",
                                  "parentGoal":"calmer_care",
                                  "onboardingState":"completed",
                                  "completedAt":"2026-07-03T02:00:00Z"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("completed_profile_missing_starter"));
    }

    private void createDraft(String accessToken, String babyName) throws Exception {
        mockMvc.perform(put("/api/v1/onboarding/profile")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(draftJson(null, babyName)))
                .andExpect(status().isOk());
    }

    private AuthConsentSyncService.SessionResponse createSignedInSession(String phoneNumber, String installationId) {
        var challenge = authConsentSyncService.createChallenge(phoneNumber);
        return authConsentSyncService.verifyChallenge(challenge.challengeId(), "246810", installationId);
    }

    private AuthConsentSyncService.SessionResponse createAcceptedSession(String phoneNumber, String installationId) {
        var session = createSignedInSession(phoneNumber, installationId);
        authConsentSyncService.acceptConsent(session.sessionId(), "pipl-v1");
        return session;
    }

    private String draftJson(Integer expectedVersion, String babyName) throws Exception {
        var root = objectMapper.createObjectNode();
        if (expectedVersion != null) {
            root.put("expectedVersion", expectedVersion);
        }
        root.put("babyName", babyName);
        root.put("ageRange", "m7_11");
        root.put("onboardingState", "draft");
        root.put("clientTraceId", "onb_profile_001");
        return objectMapper.writeValueAsString(root);
    }

    private String completedJson(Integer expectedVersion, String babyName, String completedAt) throws Exception {
        var root = objectMapper.createObjectNode();
        if (expectedVersion != null) {
            root.put("expectedVersion", expectedVersion);
        }
        root.put("babyName", babyName);
        root.put("ageRange", "m7_11");
        root.put("parentGoal", "calmer_care");
        root.put("onboardingState", "completed");
        root.put("completedAt", completedAt);
        root.put("clientTraceId", "onb_profile_001");
        var starter = root.putObject("starter");
        starter.put("sceneId", "daily_care");
        starter.put("momentId", "bath_time");
        starter.put("activityId", "bath_time");
        starter.put("utteranceId", "bath_time_warm_water");
        starter.put("phraseId", "bath_time_warm_water");
        starter.put("source", "catalog");
        return objectMapper.writeValueAsString(root);
    }

    private String bearer(String accessToken) {
        return "Bearer " + accessToken;
    }

    private String completedAtNow() {
        return Instant.now().minusSeconds(60).toString();
    }
}
