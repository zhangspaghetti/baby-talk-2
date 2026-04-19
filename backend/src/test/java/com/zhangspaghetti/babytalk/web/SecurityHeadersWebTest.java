package com.zhangspaghetti.babytalk.web;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

/**
 * 验证所有 /api/** 响应包含标准安全响应头。
 */
@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:h2:mem:security-headers-test;MODE=PostgreSQL;DB_CLOSE_DELAY=-1;DATABASE_TO_UPPER=false",
        "spring.datasource.username=sa",
        "spring.datasource.password=",
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "app.mentor.provider-mode=dev"
})
@AutoConfigureMockMvc
class SecurityHeadersWebTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void apiResponsesContainAllSecurityHeaders() throws Exception {
        // 使用 POST /api/v1/auth/challenges 端点——即使请求体无效也能验证安全头
        // 因为安全头在 filter 层设置，早于业务逻辑
        mockMvc.perform(post("/api/v1/auth/challenges")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"phoneNumber\":\"13800138000\"}"))
                .andExpect(status().isCreated())
                .andExpect(header().string("Content-Security-Policy",
                        "default-src 'none'; frame-ancestors 'none'"))
                .andExpect(header().string("X-Content-Type-Options", "nosniff"))
                .andExpect(header().string("X-Frame-Options", "DENY"))
                .andExpect(header().string("Strict-Transport-Security",
                        "max-age=31536000; includeSubDomains"))
                .andExpect(header().string("Referrer-Policy",
                        "strict-origin-when-cross-origin"))
                .andExpect(header().string("Permissions-Policy",
                        "camera=(), microphone=(), geolocation=()"));
    }

    @Test
    void securityHeadersPresentOnErrorResponses() throws Exception {
        // 验证即使请求失败（400），安全头仍然存在
        mockMvc.perform(post("/api/v1/auth/challenges")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"phoneNumber\":\"12345\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(header().string("Content-Security-Policy",
                        "default-src 'none'; frame-ancestors 'none'"))
                .andExpect(header().string("X-Content-Type-Options", "nosniff"))
                .andExpect(header().string("X-Frame-Options", "DENY"))
                .andExpect(header().string("Strict-Transport-Security",
                        "max-age=31536000; includeSubDomains"))
                .andExpect(header().string("Referrer-Policy",
                        "strict-origin-when-cross-origin"))
                .andExpect(header().string("Permissions-Policy",
                        "camera=(), microphone=(), geolocation=()"));
    }

    @Test
    void securityHeadersPresentOnVersionRejection() throws Exception {
        // 验证版本拦截器拒绝请求时安全头也存在
        // (Filter 在 Interceptor 之前执行，所以即使拦截器返回 426 也有安全头)
        mockMvc.perform(post("/api/v1/auth/challenges")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "0.1.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"phoneNumber\":\"13800138000\"}"))
                .andExpect(status().isUpgradeRequired())
                .andExpect(header().string("X-Content-Type-Options", "nosniff"))
                .andExpect(header().string("X-Frame-Options", "DENY"));
    }
}
