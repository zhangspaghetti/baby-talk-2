package com.zhangspaghetti.babytalk;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import tools.jackson.databind.ObjectMapper;
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
 * RAG 模式 LLM 集成测试 — 验证 L1 预检索注入 + 来源引用链路。
 *
 * <p>测试流程：
 * <ol>
 *   <li>向量库预注入带明确来源书名的育儿内容</li>
 *   <li>RAG 模式下发起 mentor chat 请求（无工具调用，内容预注入 system prompt）</li>
 *   <li>验证 L1 预检索成功：system prompt 中包含参考知识块</li>
 *   <li>验证 LLM 在回复末尾标注了来源书名 {@code （来源：《...》）}</li>
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
        "app.mentor.ai-max-tokens=1500",
        "app.mentor.search-mode=rag"
})
@AutoConfigureMockMvc
@ActiveProfiles({"test", "llm-it"})
@Tag("llm-it")
@EnabledIfEnvironmentVariable(named = "SSY_API_KEY", matches = ".+")
class LlmRagIntegrationTest extends AbstractIntegrationTest {

    /** 测试专用书名，断言时匹配此字符串 */
    static final String SOURCE_BOOK = "早期语言发展实践手册";

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

        // 预注入带来源书名的育儿内容，供 L1 预检索注入 system prompt
        var doc = Document.builder()
                .text("宝宝哭的时候，家长最重要的第一步是放慢语速，只说一句简短的话：" +
                      "\"I'm here with you.\" 避免立刻给玩具转移注意力，" +
                      "这会让宝宝无法学习表达情绪。先认可情绪再提供安慰是早期语言发展的黄金法则。")
                .metadata(Map.of(
                        "source_book", "《" + SOURCE_BOOK + "》",
                        "room_id", "home",
                        "chunk_id", "rag-seed-001"
                ))
                .build();
        vectorStore.add(List.of(doc));
    }

    @Test
    @DisplayName("RAG 模式 — L1 预检索注入来源内容，LLM 回复中标注书名")
    void ragMentorChatIncludesSourceCitationFromSeededContent() throws Exception {
        var result = mockMvc.perform(post("/api/v1/mentor/chat")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-llm-rag-001",
                                  "prompt":"宝宝哭了我该怎么回应",
                                  "surface":"home",
                                  "mode":"single_turn",
                                  "correlationId":"corr-llm-rag-001"
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

        // 验证响应非空
        assertThat(responseText).isNotBlank();

        // 验证 LLM 引用了来源书名（L1 注入了参考知识，LLM 指令要求标注来源）
        assertThat(responseText)
                .as("RAG 模式下 LLM 应在回复中标注来源书名 '%s'，实际回复: %s", SOURCE_BOOK, responseText)
                .contains(SOURCE_BOOK);
    }
}
