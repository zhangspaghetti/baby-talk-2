package com.zhangspaghetti.babytalk.web;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810"
})
@AutoConfigureMockMvc
class GardenFertilizerControllerTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void resetTables() {
        resetDatabase(jdbcTemplate);
    }

    @Test
    void getShouldReturnInitialFertilizerState() throws Exception {
        var accessToken = signInAndGetAccessToken("13800138000", "fert-install-1");

        mockMvc.perform(get("/api/v1/garden/fertilizer")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.availableCount").value(0))
                .andExpect(jsonPath("$.appliedCount").value(0));
    }

    @Test
    void claimShouldBeIdempotentByRequestId() throws Exception {
        var accessToken = signInAndGetAccessToken("13800138001", "fert-install-2");

        mockMvc.perform(post("/api/v1/garden/fertilizer/claim")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "eventKey":"e1",
                                  "requestId":"r-claim-1"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.idempotent").value(false))
                .andExpect(jsonPath("$.availableCount").value(1));

        mockMvc.perform(post("/api/v1/garden/fertilizer/claim")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "eventKey":"e1",
                                  "requestId":"r-claim-1"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.idempotent").value(true))
                .andExpect(jsonPath("$.availableCount").value(1));
    }

    @Test
    void applyShouldBeIdempotentByRequestId() throws Exception {
        var accessToken = signInAndGetAccessToken("13800138002", "fert-install-3");

        mockMvc.perform(post("/api/v1/garden/fertilizer/claim")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "eventKey":"e2",
                                  "requestId":"r-claim-2"
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/garden/fertilizer/apply")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "requestId":"r-apply-1"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.idempotent").value(false))
                .andExpect(jsonPath("$.availableCount").value(0))
                .andExpect(jsonPath("$.appliedCount").value(1));

        mockMvc.perform(post("/api/v1/garden/fertilizer/apply")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "requestId":"r-apply-1"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.idempotent").value(true))
                .andExpect(jsonPath("$.availableCount").value(0))
                .andExpect(jsonPath("$.appliedCount").value(1));
    }

    private String signInAndGetAccessToken(String phoneNumber, String installationId) throws Exception {
        var challengeId = createChallenge(phoneNumber);
        var result = mockMvc.perform(post("/api/v1/auth/verify")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "challengeId":"%s",
                                  "verificationCode":"246810",
                                  "installationId":"%s"
                                }
                                """.formatted(challengeId, installationId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andReturn();
        var body = readJson(result.getResponse().getContentAsString());
        return body.get("accessToken").asText();
    }

    private String createChallenge(String phoneNumber) throws Exception {
        var result = mockMvc.perform(post("/api/v1/auth/challenges")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"phoneNumber":"%s"}
                                """.formatted(phoneNumber)))
                .andExpect(status().isCreated())
                .andReturn();
        return readJson(result.getResponse().getContentAsString()).get("challengeId").asText();
    }

    private JsonNode readJson(String rawJson) throws Exception {
        return objectMapper.readTree(rawJson);
    }

    private String bearer(String accessToken) {
        return "Bearer " + accessToken;
    }
}
