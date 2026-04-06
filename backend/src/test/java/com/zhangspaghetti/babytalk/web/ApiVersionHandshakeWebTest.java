package com.zhangspaghetti.babytalk.web;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@AutoConfigureMockMvc
class ApiVersionHandshakeWebTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void versionEndpointReportsSupportedVersions() throws Exception {
        mockMvc.perform(get("/api/v1/config/version"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.currentVersion").value("1.0.0"))
                .andExpect(jsonPath("$.minSupportedVersion").value("1.0.0"))
                .andExpect(jsonPath("$.upgradeRequired").value(false));
    }

    @Test
    void bootstrapRejectsMissingVersionHeader() throws Exception {
        mockMvc.perform(get("/api/v1/app/bootstrap"))
                .andExpect(status().is(426))
                .andExpect(header().string("X-Min-Supported-Version", "1.0.0"))
                .andExpect(jsonPath("$.upgradeRequired").value(true))
                .andExpect(jsonPath("$.message").value("缺少 X-App-Version 请求头，请升级客户端后重试。"));
    }

    @Test
    void bootstrapAcceptsSupportedVersionHeader() throws Exception {
        MvcResult sessionResult = mockMvc.perform(post("/api/v1/auth/session"))
            .andExpect(status().isOk())
            .andReturn();

        String sessionId = sessionResult.getResponse().getContentAsString()
            .replace("{\"sessionId\":\"", "")
            .replace("\"}", "");

        mockMvc.perform(get("/api/v1/app/bootstrap")
                .header("X-App-Version", "1.0.0+1")
                .header("X-Session-Id", sessionId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.caregiverName").value("小明妈妈"));
    }
}