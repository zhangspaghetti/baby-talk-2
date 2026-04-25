package com.zhangspaghetti.babytalk.web;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import com.zhangspaghetti.babytalk.service.MentorProvider;
import org.junit.jupiter.api.Test;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

/**
 * Practice Generate API 的 MockMvc 测试。
 * mock MentorProvider 返回合法 JSON → 验证 200 + activities/phrases 结构；
 * mock 返回非 JSON → 验证 fallback 处理（空 activities）。
 */
@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "app.mentor.provider-mode=dev",
        "app.mentor.practice-response-max-length=2000"
})
@AutoConfigureMockMvc(addFilters = false)
class PracticeGenerateControllerTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private MentorProvider mentorProvider;

    @MockitoBean
    private EmbeddingModel embeddingModel;

    // 合法 JSON — LLM 返回结构化练习数据
    private static final String VALID_PRACTICE_JSON = """
            {
              "activities": [
                {
                  "title": "早安问候",
                  "summary": "用简单的英语问候开始新的一天",
                  "sceneTag": "morning_routine",
                  "coachTip": "每天早上重复同一句，宝宝会逐渐熟悉（来源：《亲子英语启蒙》）",
                  "phrases": [
                    {
                      "english": "Good morning, baby!",
                      "chinese": "早上好，宝宝！",
                      "pronunciation": "古德 莫宁，贝比",
                      "difficulty": "easy"
                    },
                    {
                      "english": "Time to wake up!",
                      "chinese": "该起床了！",
                      "pronunciation": "泰姆 图 威克 阿普",
                      "difficulty": "easy"
                    }
                  ]
                }
              ]
            }
            """;

    @Test
    void validJsonResponseReturns200WithActivitiesAndPhrases() throws Exception {
        when(mentorProvider.respond(any()))
                .thenReturn(new MentorProvider.ProviderResponse(VALID_PRACTICE_JSON, "practice response"));

        mockMvc.perform(post("/api/v1/mentor/practice/generate")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId": "install-practice-test",
                                  "surface": "practice",
                                  "babyAgeMonths": 12,
                                  "sceneTag": "morning_routine"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.activities").isArray())
                .andExpect(jsonPath("$.activities.length()").value(1))
                .andExpect(jsonPath("$.activities[0].title").value("早安问候"))
                .andExpect(jsonPath("$.activities[0].sceneTag").value("morning_routine"))
                .andExpect(jsonPath("$.activities[0].coachTip").isString())
                .andExpect(jsonPath("$.activities[0].phrases").isArray())
                .andExpect(jsonPath("$.activities[0].phrases.length()").value(2))
                .andExpect(jsonPath("$.activities[0].phrases[0].english").value("Good morning, baby!"))
                .andExpect(jsonPath("$.activities[0].phrases[0].chinese").value("早上好，宝宝！"))
                .andExpect(jsonPath("$.activities[0].phrases[0].difficulty").value("easy"));
    }

    @Test
    void nonJsonResponseReturnsFallbackEmptyActivities() throws Exception {
        when(mentorProvider.respond(any()))
                .thenReturn(new MentorProvider.ProviderResponse(
                        "这是一段普通文本，不是 JSON 格式的响应。", "plain text response"));

        mockMvc.perform(post("/api/v1/mentor/practice/generate")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId": "install-practice-fallback",
                                  "surface": "practice",
                                  "babyAgeMonths": 18,
                                  "sceneTag": "bedtime"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.activities").isArray())
                .andExpect(jsonPath("$.activities.length()").value(0));
    }

    @Test
    void jsonWrappedInCodeFenceIsParsedCorrectly() throws Exception {
        // LLM 有时会把 JSON 包裹在 markdown code fence 中
        String wrappedJson = """
                Here is the practice data:
                ```json
                {
                  "activities": [
                    {
                      "title": "吃饭时间",
                      "summary": "用餐时的简单英语表达",
                      "sceneTag": "mealtime",
                      "coachTip": "指着食物说英文，宝宝更容易理解",
                      "phrases": [
                        {
                          "english": "Yummy!",
                          "chinese": "好吃！",
                          "pronunciation": "亚米",
                          "difficulty": "easy"
                        }
                      ]
                    }
                  ]
                }
                ```
                """;
        when(mentorProvider.respond(any()))
                .thenReturn(new MentorProvider.ProviderResponse(wrappedJson, "code fence response"));

        mockMvc.perform(post("/api/v1/mentor/practice/generate")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId": "install-practice-codefence",
                                  "surface": "practice",
                                  "babyAgeMonths": 24,
                                  "sceneTag": "mealtime"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.activities").isArray())
                .andExpect(jsonPath("$.activities.length()").value(1))
                .andExpect(jsonPath("$.activities[0].title").value("吃饭时间"))
                .andExpect(jsonPath("$.activities[0].phrases[0].english").value("Yummy!"));
    }

    @Test
    void missingSurfaceReturnsBadRequest() throws Exception {
        mockMvc.perform(post("/api/v1/mentor/practice/generate")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId": "install-practice-nosurface",
                                  "surface": "",
                                  "babyAgeMonths": 12,
                                  "sceneTag": "morning"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("missing_surface"));
    }

    @Test
    void wrongSurfaceReturnsBadRequest() throws Exception {
        mockMvc.perform(post("/api/v1/mentor/practice/generate")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId": "install-practice-wrongsurface",
                                  "surface": "home",
                                  "babyAgeMonths": 12,
                                  "sceneTag": "morning"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_surface"));
    }

    @Test
    void missingInstallationIdReturnsBadRequest() throws Exception {
        mockMvc.perform(post("/api/v1/mentor/practice/generate")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId": "",
                                  "surface": "practice",
                                  "babyAgeMonths": 12,
                                  "sceneTag": "morning"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("missing_installationId"));
    }

    @Test
    void outOfRangeBabyAgeReturnsBadRequest() throws Exception {
        mockMvc.perform(post("/api/v1/mentor/practice/generate")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId": "install-practice-age",
                                  "surface": "practice",
                                  "babyAgeMonths": 48,
                                  "sceneTag": "morning"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_baby_age_months"));
    }

    @Test
    void tooLongSceneTagReturnsBadRequest() throws Exception {
        var sceneTag = "a".repeat(65);

        mockMvc.perform(post("/api/v1/mentor/practice/generate")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId": "install-practice-scene",
                                  "surface": "practice",
                                  "babyAgeMonths": 12,
                                  "sceneTag": "%s"
                                }
                                """.formatted(sceneTag)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_sceneTag"));
    }

    @Test
    void providerTimeoutReturnsGatewayTimeout() throws Exception {
        when(mentorProvider.respond(any()))
                .thenThrow(new MentorProvider.ProviderTimeoutException("timeout"));

        mockMvc.perform(post("/api/v1/mentor/practice/generate")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId": "install-timeout",
                                  "surface": "practice",
                                  "babyAgeMonths": 12,
                                  "sceneTag": "morning"
                                }
                                """))
                .andExpect(status().isGatewayTimeout())
                .andExpect(jsonPath("$.code").value("provider_timeout"));
    }

    @Test
    void providerUnavailableReturnsServiceUnavailable() throws Exception {
        when(mentorProvider.respond(any()))
                .thenThrow(new MentorProvider.ProviderUnavailableException("unavailable"));

        mockMvc.perform(post("/api/v1/mentor/practice/generate")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId": "install-unavailable",
                                  "surface": "practice",
                                  "babyAgeMonths": 12,
                                  "sceneTag": "morning"
                                }
                                """))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value("provider_unavailable"));
    }

    @Test
    void providerMalformedResponseReturnsFallbackEmptyActivities() throws Exception {
        when(mentorProvider.respond(any()))
                .thenThrow(new MentorProvider.ProviderMalformedResponseException("malformed"));

        mockMvc.perform(post("/api/v1/mentor/practice/generate")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId": "install-malformed",
                                  "surface": "practice",
                                  "babyAgeMonths": 12,
                                  "sceneTag": "morning"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.activities").isArray())
                .andExpect(jsonPath("$.activities.length()").value(0));
    }

    @Test
    void nullSceneTagStillWorks() throws Exception {
        when(mentorProvider.respond(any()))
                .thenReturn(new MentorProvider.ProviderResponse(VALID_PRACTICE_JSON, "practice response"));

        mockMvc.perform(post("/api/v1/mentor/practice/generate")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId": "install-no-scene",
                                  "surface": "practice",
                                  "babyAgeMonths": 6
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.activities").isArray())
                .andExpect(jsonPath("$.activities.length()").value(1));
    }
}
