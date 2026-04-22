package com.zhangspaghetti.babytalk;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

/**
 * LLM 集成测试 — 验证通过 SSY (胜算云) 中转站的真实 LLM / Embedding 调用链路。
 *
 * <p>仅当 {@code SSY_API_KEY} 环境变量存在时运行，否则自动跳过。
 * Token 消耗极小（prompt ≤ 10 tokens，max_tokens=80，embedding ≤ 3 tokens）。
 *
 * <p>本地运行：
 * <pre>
 *   $env:SSY_API_KEY="sk-xxx"
 *   .\bash.cmd -lc "cd backend && ./mvnw test -Dgroups='llm-it'"
 * </pre>
 *
 * <p>CI 中默认不执行（需显式设置 {@code SSY_API_KEY} 并加 {@code -Dgroups=llm-it}）。
 */
@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "app.mentor.rate-limit-max-requests=10",
        "app.kg.review-enabled=false",
        "app.mentor.ai-max-tokens=1500"
})
@AutoConfigureMockMvc
@ActiveProfiles({"test", "llm-it"})
@Tag("llm-it")
@EnabledIfEnvironmentVariable(named = "SSY_API_KEY", matches = ".+")
class LlmIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private EmbeddingModel embeddingModel;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void resetTables() {
        resetDatabase(jdbcTemplate);
    }

    @Test
    @DisplayName("Mentor 对话 — 真实调用 SSY/gpt-5-nano 并返回中文建议")
    void mentorChatReturnsRealLlmResponse() throws Exception {
        mockMvc.perform(post("/api/v1/mentor/chat")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-llm-it-001",
                                  "prompt":"宝宝哭了",
                                  "surface":"home",
                                  "mode":"single_turn",
                                  "correlationId":"corr-llm-it-001"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value("ok"))
                .andExpect(jsonPath("$.phase").value("response_delivered"))
                .andExpect(jsonPath("$.fallbackUsed").value(false))
                .andExpect(jsonPath("$.responseText").isString());
    }

    @Test
    @DisplayName("Embedding — text-embedding-3-small 返回正确维度的向量")
    void embeddingModelReturnsNonZeroVector() {
        float[] vector = embeddingModel.embed("宝宝");

        assertThat(vector).isNotNull();
        assertThat(vector).hasSize(1536);

        // 确认 API 真实返回了向量而非全零
        int nonZero = 0;
        for (float v : vector) {
            if (Math.abs(v) > 1e-6f) {
                nonZero++;
            }
        }
        assertThat(nonZero)
                .as("至少 100 个维度应为非零，当前非零数: %d", nonZero)
                .isGreaterThan(100);
    }
}
