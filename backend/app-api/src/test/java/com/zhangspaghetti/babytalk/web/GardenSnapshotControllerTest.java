package com.zhangspaghetti.babytalk.web;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810"
})
@AutoConfigureMockMvc
class GardenSnapshotControllerTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void snapshotRequiresAuthentication() throws Exception {
        mockMvc.perform(get("/api/v1/garden/snapshot")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("consumer_authentication_required"));
    }
}
