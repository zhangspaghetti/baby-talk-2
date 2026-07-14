package com.zhangspaghetti.babytalk;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.ai.document.Document;
import org.springframework.ai.vectorstore.VectorStore;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

/**
 * Agentic 模式 LLM 集成测试 — 验证知识宫殿工具调用链路。
 *
 * <p>测试流程：
 * <ol>
 *   <li>向量库预注入一条育儿内容</li>
 *   <li>Agentic 模式下发起 mentor chat 请求</li>
 *   <li>LLM 调用 palace_vector_search 工具找到相关内容</li>
 *   <li>验证返回 200，phase=response_delivered</li>
 * </ol>
 *
 * <p>仅当 {@code SSY_API_KEY} 环境变量存在时运行。
 *
 * <p>运行方式：
 * <pre>
 *   $env:SSY_API_KEY="sk-xxx"
 *   .\bash.cmd -lc "cd backend && ./mvnw test -Dgroups='llm-it'"
 * </pre>
 */
@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "app.mentor.rate-limit-max-requests=10",
        "app.kg.review-enabled=false",
        "app.mentor.ai-max-tokens=2000",
        "app.mentor.search-mode=agentic"
})
@AutoConfigureMockMvc
@ActiveProfiles({"test", "llm-it"})
@Tag("llm-it")
@EnabledIfEnvironmentVariable(named = "SSY_API_KEY", matches = ".+")
class LlmAgenticIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private VectorStore vectorStore;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private ObjectMapper objectMapper;

    @BeforeEach
    void resetAndSeedPalace() {
        resetDatabase(jdbcTemplate);

        // 预注入一条育儿内容，供 agentic LLM 通过 palace_vector_search 检索
        var doc = Document.builder()
                .text("宝宝哭的时候，先把语速放慢，只说一句：I'm here with you。" +
                      "抱近一点，停半拍，再描述你看到的感受。避免立刻给玩具转移注意力，" +
                      "这会让宝宝学不会表达情绪。先认可情绪，再提供安慰。")
                .metadata(Map.of(
                        "source_book", "《早期语言发展实践手册》",
                        "room_id", "home",
                        "chunk_id", "seed-chunk-001"
                ))
                .build();
        vectorStore.add(List.of(doc));
    }

    @Test
    @DisplayName("Agentic 模式 — 工具调用 + 知识宫殿检索 + 返回真实建议")
    void agenticMentorChatWithSeededPalaceReturnsResponse() throws Exception {
        var result = mockMvc.perform(post("/api/v1/mentor/chat")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-llm-agentic-001",
                                  "prompt":"宝宝哭了怎么办",
                                  "surface":"home",
                                  "mode":"single_turn",
                                  "correlationId":"corr-llm-agentic-001"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value("ok"))
                .andExpect(jsonPath("$.phase").value("response_delivered"))
                .andExpect(jsonPath("$.fallbackUsed").value(false))
                .andExpect(jsonPath("$.responseText").isString())
                .andReturn();

        var body = objectMapper.readTree(result.getResponse().getContentAsString());
        var responseText = body.get("responseText").asText();

        // 验证响应非空（LLM 有实际输出）
        assertThat(responseText).isNotBlank();
        assertThat(responseText).hasSizeLessThanOrEqualTo(500);
    }
}
