package com.zhangspaghetti.babytalk;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import com.zhangspaghetti.babytalk.config.MentorProperties;
import com.zhangspaghetti.babytalk.palace.PalaceHybridRetrievalService;
import com.zhangspaghetti.babytalk.service.MentorProvider;
import com.zhangspaghetti.babytalk.service.SpringAiMentorProvider;
import io.minio.MinioClient;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.ChatClient.CallResponseSpec;
import org.springframework.ai.chat.client.ChatClient.ChatClientRequestSpec;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "app.mentor.provider-mode=dev",
        "app.mentor.search-mode=rag",
        "app.mentor.rate-limit-max-requests=10"
})
@AutoConfigureMockMvc(addFilters = false)
class MentorChatIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private MentorProperties mentorProperties;

    @Autowired
    private PalaceHybridRetrievalService palaceHybridRetrievalService;

    @MockitoBean
    private MentorProvider mentorProvider;

    @MockitoBean
    private EmbeddingModel embeddingModel;

    @MockitoBean
    private MinioClient minioClient;

    private static final float[] FIXED_QUERY_VECTOR;

    static {
        FIXED_QUERY_VECTOR = new float[1536];
        float value = 1.0f / (float) Math.sqrt(1536);
        for (int i = 0; i < FIXED_QUERY_VECTOR.length; i++) {
            FIXED_QUERY_VECTOR[i] = value;
        }
    }

    @BeforeEach
    void setUp() {
        resetDatabase(jdbcTemplate);
        jdbcTemplate.execute("TRUNCATE TABLE palace_query_traces, palace_bridge_edges, palace_projection_version, palace_rooms RESTART IDENTITY CASCADE");
        jdbcTemplate.execute("DELETE FROM vector_store");
        when(embeddingModel.embed(anyString())).thenReturn(FIXED_QUERY_VECTOR);
        when(mentorProvider.respond(any())).thenAnswer(invocation -> {
            MentorProvider.ProviderRequest request = invocation.getArgument(0);
            return buildDelegatingProvider().respond(request);
        });

        seedChunk("00000000-0000-0000-0000-0000000000a1", "Mirror the baby's babble, then pause for a response.", "0-3");
        seedChunk("00000000-0000-0000-0000-0000000000a2", "Use one short phrase and wait for eye contact.", "1-3");
    }

    @Test
    void testMentorChatWithChildAgeProducesTrace() throws Exception {
        int beforeCount = queryTraceCount();

        mockMvc.perform(post("/api/v1/mentor/chat")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-trace-age",
                                  "prompt":"How should I respond to babble?",
                                  "surface":"home",
                                  "mode":"single_turn",
                                  "correlationId":"corr-trace-age-6",
                                  "childAgeMonths":6
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value("ok"))
                .andExpect(jsonPath("$.phase").value("response_delivered"))
                .andExpect(jsonPath("$.fallbackUsed").value(false))
                .andExpect(jsonPath("$.responseText").isString());

        assertThat(queryTraceCount()).isEqualTo(beforeCount + 1);
        assertThat(lastTemporalRule()).isNotBlank().isNotEqualTo("skipped");
        assertThat(lastCandidatesJson()).contains("Mirror the baby's babble");
    }

    @Test
    void testMentorChatWithNullChildAgeSkipsBoost() throws Exception {
        int beforeCount = queryTraceCount();

        mockMvc.perform(post("/api/v1/mentor/chat")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-trace-null",
                                  "prompt":"How should I respond to babble?",
                                  "surface":"home",
                                  "mode":"single_turn",
                                  "correlationId":"corr-trace-null"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value("ok"))
                .andExpect(jsonPath("$.phase").value("response_delivered"))
                .andExpect(jsonPath("$.fallbackUsed").value(false));

        assertThat(queryTraceCount()).isEqualTo(beforeCount + 1);
        assertThat(lastTemporalRule()).isEqualTo("skipped");
        assertThat(lastCandidatesJson()).contains("Use one short phrase");
    }

    @Test
    void testNoRegressionWithNullChildAge() throws Exception {
        mockMvc.perform(post("/api/v1/mentor/chat")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-regression-null-age",
                                  "prompt":"Give me one short response for baby babble.",
                                  "surface":"home",
                                  "mode":"single_turn",
                                  "correlationId":"corr-regression-null-age"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value("ok"))
                .andExpect(jsonPath("$.phase").value("response_delivered"))
                .andExpect(jsonPath("$.responseText").isString());

        assertThat(lastTemporalRule()).isEqualTo("skipped");
        assertThat(queryTraceCount()).isGreaterThan(0);
        assertThat(jdbcTemplate.queryForObject("select count(*) from mentor_turns", Integer.class)).isEqualTo(1);
    }

    private MentorProvider buildDelegatingProvider() {
        ChatClient chatClient = mock(ChatClient.class);
        ChatClientRequestSpec requestSpec = mock(ChatClientRequestSpec.class);
        CallResponseSpec callResponseSpec = mock(CallResponseSpec.class);

        when(chatClient.prompt()).thenReturn(requestSpec);
        when(requestSpec.system(anyString())).thenReturn(requestSpec);
        when(requestSpec.user(anyString())).thenReturn(requestSpec);
        when(requestSpec.advisors(any(java.util.function.Consumer.class))).thenReturn(requestSpec);
        when(requestSpec.tools(any())).thenReturn(requestSpec);
        when(requestSpec.call()).thenReturn(callResponseSpec);
        when(callResponseSpec.content()).thenReturn("先模仿宝宝的声音，再停一下等他回应。（来源：《测试育儿书》）");

        return new SpringAiMentorProvider(chatClient, mentorProperties, null, palaceHybridRetrievalService);
    }

    private int queryTraceCount() {
        return jdbcTemplate.queryForObject("select count(*) from palace_query_traces", Integer.class);
    }

    private String lastTemporalRule() {
        return jdbcTemplate.queryForObject(
                "select temporal_rule_applied from palace_query_traces order by queried_at desc limit 1",
                String.class);
    }

    private String lastCandidatesJson() {
        return jdbcTemplate.queryForObject(
                "select candidates_json::text from palace_query_traces order by queried_at desc limit 1",
                String.class);
    }

    private void seedChunk(String id, String content, String ageRange) {
        jdbcTemplate.update(
                "INSERT INTO vector_store (id, content, metadata, embedding) VALUES (?::uuid, ?, ?::jsonb, ?::vector)",
                id,
                content,
                """
                        {"wing":"language_development","room":"early_communication","age_range":"%s","source_book":"《测试育儿书》"}
                        """.formatted(ageRange),
                buildVectorLiteral(FIXED_QUERY_VECTOR));
    }

    private static String buildVectorLiteral(float[] vector) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < vector.length; i++) {
            if (i > 0) {
                sb.append(',');
            }
            sb.append(vector[i]);
        }
        sb.append(']');
        return sb.toString();
    }
}
