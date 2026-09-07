package com.zhangspaghetti.babytalk.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhangspaghetti.babytalk.practice.scene.SceneGenerationRequest;
import com.zhangspaghetti.babytalk.practice.scene.SceneGenerationResponse;
import com.zhangspaghetti.babytalk.practice.scene.SceneGenerationService;
import java.util.stream.Stream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.springframework.http.MediaType;
import org.springframework.http.converter.json.JacksonJsonHttpMessageConverter;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.test.web.servlet.request.RequestPostProcessor;
import tools.jackson.databind.json.JsonMapper;

class SceneGenerationControllerTest {

    private MockMvc mockMvc;

    private SceneGenerationService service;

    private tools.jackson.databind.ObjectMapper objectMapper;

    @BeforeEach
    void reset() {
        service = org.mockito.Mockito.mock(SceneGenerationService.class);
        objectMapper = JsonMapper.builder().build();
        mockMvc = MockMvcBuilders.standaloneSetup(new SceneGenerationController(service))
                .setControllerAdvice(new ApiExceptionHandler())
                .setMessageConverters(new JacksonJsonHttpMessageConverter((JsonMapper) objectMapper))
                .build();
        org.mockito.Mockito.reset(service);
        when(service.generate(any(), eq("session-1"))).thenReturn(response("custom"));
    }

    @Test
    void validCustomRequestPassesOnlyStrictRequestAndSidToService() throws Exception {
        mockMvc.perform(post("/api/v1/practice/scene-generations")
                        .with(authenticationWithSid("session-1"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"source":{"type":"custom","text":"洗澡时不想碰水"},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.generatedContentId").value("pgc-response"))
                .andExpect(jsonPath("$.source.type").value("custom"));

        var request = org.mockito.ArgumentCaptor.forClass(SceneGenerationRequest.class);
        verify(service).generate(request.capture(), eq("session-1"));
        assertThat(request.getValue().source().type()).isEqualTo("custom");
        assertThat(request.getValue().source().text()).isEqualTo("洗澡时不想碰水");
    }

    @Test
    void validPresetRequestDoesNotAcceptTextOverride() throws Exception {
        when(service.generate(any(), eq("session-1"))).thenReturn(response("preset"));
        mockMvc.perform(post("/api/v1/practice/scene-generations")
                        .with(authenticationWithSid("session-1"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"source":{"type":"preset","presetSceneId":"bath_time"},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.source.type").value("preset"));
    }

    @ParameterizedTest(name = "invalid strict body: {0}")
    @MethodSource("invalidBodies")
    void malformedOrMixedTaggedUnionReturnsOnePrivacySafeErrorAndDoesNotCallService(
            String name, String body) throws Exception {
        mockMvc.perform(post("/api/v1/practice/scene-generations")
                        .with(authenticationWithSid("session-1"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_scene_source"))
                .andExpect(jsonPath("$.details").isEmpty());
        verify(service, never()).generate(any(), any());
    }

    static Stream<Arguments> invalidBodies() {
        return Stream.of(
                Arguments.of("top-level unknown", """
                        {"source":{"type":"custom","text":"洗澡时不想碰水"},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1","babyProfileId":"forbidden"}
                        """),
                Arguments.of("forbidden age range", """
                        {"source":{"type":"custom","text":"洗澡时不想碰水"},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1","ageRange":"m7_11"}
                        """),
                Arguments.of("forbidden parent goal", """
                        {"source":{"type":"custom","text":"洗澡时不想碰水"},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1","parentGoal":"calmer_care"}
                        """),
                Arguments.of("forbidden baby name", """
                        {"source":{"type":"custom","text":"洗澡时不想碰水"},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1","babyName":"小满"}
                        """),
                Arguments.of("forbidden household id", """
                        {"source":{"type":"custom","text":"洗澡时不想碰水"},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1","householdId":"forbidden"}
                        """),
                Arguments.of("forbidden account id", """
                        {"source":{"type":"custom","text":"洗澡时不想碰水"},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1","accountId":"forbidden"}
                        """),
                Arguments.of("forbidden profile id", """
                        {"source":{"type":"custom","text":"洗澡时不想碰水"},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1","profileId":"forbidden"}
                        """),
                Arguments.of("preset text override", """
                        {"source":{"type":"preset","presetSceneId":"bath_time","text":"override"},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1"}
                        """),
                Arguments.of("custom preset id mix", """
                        {"source":{"type":"custom","text":"洗澡时不想碰水","presetSceneId":"bath_time"},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1"}
                        """),
                Arguments.of("source unknown field", """
                        {"source":{"type":"custom","text":"洗澡时不想碰水","unexpected":true},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1"}
                        """),
                Arguments.of("source type number", """
                        {"source":{"type":1,"text":"洗澡时不想碰水"},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1"}
                        """),
                Arguments.of("source text number", """
                        {"source":{"type":"custom","text":1},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1"}
                        """),
                Arguments.of("source text array", """
                        {"source":{"type":"custom","text":[]},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1"}
                        """),
                Arguments.of("source preset id object", """
                        {"source":{"type":"preset","presetSceneId":{}},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1"}
                        """),
                Arguments.of("source primitive", """
                        {"source":"custom","locale":"zh-CN","installationId":"i1","clientRequestId":"r1"}
                        """),
                Arguments.of("missing custom text", """
                        {"source":{"type":"custom"},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1"}
                        """),
                Arguments.of("null custom text", """
                        {"source":{"type":"custom","text":null},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1"}
                        """),
                Arguments.of("null preset id", """
                        {"source":{"type":"preset","presetSceneId":null},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1"}
                        """),
                Arguments.of("top-level null locale", """
                        {"source":{"type":"custom","text":"洗澡时不想碰水"},"locale":null,"installationId":"i1","clientRequestId":"r1"}
                        """),
                Arguments.of("missing source", """
                        {"locale":"zh-CN","installationId":"i1","clientRequestId":"r1"}
                        """),
                Arguments.of("null source", """
                        {"source":null,"locale":"zh-CN","installationId":"i1","clientRequestId":"r1"}
                        """),
                Arguments.of("source array", """
                        {"source":[],"locale":"zh-CN","installationId":"i1","clientRequestId":"r1"}
                        """),
                Arguments.of("locale number", """
                        {"source":{"type":"custom","text":"洗澡时不想碰水"},"locale":1,"installationId":"i1","clientRequestId":"r1"}
                        """),
                Arguments.of("installation id number", """
                        {"source":{"type":"custom","text":"洗澡时不想碰水"},"locale":"zh-CN","installationId":1,"clientRequestId":"r1"}
                        """),
                Arguments.of("client request id object", """
                        {"source":{"type":"custom","text":"洗澡时不想碰水"},"locale":"zh-CN","installationId":"i1","clientRequestId":{}}
                        """),
                Arguments.of("duplicate nested type", """
                        {"source":{"type":"custom","type":"preset","text":"洗澡时不想碰水"},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1"}
                        """),
                Arguments.of("duplicate top-level", """
                        {"source":{"type":"custom","text":"洗澡时不想碰水"},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1","clientRequestId":"r2"}
                        """),
                Arguments.of("bad json", "{"),
                Arguments.of("top-level array", "[]"),
                Arguments.of("top-level null", "null"));
    }

    @Test
    void unauthenticatedSidIsPassedAsNullForProfileErrorTranslation() throws Exception {
        when(service.generate(any(), eq(null))).thenThrow(new ContractException(
                org.springframework.http.HttpStatus.UNAUTHORIZED, "invalid_session", "session 不存在或已失效。"));
        mockMvc.perform(post("/api/v1/practice/scene-generations")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"source":{"type":"custom","text":"洗澡时不想碰水"},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1"}
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("invalid_session"));
    }

    @Test
    void unexpectedCatalogFailureUsesGenericPrivacySafeFiveHundredResponse() throws Exception {
        when(service.generate(any(), eq("session-1")))
                .thenThrow(new IllegalStateException("catalog database connection secret"));

        var result = mockMvc.perform(post("/api/v1/practice/scene-generations")
                        .with(authenticationWithSid("session-1"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"source":{"type":"preset","presetSceneId":"catalog_down"},"locale":"zh-CN","installationId":"i1","clientRequestId":"r1"}
                                """))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.code").value("internal_error"))
                .andExpect(jsonPath("$.message").value("服务端处理失败。"))
                .andReturn();
        assertThat(result.getResponse().getContentAsString())
                .doesNotContain("catalog database connection secret");
    }

    private RequestPostProcessor authenticationWithSid(String sid) {
        var jwt = Jwt.withTokenValue("token")
                .header("alg", "none")
                .claim("sid", sid)
                .build();
        var authentication = new JwtAuthenticationToken(jwt);
        return request -> {
            request.setUserPrincipal(authentication);
            return request;
        };
    }

    private SceneGenerationResponse response(String source) {
        var provenance = new SceneGenerationResponse.ProviderProvenance(
                "provider_generated", "test-provider", "test-model", 1);
        var starter = new SceneGenerationResponse.UtteranceView(
                "phrase-1", "phrase-1", "We can go slowly.", "我们可以慢慢来。", "we can go slowly",
                "看着宝宝。", "慢慢说。", "starter", "starter", null, 1, provenance);
        return new SceneGenerationResponse(
                "pgc-response", "custom-scene-generated-output-v1",
                new SceneGenerationResponse.RouteView("gen_scene_1", "gen_scene_1", "gen_activity_1", "gen_activity_1", "phrase-1"),
                new SceneGenerationResponse.SceneView("日常照护", "洗澡安抚", "Bath care"),
                starter,
                java.util.List.of(
                        new SceneGenerationResponse.UtteranceView("utt-2", "utt-2", "Together.", "一起。", "together", "一起做。", "慢慢说。", "starter", "reaction_support", "cooperating", 2, provenance),
                        new SceneGenerationResponse.UtteranceView("utt-3", "utt-3", "Try slowly.", "慢慢试。", "try slowly", "放近一点。", "等一等。", "starter", "reaction_support", "hesitant", 3, provenance),
                        new SceneGenerationResponse.UtteranceView("utt-4", "utt-4", "Pause.", "停一下。", "pause", "停一下。", "接住拒绝。", "starter", "reaction_support", "resisting", 4, provenance),
                        new SceneGenerationResponse.UtteranceView("utt-5", "utt-5", "I will wait.", "我等你。", "i will wait", "安静等候。", "不催促。", "starter", "reaction_support", "no_response", 5, provenance),
                        new SceneGenerationResponse.UtteranceView("utt-6", "utt-6", "Take a pause.", "先停一会儿。", "take a pause", "做个停顿。", "慢慢收束。", "starter", "reaction_support", "other", 6, provenance)),
                new SceneGenerationResponse.SourceView(source, "preset".equals(source) ? "bath_time" : null, "preset".equals(source) ? 3 : null));
    }

}
